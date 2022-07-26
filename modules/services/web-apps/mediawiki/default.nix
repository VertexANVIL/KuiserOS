{ config, pkgs, lib, ... }:

let

  inherit (lib) mkDefault mkEnableOption mkForce mkIf mkMerge mkOption;
  inherit (lib) concatStringsSep mapAttrsToList optional optionals optionalString types;

  cfg = config.services.mediawiki-nginx;
  fpm = config.services.phpfpm.pools.mediawiki;
  user = "mediawiki";
  group = config.services.nginx.group;
  cacheDir = "/var/cache/mediawiki";
  stateDir = "/var/lib/mediawiki";

  pkg = pkgs.stdenv.mkDerivation rec {
    pname = "mediawiki-full";
    version = src.version;
    src = cfg.package;

    __noChroot = true;

    nativeBuildInputs = with pkgs; [ git php73Packages.composer ];

    buildPhase = ''
      export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
      export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

      ${concatStringsSep "\n" (mapAttrsToList (k: v: ''
        ln -s ${v} share/mediawiki/extensions/${k}
      '') cfg.extensions)}

      mkdir build.temp
      export HOME="$(pwd)/build.temp"

      cd share/mediawiki
      cp ${cfg.composerFile} composer.local.json
      composer update
      cd ./../../
    '';

    installPhase = ''
      mkdir -p $out
      cp -r * $out/

      rm -rf $out/share/mediawiki/skins/*
      rm -rf $out/share/mediawiki/extensions/*

      ${concatStringsSep "\n" (mapAttrsToList (k: v: ''
        ln -s ${v} $out/share/mediawiki/skins/${k}
      '') cfg.skins)}

      ${concatStringsSep "\n" (mapAttrsToList (k: v: ''
        ln -s ${v} $out/share/mediawiki/extensions/${k}
      '') cfg.extensions)}
    '';
  };

  mediawikiScripts = pkgs.runCommand "mediawiki-scripts"
    {
      buildInputs = [ pkgs.makeWrapper ];
      preferLocalBuild = true;
    } ''
    mkdir -p $out/bin
    for i in changePassword.php createAndPromote.php userOptions.php edit.php nukePage.php update.php; do
      makeWrapper ${pkgs.php}/bin/php $out/bin/mediawiki-$(basename $i .php) \
        --set MEDIAWIKI_CONFIG ${mediawikiConfig} \
        --add-flags ${pkg}/share/mediawiki/maintenance/$i
    done
  '';

  mediawikiConfig = pkgs.writeText "LocalSettings.php" ''
    <?php
      # Protect against web entry
      if ( !defined( 'MEDIAWIKI' ) ) {
        exit;
      }

      $wgSitename = "${cfg.name}";
      $wgMetaNamespace = false;

      ## The URL base path to the directory containing the wiki;
      ## defaults for all runtime URL paths are based off of this.
      ## For more information on customizing the URLs
      ## (like /w/index.php/Page_title to /wiki/Page_title) please see:
      ## https://www.mediawiki.org/wiki/Manual:Short_URL
      $wgScriptPath = "";

      ## The protocol and server name to use in fully-qualified URLs
      $wgServer = "${if cfg.virtualHost.addSSL || cfg.virtualHost.forceSSL || cfg.virtualHost.onlySSL then "https" else "http"}://${cfg.virtualHost.serverName}";

      ## The URL path to static resources (images, scripts, etc.)
      $wgResourceBasePath = $wgScriptPath;

      ## The URL path to the logo.  Make sure you change this from the default,
      ## or else you'll overwrite your logo when you upgrade!
      $wgLogo = "$wgResourceBasePath/resources/assets/wiki.png";

      ## UPO means: this is also a user preference option

      $wgEnableEmail = true;
      $wgEnableUserEmail = true; # UPO

      $wgEmergencyContact = "${cfg.contact}";
      $wgPasswordSender = $wgEmergencyContact;

      $wgEnotifUserTalk = false; # UPO
      $wgEnotifWatchlist = false; # UPO
      $wgEmailAuthentication = true;

      ## Database settings
      $wgDBtype = "${cfg.database.type}";
      $wgDBserver = "${cfg.database.host}:${if cfg.database.socket != null then cfg.database.socket else toString cfg.database.port}";
      $wgDBname = "${cfg.database.name}";
      $wgDBuser = "${cfg.database.user}";
      ${optionalString (cfg.database.passwordFile != null) "$wgDBpassword = file_get_contents(\"${cfg.database.passwordFile}\");"}

      ${optionalString (cfg.database.type == "mysql" && cfg.database.tablePrefix != null) ''
        # MySQL specific settings
        $wgDBprefix = "${cfg.database.tablePrefix}";
      ''}

      ${optionalString (cfg.database.type == "mysql") ''
        # MySQL table options to use during installation or update
        $wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";
      ''}

      ## Shared memory settings
      $wgMainCacheType = CACHE_NONE;
      $wgMemCachedServers = [];

      ${optionalString (cfg.uploadsDir != null) ''
        $wgEnableUploads = true;
        $wgUploadDirectory = "${cfg.uploadsDir}";
      ''}

      $wgUseImageMagick = true;
      $wgImageMagickConvertCommand = "${pkgs.imagemagick}/bin/convert";

      # InstantCommons allows wiki to use images from https://commons.wikimedia.org
      $wgUseInstantCommons = false;

      # Periodically send a pingback to https://www.mediawiki.org/ with basic data
      # about this MediaWiki instance. The Wikimedia Foundation shares this data
      # with MediaWiki developers to help guide future development efforts.
      $wgPingback = true;

      ## If you use ImageMagick (or any other shell command) on a
      ## Linux server, this will need to be set to the name of an
      ## available UTF-8 locale
      $wgShellLocale = "C.UTF-8";

      ## Set $wgCacheDirectory to a writable directory on the web server
      ## to make your wiki go slightly faster. The directory should not
      ## be publically accessible from the web.
      $wgCacheDirectory = "${cacheDir}";

      # Site language code, should be one of the list in ./languages/data/Names.php
      $wgLanguageCode = "en";

      $wgSecretKey = file_get_contents("${stateDir}/secret.key");

      # Changing this will log out all existing sessions.
      $wgAuthenticationTokenVersion = "";

      ## For attaching licensing metadata to pages, and displaying an
      ## appropriate copyright notice / icon. GNU Free Documentation
      ## License and Creative Commons licenses are supported so far.
      $wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
      $wgRightsUrl = "";
      $wgRightsText = "";
      $wgRightsIcon = "";

      # Path to the GNU diff3 utility. Used for conflict resolution.
      $wgDiff = "${pkgs.diffutils}/bin/diff";
      $wgDiff3 = "${pkgs.diffutils}/bin/diff3";

      # Enabled skins.
      ${concatStringsSep "\n" (mapAttrsToList (k: v: "wfLoadSkin('${k}');") cfg.skins)}

      # Enabled extensions.
      ${concatStringsSep "\n" (mapAttrsToList (k: v: "wfLoadExtension('${k}');") cfg.extensions)}

      # Mail
      $wgSMTP = array(
        'host' => "${cfg.mail.host}",
        'IDHost' => "${cfg.mail.idHost}",
        'port' => ${toString cfg.mail.port},
        'auth' => ${toString cfg.mail.auth},
        'username' => "${cfg.mail.username}",
        ${optionalString (cfg.mail.passwordFile != null) "'password' => file_get_contents(\"${cfg.mail.passwordFile}\")"}
      );

      $wgPasswordReminderResendTime = 0;


      # End of automatically generated settings.
      # Add more configuration options below.

      ${cfg.extraConfig}
  '';

in
{
  # interface
  options = {
    services.mediawiki-nginx = {

      enable = mkEnableOption "MediaWiki";

      composerFile = mkOption {
        default = { };
        type = types.path;
      };

      package = mkOption {
        type = types.package;
        default = pkgs.mediawiki;
        description = "Which MediaWiki package to use.";
      };

      name = mkOption {
        default = "MediaWiki";
        example = "Foobar Wiki";
        description = "Name of the wiki.";
      };

      contact = mkOption {
        default = "foo@example.org";
      };

      uploadsDir = mkOption {
        type = types.nullOr types.path;
        default = "${stateDir}/uploads";
        description = ''
          This directory is used for uploads of pictures. The directory passed here is automatically
          created and permissions adjusted as required.
        '';
      };

      passwordFile = mkOption {
        type = types.path;
        description = "A file containing the initial password for the admin user.";
        example = "/run/keys/mediawiki-password";
      };

      skins = mkOption {
        default = { };
        type = types.attrsOf types.path;
        description = ''
          List of paths whose content is copied to the 'skins'
          subdirectory of the MediaWiki installation.
        '';
      };

      extensions = mkOption {
        default = { };
        type = types.attrsOf types.path;
        description = ''
          List of paths whose content is copied to the 'extensions'
          subdirectory of the MediaWiki installation.
        '';
      };

      database = {
        type = mkOption {
          type = types.enum [ "mysql" "postgres" "sqlite" "mssql" "oracle" ];
          default = "mysql";
          description = "Database engine to use. MySQL/MariaDB is the database of choice by MediaWiki developers.";
        };

        host = mkOption {
          type = types.str;
          default = "localhost";
          description = "Database host address.";
        };

        port = mkOption {
          type = types.port;
          default = 3306;
          description = "Database host port.";
        };

        name = mkOption {
          type = types.str;
          default = "mediawiki";
          description = "Database name.";
        };

        user = mkOption {
          type = types.str;
          default = "mediawiki";
          description = "Database user.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/keys/mediawiki-dbpassword";
          description = ''
            A file containing the password corresponding to
            <option>database.user</option>.
          '';
        };

        tablePrefix = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            If you only have access to a single database and wish to install more than
            one version of MediaWiki, or have other applications that also use the
            database, you can give the table names a unique prefix to stop any naming
            conflicts or confusion.
            See <link xlink:href='https://www.mediawiki.org/wiki/Manual:$wgDBprefix'/>.
          '';
        };

        socket = mkOption {
          type = types.nullOr types.path;
          default = if cfg.database.createLocally then "/run/mysqld/mysqld.sock" else null;
          defaultText = "/run/mysqld/mysqld.sock";
          description = "Path to the unix socket file to use for authentication.";
        };

        createLocally = mkOption {
          type = types.bool;
          default = cfg.database.type == "mysql";
          defaultText = "true";
          description = ''
            Create the database and database user locally.
            This currently only applies if database type "mysql" is selected.
          '';
        };
      };

      mail = {
        host = mkOption {
          type = types.str;
        };

        idHost = mkOption {
          type = types.str;
        };

        port = mkOption {
          type = types.port;
          default = 587;
        };

        auth = mkOption {
          type = types.bool;
          default = false;
        };

        username = mkOption {
          type = types.str;
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/keys/mediawiki-mailpassword";
          description = ''
            A file containing the password corresponding to
            <option>mail.username</option>.
          '';
        };
      };

      virtualHost = mkOption {
        type = types.submodule (import <nixpkgs/nixos/modules/services/web-servers/nginx/vhost-options.nix>);
      };

      poolConfig = mkOption {
        type = with types; attrsOf (oneOf [ str int bool ]);
        default = {
          "pm" = "dynamic";
          "pm.max_children" = 32;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 4;
          "pm.max_requests" = 500;
        };
        description = ''
          Options for the MediaWiki PHP pool. See the documentation on <literal>php-fpm.conf</literal>
          for details on configuration directives.
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        description = ''
          Any additional text to be appended to MediaWiki's
          LocalSettings.php configuration file. For configuration
          settings, see <link xlink:href="https://www.mediawiki.org/wiki/Manual:Configuration_settings"/>.
        '';
        default = "";
        example = ''
          $wgEnableEmail = false;
        '';
      };

    };
  };

  # implementation
  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.database.createLocally -> cfg.database.type == "mysql";
        message = "services.mediawiki-nginx.createLocally is currently only supported for database type 'mysql'";
      }
      {
        assertion = cfg.database.createLocally -> cfg.database.user == user;
        message = "services.mediawiki-nginx.database.user must be set to ${user} if services.mediawiki-nginx.database.createLocally is set true";
      }
      {
        assertion = cfg.database.createLocally -> cfg.database.socket != null;
        message = "services.mediawiki-nginx.database.socket must be set if services.mediawiki-nginx.database.createLocally is set to true";
      }
      {
        assertion = cfg.database.createLocally -> cfg.database.passwordFile == null;
        message = "a password cannot be specified if services.mediawiki-nginx.database.createLocally is set to true";
      }
    ];

    services.mediawiki-nginx.skins = {
      MonoBook = "${cfg.package}/share/mediawiki/skins/MonoBook";
      Timeless = "${cfg.package}/share/mediawiki/skins/Timeless";
      Vector = "${cfg.package}/share/mediawiki/skins/Vector";
    };

    services.mysql = mkIf cfg.database.createLocally {
      enable = true;
      package = mkDefault pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = { "${cfg.database.name}.*" = "ALL PRIVILEGES"; };
        }
      ];
    };

    services.phpfpm.pools.mediawiki = {
      inherit user group;
      phpEnv.MEDIAWIKI_CONFIG = "${mediawikiConfig}";
      settings = {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
      } // cfg.poolConfig;
    };

    services.nginx.virtualHosts.${cfg.virtualHost.serverName} = mkMerge [
      cfg.virtualHost
      {
        root = mkForce "${pkg}/share/mediawiki";
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${stateDir}' 0750 ${user} ${group} - -"
      "d '${cacheDir}' 0750 ${user} ${group} - -"
    ] ++ optionals (cfg.uploadsDir != null) [
      "d '${cfg.uploadsDir}' 0750 ${user} ${group} - -"
      "Z '${cfg.uploadsDir}' 0750 ${user} ${group} - -"
    ];

    systemd.services.mediawiki-init = mkIf cfg.database.createLocally {
      wantedBy = [ "multi-user.target" ];
      before = [ "phpfpm-mediawiki.service" ];
      after = optional cfg.database.createLocally "mysql.service";
      script = ''
        if ! test -e "${stateDir}/secret.key"; then
          tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64 > ${stateDir}/secret.key
        fi

        echo "exit( wfGetDB( DB_MASTER )->tableExists( 'user' ) ? 1 : 0 );" | \
        ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/eval.php --conf ${mediawikiConfig} && \
        ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/install.php \
          --confpath /tmp \
          --scriptpath / \
          --dbserver ${cfg.database.host}${optionalString (cfg.database.socket != null) ":${cfg.database.socket}"} \
          --dbport ${toString cfg.database.port} \
          --dbname ${cfg.database.name} \
          ${optionalString (cfg.database.tablePrefix != null) "--dbprefix ${cfg.database.tablePrefix}"} \
          --dbuser ${cfg.database.user} \
          ${optionalString (cfg.database.passwordFile != null) "--dbpassfile ${cfg.database.passwordFile}"} \
          --passfile ${cfg.passwordFile} \
          ${cfg.name} \
          admin

        ${pkgs.php}/bin/php ${pkg}/share/mediawiki/maintenance/update.php --conf ${mediawikiConfig} --quick
      '';

      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = group;
        PrivateTmp = true;
      };
    };

    systemd.services.nginx.after = optional (cfg.database.createLocally && cfg.database.type == "mysql") "mysql.service";

    users.users.${user} = {
      group = group;
      isSystemUser = true;
    };

    environment.systemPackages = [ mediawikiScripts ];
  };
}
