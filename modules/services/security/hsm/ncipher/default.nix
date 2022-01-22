{ config, lib, pkgs, ... }:
with lib;
let
    cfg = config.services.security.hsm.ncipher;

    toNcipherINI = attrsOfLists:
        let
            filtered = filterAttrs (n: v: v != null) attrsOfLists;

            # need to override this because our true/false is yes/no
            tkvFunc = lib.generators.toKeyValue {
                mkKeyValue = lib.generators.mkKeyValueDefault {
                    mkValueString = v: with builtins;
                        let err = t: v: abort
                            ("generators.mkValueStringDefault: " +
                            "${t} not supported: ${toPretty {} v}");
                        in   if isInt      v then toString v
                        # convert derivations to store paths
                        else if lib.isDerivation v then toString v
                        # we default to not quoting strings
                        else if isString   v then v
                        # isString returns "1", which is not a good default
                        else if true  ==   v then "yes"
                        # here it returns to "", which is even less of a good default
                        else if false ==   v then "no"
                        else if null  ==   v then "null"
                        # if you have lists you probably want to replace this
                        else if isList     v then err "lists" v
                        # same as for lists, might want to replace
                        else if isAttrs    v then err "attrsets" v
                        # functions can’t be printed of course
                        else if isFunction v then err "functions" v
                        # Floats currently can't be converted to precise strings,
                        # condition warning on nix version once this isn't a problem anymore
                        # See https://github.com/NixOS/nix/pull/3480
                        else if isFloat    v then libStr.floatToString v
                        else err "this value is" (toString v);
                } "=";
            };

            mkSection = sectName: sectValues: ''
            [${escape [ "[" "]" ] sectName}]
            '' + tkvFunc (filterAttrs (n: v: v != null) sectValues);
            mkSections = sectName: sects:
                if isList sects then
                    concatStringsSep "\n" (map (mkSection sectName) sects)
                else if isAttrs sects then
                    mkSection sectName sects
                else null;

            # map function to string for each key val
            mapAttrsToStringsSep = sep: mapFn: attrLists:
                concatStringsSep sep (mapAttrsToList mapFn attrLists);
        in
        # map input to ini sections
        "syntax-version=1\n" + (mapAttrsToStringsSep "\n" mkSections filtered);
    
    renderedCardList = concatStringsSep "\n" cfg.cardlist;
    renderedConfig = toNcipherINI cfg.config;
in
{
    options.services.security.hsm.ncipher = {
        enable = mkEnableOption "nCipher HSM";

        packages = {
            secworld = mkOption {
                type = types.package;
                default = pkgs.secworld;
                defaultText = "pkgs.secworld";
                description = "The Security World software package to use.";
            };

            # driver = mkOption {
            #     type = types.package;
            #     default = pkgs.linuxPackages.nfast;
            #     defaultText = "pkgs.linuxPackages.nfast";
            #     description = "The nFast driver package to use.";
            # };
        };

        hardserver = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enables the hardserver service";
            };

            user = mkOption {
                type = types.str;
                default = "nfast";
                description = "User to run the service as";
            };

            group = mkOption {
                type = types.str;
                default = "nfast";
                description = "Group to run the service as";
            };
        };

        raserv = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enables the Remote Administration service";
            };

            user = mkOption {
                type = types.str;
                default = "raserv";
                description = "User to run the service as";
            };

            group = mkOption {
                type = types.str;
                default = "raserv";
                description = "Group to run the service as";
            };
        };

        enableEdge = mkOption {
            type = types.bool;
            default = true;
            description = "Enable support for nShield Edge detection";
        };

        cardlist = mkOption {
            description = ''
                Remote Administration Ready smartcards that are allowed to be used.
                Examples of valid 16 digit serial numbers:
                    XXXXXXXX-XXXXXXXX
                    XXXXXXXXXXXXXXXX
                    XXXX-XXXX-XXXX-XXXX
                To permit any cards presented to be used:
                     *
            '';

            type = types.listOf types.str;
            default = [];
        };

        config = mkOption {
            description = ''
                Configuration options to set in the nCipher configuration file.
                For a full list of available parameters, see the config template in the platform software.
            '';

            type = types.submodule {
                freeformType = types.attrs;
                options = {
                    server_settings = mkOption {
                        default = null;
                        description = "Hardserver settings which can be changed by calling hsc_serversettings with the hardserver running";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                loglevel = mkOption {
                                    default = null;
                                    defaultText = "info";
                                    type = types.nullOr (types.enum [ "info" "notice" "client" "remoteserver" "error" "serious" "internal" "startup" "fatal" "fatalinternal" ]);
                                    description = ''
                                        The hardserver's logging level, one of info, notice, client, remoteserver,
                                        error, serious, internal, startup, fatal, fatalinternal
                                    '';
                                };

                                logdetail = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = "Level of detail to log, for diagnostics or debugging.";
                                };

                                connect_maxqueue = mkOption {
                                    default = null;
                                    defaultText = "4096";
                                    type = types.nullOr types.int;
                                    description = "The maximum queue length for a remote connection between 1 and 4096";
                                };

                                connect_retry = mkOption {
                                    default = null;
                                    defaultText = "10";
                                    type = types.nullOr types.int;
                                    description = "Number of seconds to wait before retrying a remote connection";
                                };

                                connect_keepalive = mkOption {
                                    default = null;
                                    defaultText = "10";
                                    type = types.nullOr types.int;
                                    description = "Number of seconds between keepalive packets for remote connections";
                                };

                                connect_keepidle = mkOption {
                                    default = null;
                                    defaultText = "30";
                                    type = types.nullOr types.int;
                                    description = "Number of seconds before the first keepalive packet for remote outgoing connections";
                                };

                                connect_broken = mkOption {
                                    default = null;
                                    defaultText = "90";
                                    type = types.nullOr types.int;
                                    description = ''
                                        Number of seconds the remote end may be unresponsive before a remote
                                        connection (incoming or outgoing) is considered broken
                                    '';
                                };

                                connect_command_block = mkOption {
                                    default = null;
                                    defaultText = "35";
                                    type = types.nullOr types.int;
                                    description = ''
                                        After a netHSM has failed, how many seconds should the hardserver wait for
                                        it to become available again, before failing commands destined to the netHSM
                                        with a NetworkError message. For commands to have a chance of succeeding
                                        after a netHSM has failed, this value should be greater than connect_retry.
                                        If it is set to 0, then commands to the netHSM are failed with NetworkError
                                        immediately a netHSM has failed.
                                    '';
                                };

                                accept_keepidle = mkOption {
                                    default = null;
                                    defaultText = "30";
                                    type = types.nullOr types.int;
                                    description = "Number of seconds before the first keepalive packet for remote incoming connections";
                                };

                                accept_keepalive = mkOption {
                                    default = null;
                                    defaultText = "10";
                                    type = types.nullOr types.int;
                                    description = ''
                                        Number of seconds between keepalive packets for remote incoming connections.
                                        The socket will timeout after ten consecutive probe failures
                                    '';
                                };

                                max_pci_if_vers = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "Maximum PCI interface version. 0 implies no limit.";
                                };

                                enable_remote_mode = mkOption {
                                    default = null;
                                    defaultText = "true";
                                    type = types.nullOr types.bool;
                                    description = "Is remote mode changing enabled on this system?";
                                };

                                enable_remote_reboot = mkOption {
                                    default = null;
                                    defaultText = "true";
                                    type = types.nullOr types.bool;
                                    description = "Is remote reboot enabled on this system?";
                                };

                                enable_remote_upgrade = mkOption {
                                    default = null;
                                    defaultText = "true";
                                    type = types.nullOr types.bool;
                                    description = "Is remote upgrade enabled on this system?";
                                };
                            };
                        });
                    };

                    module_settings = mkOption {
                        default = [];
                        description = "Per-module settings which can be changed by calling hsc_serversettings with the hardserver running";

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                esn = mkOption {
                                    type = types.str;
                                    description = "Module ESN";
                                };

                                priority = mkOption {
                                    default = null;
                                    defaultText = "100";
                                    type = types.nullOr (types.addCheck types.int (n: n >= 1 && n <= 100));
                                    description = "Priority class of this module -- lower number is higher priority.";
                                };
                            };
                        });
                    };

                    server_remotecomms = mkOption {
                        default = null;
                        description = "Hardserver IPv4 remote communication settings, these are only read at hardserver startup time";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                impath_port = mkOption {
                                    default = null;
                                    defaultText = "9004";
                                    type = types.nullOr types.int;
                                    description = ''
                                        The port for the hardserver to listen to for incoming impath connections or 0 for none.
                                        Note that any firewall must be configured to allow connections to this port.
                                    '';
                                };

                                impath_addr = mkOption {
                                    default = null;
                                    defaultText = "0.0.0.0";
                                    type = types.nullOr types.str;
                                    description = "Specific IPv4 address the hardserver will bind to to listen for incoming impath connections.";
                                };

                                impath_interface = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = ''
                                        Interface name (eth0, eth1, or bond0) the hardserver will bind to.
                                        Used if impath_addr is 0.0.0.0 (i.e. INADDR_ANY). Default is bind to all interfaces.
                                    '';
                                };
                            };
                        });
                    };

                    server_remotecomms_ipv6 = mkOption {
                        default = null;
                        description = "Hardserver IPv6 remote communication settings, these are only read at hardserver startup time";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                impath_port = mkOption {
                                    default = null;
                                    defaultText = "9004";
                                    type = types.nullOr types.int;
                                    description = ''
                                        The port for the hardserver to listen to for incoming impath connections or 0 for none.
                                        Note that any firewall must be configured to allow connections to this port.
                                    '';
                                };

                                impath_addr = mkOption {
                                    default = null;
                                    defaultText = "::";
                                    type = types.nullOr types.str;
                                    description = "Specific IPv6 address the hardserver will bind to to listen for incoming impath connections.";
                                };

                                impath_interface = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = ''
                                        Interface name (eth0, eth1, or bond0) the hardserver will bind to.
                                        It gets converted to the scope ID for link-local IP addresses.
                                        Used only if impath_addr is of link-local type (i.e. fe80::).
                                    '';
                                };
                            };
                        });
                    };

                    auditlog_settings = mkOption {
                        default = null;
                        description = "Hardserver settings for audit logging.";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                auditlog_port = mkOption {
                                    default = null;
                                    defaultText = "514";
                                    type = types.nullOr types.int;
                                    description = "Port number the audit logging syslog server listens to.";
                                };

                                auditlog_addr = mkOption {
                                    type = types.str;
                                    description = "IP Address of the audit logging syslog server.";
                                };

                                auditlog_copy_hslog = mkOption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Copy audit log entries to hardserver log.";
                                };
                            };
                        });
                    };

                    server_startup = mkOption {
                        default = {};
                        description = "Hardserver communication settings, these are only read at hardserver startup time";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                unix_socket_name = mkOption {
                                    default = null;
                                    defaultText = "/opt/nfast/sockets/nserver";
                                    type = types.nullOr types.str;
                                    description = "Name of unix socket to use for non-privileged connections on unix";
                                };

                                unix_privsocket_name = mkOption {
                                    default = null;
                                    defaultText = "/opt/nfast/sockets/priv/privnserver";
                                    type = types.nullOr types.str;
                                    description = "Name of unix socket to use for privileged connections on unix";
                                };

                                nt_pipe_name = mkOption {
                                    default = null;
                                    defaultText = "\\\\.\\pipe\\crypto";
                                    type = types.nullOr types.str;
                                    description = "Name of pipe to use for non-privileged connections on windows or empty";
                                };

                                nt_pipe_users = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = "User or group allowed to issue non-privileged connections on windows or empty string for anyone";
                                };

                                nt_privpipe_name = mkOption {
                                    default = null;
                                    defaultText = "\\\\.\\pipe\\privcrypto";
                                    type = types.nullOr types.str;
                                    description = "Name of pipe to use for privileged connections on windows or empty string for none";
                                };

                                nt_privpipe_users = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = "User or group allowed to issue privileged connections on windows or empty string for members of the Administrators group";
                                };

                                nonpriv_port = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.str;
                                    description = ''
                                        The port for the hardserver to listen to for local non-privileged TCP connections. Java clients default to connecting to 9000.
                                        When 0 is specified, the port is disabled on UNIX, but enabled on port 9000 with the access controls specified by nt_pipe_users on Windows.
                                    '';
                                };

                                priv_port = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.str;
                                    description = ''
                                        The port for the hardserver to listen to for local privileged TCP connections. Java clients default to connecting to 9001.
                                        When 0 is specified the port is disabled on UNIX, but enabled on port 9001 with the access controls specified by nt_privpipe_users on Windows.
                                    '';
                                };

                                serial_dtpp_devices = mkOption {
                                    default = "";
                                    type = types.nullOr types.str;
                                    example = "COM1:COM2 or /dev/cua2:/dev/cua3";
                                    description = "List of serial device nodes or COM ports for serial devices";
                                };

                                unix_file_descriptor_max = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.str;
                                    description = ''
                                        The maximum number of file descriptors the hardserver can have open
                                        concurrently on Unix. The hardserver automatically configures its file
                                        descriptor soft limit up to the kernel hard limit. If this config entry is
                                        non-zero, the hardserver will set the soft limit to the requested value. The
                                        hardserver will refuse to start-up if it fails to set the new soft limit.
                                        This allows enforcement that the hardserver will be able to support, for
                                        example, a certain number of connections needed by client applications. If
                                        start-up fails, increase the kernel hard limit to be equal to or higher than
                                        the required number of file descriptors.
                                    '';
                                };
                            };
                        });
                    };

                    server_performance = mkOption {
                        default = null;
                        description = "Hardserver performance settings, these are only read at hardserver startup time";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                enable_scaling = mkOption {
                                    default = null;
                                    defaultText = "auto";
                                    type = types.nullOr (types.either types.bool (types.enum [ "auto" ]));
                                    description = ''
                                        Is multi-threaded performance scaling enabled on this system?
                                        - auto means the hardserver will choose the best option for the available hardware
                                    '';
                                };

                                target_concurrency = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = ''
                                        How much concurrent processing should the hardserver attempt to make use of
                                        for performance scaling? Applicable only when enable_scaling is set to yes.
                                        Auto-configured by the hardserver if set to 0; the target concurrency
                                        selected is written to the hardserver log. This does not restrict the
                                        hardserver to a particular number of cores, but if CPU availability is
                                        reduced by other applications, or if CPU affinity is enabled, reducing this
                                        setting below the auto-configured value may help improve performance. On
                                        systems with large numbers of CPU cores, if large numbers of client
                                        connections are made to the hardserver, or if large numbers of HSMs are
                                        used, increasing this value above the auto-configured default may help
                                        improve scaling.
                                    '';
                                };
                            };
                        });
                    };

                    nethsm_imports = mkOption {
                        default = [];
                        description = ''
                            The HSMs that the hardserver should import. Note that the limits listed here
                            must be at least as strict as the HSM's own configuration, or the HSM will reject attempts to connect with ServerAccessDenied.
                        '';

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                local_module = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "New module number to assign to the imported nethsm, or 0 to use the next unassigned module number.";
                                };

                                remote_ip = mkOption {
                                    type = types.str;
                                    description = "Network address of the HSM";
                                };

                                remote_port = mkOption {
                                    type = types.int;
                                    description = "Port to connect to on the HSM";
                                };

                                remote_esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the HSM to import";
                                };

                                keyhash = mkOption {
                                    type = types.str;
                                    description = ''
                                        The hash of the key that the HSM should authenticate themselves with.
                                        If set to forty zeroes, key authentication is not performed (NOT RECOMMENDED).
                                    '';
                                };

                                timelimit = mkOption {
                                    default = null;
                                    type = types.nullOr types.int;
                                    description = "Obsolete. This should be 0 or unset in new configuration entries and will be removed in a future release.";
                                };

                                datalimit = mkOption {
                                    default = null;
                                    type = types.nullOr types.int;
                                    description = "Obsolete. This should be 0 or unset in new configuration entries and will be removed in a future release.";
                                };

                                privileged = mkOption {
                                    default = null;
                                    type = types.nullOr types.int;
                                    description = "Whether to make a privileged connection to the HSM";
                                };

                                privileged_use_high_port = mkOption {
                                    default = null;
                                    type = types.nullOr types.int;
                                    description = "Whether to use high-numbered ports for privileged connections";
                                };

                                ntoken_esn = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = "ESN of this client's nToken";
                                };
                            };
                        });
                    };

                    load_seemachine = mkOption {
                        default = [];
                        description = ''
                            The SEE machines that the modules should load and possibly start for the
                            benefit of other hardserver clients. Incorporates payShield startup settings
                        '';

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                module = mkOption {
                                    type = types.int;
                                    description = "The module to load the SEE machine onto";
                                };

                                machine_file = mkOption {
                                    type = types.str;
                                    description = ''
                                        The filename of the SEE machine for this module to host. If the module is a
                                        payShield this must be the full path to emvsmtype(1,2).sar with the desired version number.
                                    '';
                                };

                                encryption_key = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = ''
                                        The ident of the seeconf key that protects the SEE machine. Only module-protected keys can be used here.
                                        If the machine is not encrypted then leave this field blank.
                                    '';
                                };

                                signing_hash = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = ''
                                        The hash of the key that the SEE machine is signed by. This is only required
                                        if you are using the dynamic feature enable and the SEE machine is encrypted.
                                        (If the SEE machine is not encrypted then the signing key hash can be extracted from it automatically.)
                                    '';
                                };

                                userdata = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = ''
                                        The filename of the userdata to pass to the SEE machine on startup.
                                        If userdata is blank then the seemachine is loaded but not started.
                                        If the module is a payShield then this field must be left blank.
                                    '';
                                };

                                worldid_pubname = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = ''
                                        The PublishedObject name to use for publishing the KeyID of the started SEE machine.
                                        If worldid_pubname is blank then the KeyID is not published. This field is ignored if userdata is blank.
                                        If the module is a payShield then this field must be left blank.
                                    '';
                                };

                                postload_prog = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = ''
                                        Program to run after loading the SEE machine to perform any initialisation
                                        required by the SEE machine or its clients, or blank if no initialisation is required.
                                        This program must accept an argument of the form "-m <module>".
                                        If the module is a payShield, simply enter "payshield".
                                    '';
                                };

                                postload_args = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = ''
                                        Args to pass to postload_prog, less '-m <module>' which will be automatically passed as the first argument.
                                        This field is ignored if postload_prog is blank. If the module is a payShield then enter "-n <psiname> [-d]".
                                    '';
                                };

                                pull_rfs = mkOption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Set to true to pull the SEE machine and userdata from the RFS before loading on the remote module.";
                                };
                            };
                        });
                    };

                    slot_imports = mkOption {
                        default = [];
                        description = ''
                            Remote slots that the hardserver should import to modules on this machine.
                            This cannot be configured alongside dynamic slots.
                        '';

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                local_esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the local module to import the slot to";
                                };

                                local_slotid = mkOption {
                                    default = null;
                                    defaultText = "2";
                                    type = types.nullOr types.int;
                                    description = "SlotID to use to refer to the slot when it is imported on the local module";
                                };

                                remote_ip = mkOption {
                                    type = types.str;
                                    description = "IP address of the machine hosting the slot to import";
                                };

                                remote_port = mkOption {
                                    type = types.int;
                                    description = "Port to connect to on the remote machine";
                                };

                                remote_esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the remote module to import the slot from";
                                };

                                remote_slotid = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "SlotID of the slot to import on the remote module";
                                };
                            };
                        });
                    };

                    slot_exports = mkOption {
                        default = [];
                        description = ''
                            Local slots that the hardserver should allow remote modules to import.
                            This cannot be configured alongside dynamic slots.
                        '';

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                local_esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the local module whose slot is allowed to be exported.";
                                };

                                local_slotid = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "SlotID of the slot which is allowed to be exported.";
                                };

                                remote_ip = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = "IP address of the machine allowed to import the slot or empty to allow all machines.";
                                };

                                remote_esn = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = "ESN of the module allowed to import the slot or empty to allow all modules which are permitted in the security world.";
                                };
                            };
                        });
                    };

                    dynamic_slot_timeouts = mkOption {
                        default = null;
                        description = "Timeout values used to specify expected smartcard responsiveness for all modules on the network.";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                round_trip_time_limit = mkOption {
                                    default = null;
                                    defaultText = "10";
                                    type = types.nullOr types.int;
                                    description = "Round trip time limit, in seconds, is how long to wait before giving up due to network delays.";
                                };

                                card_remove_detect_time_limit = mkOption {
                                    default = null;
                                    defaultText = "30";
                                    type = types.nullOr types.int;
                                    description = ''
                                        Maximum time, in seconds, that can pass without a response from the
                                        smartcard before considering it removed and unloading all associated secrets
                                    '';
                                };
                            };
                        });
                    };

                    dynamic_slots = mkOption {
                        default = [];
                        description = ''
                            The dynamic smartcard slots that the modules should provide for the use of
                            administrators who do not have physical access to the module hardware
                        '';

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the module to be configured with dynamic slots.";
                                };

                                slotcount = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "Number of dynamic slots the module will support.";
                                };
                            };
                        });
                    };

                    slot_mapping = mkOption {
                        default = [];
                        description = "Slot remapping configuration.";

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                esn = mkOption {
                                    type = types.str;
                                    description = "ESN of the module on which slot 0 will be remapped with another.";
                                };

                                slot = mkOption {
                                    default = null;
                                    defaultText = "0";
                                    type = types.nullOr types.int;
                                    description = "Slot to exchange with slot 0. Setting this value to 0 means do nothing.";
                                };
                            };
                        });
                    };

                    remote_file_system = mkOption {
                        default = [];
                        description = "The remote file system volumes that this machine hosts for the benefit of HSMs.";

                        type = types.listOf (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                remote_ip = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = "IP address of the machine allowed to access this volume or empty to allow any IP address. (which is the default)";
                                };

                                remote_esn = mkOption {
                                    default = null;
                                    defaultText = "";
                                    type = types.nullOr types.str;
                                    description = "ESN of the remote module allowed to access this volume or blank to allow any module";
                                };

                                keyhash = mkOption {
                                    default = null;
                                    defaultText = "0000000000000000000000000000000000000000";
                                    type = types.nullOr types.str;
                                    description = "The hash of the key that the machine must authenticate themselves with, or 40 zeros to indicate no key authentication required.";
                                };

                                native_path = mkOption {
                                    type = types.str;
                                    description = "The local filename for the volume to which this entry corresponds";
                                };

                                volume = mkOption {
                                    type = types.str;
                                    description = "The name of the volume which the remote host uses to access the files in native_path";
                                };

                                allow_read = mkOption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Set to true to allow a remote server to read the contents of a file in this volume.";
                                };

                                allow_write = mkoption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Set to true to allow a remote server to write the contents of a file in this volume.";
                                };
                                
                                is_directory = mkOption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Set to true if this volume represents a directory";
                                };

                                is_text = mkOption {
                                    default = null;
                                    defaultText = "false";
                                    type = types.nullOr types.bool;
                                    description = "Set to true if files in this volume are text files which need to be opened in text mode.";
                                };
                            };
                        });
                    };

                    rfs_sync_client = mkOption {
                        default = null;
                        description = "The remote file system that this client will synchronise its key management data files with.";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                remote_ip = mkOption {
                                    type = types.str;
                                    description = "IP address of the RFS server to synchronise against.";
                                };
                                
                                remote_port = mkOption {
                                    default = null;
                                    defaultText = "9004";
                                    type = types.nullOr types.int;
                                    description = "Port to connect to the RFS server with.";
                                };

                                use_kneti = mkOption {
                                    default = null;
                                    type = types.nullOr types.bool;
                                    description = "Set to true to use an authenticated channel to the RFS.";
                                };

                                local_esn = mkOption {
                                    default = null;
                                    type = types.nullOr types.str;
                                    description = "ESN of the local module to use for authentication (default = first module; only required if use_kneti=yes).";
                                };
                            };
                        });
                    };

                    remote_administration_service_startup = mkOption {
                        default = null;
                        description = "Remote Administration Service communication settings, these are only read at Remote Administration Service startup time";

                        type = types.nullOr (types.submodule {
                            freeformType = types.attrs;
                            options = {
                                port = mkOption {
                                    default = null;
                                    defaultText = "9005";
                                    type = types.nullOr types.int;
                                    description = "The port for the Remote Administration Service to listen on for incoming TCP connections from remote administration clients";
                                };
                            };
                        });
                    };
                };
            };

            default = {};
        };
    };

    config = mkIf cfg.enable {
        #boot.extraModulePackages = [ cfg.packages.driver ];
        services.udev.packages = [ cfg.packages.secworld ]; # Udev rules for the Edge HSM

        # Udev rules for the Edge HSM
        services.udev.extraRules = if cfg.enableEdge then ''
            ACTION=="add", KERNEL=="ttyUSB*", SUBSYSTEM=="tty", ATTRS{interface}=="nCipher.nShield.Edge", ATTRS{bInterfaceNumber}=="00", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ncipher-edge-handler@$kernel.service", OWNER:="${cfg.hardserver.user}", GROUP:="${cfg.hardserver.group}", MODE:="0600"
        '' else "";

        environment = {
            # add the dirs for data to persistent volume
            persistence."/persist".directories = [
                "/opt/nfast/hardserver.d"
                "/opt/nfast/kmdata"
            ];

            sessionVariables = {
                "NFAST_HOME" = "/opt/nfast";
            };
        };

        users = {
            users = {
                "${cfg.hardserver.user}" = {
                    group = cfg.hardserver.group;
                    isSystemUser = true;
                    description = "nCipher Hardserver Service Account";
                };

                "${cfg.raserv.user}" = {
                    group = cfg.raserv.group;
                    isSystemUser = true;
                    description = "nCipher Remote Administration Service Account";
                };
            };

            groups = {
                "${cfg.hardserver.group}" = {};
                "${cfg.raserv.group}" = {};
            };
        };

        systemd.services = let
            home = "/opt/nfast";
            path = "${cfg.packages.secworld}/opt/nfast";
        in {
            ncipher-hardserver = mkIf cfg.hardserver.enable {
                description = "nCipher Hardserver Service";
                after = [ "syslog.target" "network.target" ];
                wantedBy = [ "multi-user.target" ];

                # for the startup script
                path = [ pkgs.pciutils ];

                environment = {
                    NFAST_HOME = home;
                    NFAST_USER = cfg.hardserver.user;
                    NFAST_GROUP = cfg.hardserver.group;
                    NFAST_CARDLIST_SOURCE = toString (pkgs.writeText "cardlist" renderedCardList);
                    NFAST_CONFIG_SOURCE = toString (pkgs.writeText "config" renderedConfig);
                };

                serviceConfig = {
                    ExecStart = pkgs.writeShellScript "hardserver-start" (builtins.readFile ./scripts/hardserver-start.sh);
                    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
                    ExecStartPre = pkgs.writeShellScript "hardserver-init" (builtins.readFile ./scripts/hardserver-init.sh);

                    Restart = "on-failure";
                    RestartSec = "30s";

                    User = cfg.hardserver.user;
                    Group = cfg.hardserver.group;
                    PermissionsStartOnly = true;

                    WorkingDirectory = home;
                    ReadWritePaths = home;

                    # Hardening
                    CapabilityBoundingSet = "";
                    IPAddressDeny = [ "" ];
                    KeyringMode = "private";
                    LockPersonality = true;
                    MemoryDenyWriteExecute = true;
                    NoNewPrivileges = true;
                    NotifyAccess = "none";
                    ProcSubset = "pid";
                    RemoveIPC = true;

                    PrivateDevices = false;
                    PrivateMounts = true;
                    PrivateNetwork = false;
                    PrivateTmp = true;
                    PrivateUsers = true;

                    ProtectClock = false;
                    ProtectControlGroups = true;
                    ProtectHome = true;
                    ProtectKernelLogs = true;
                    ProtectKernelModules = true;
                    ProtectKernelTunables = true;
                    ProtectHostname = true;
                    ProtectProc = "invisible";
                    ProtectSystem = "strict";
                    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
                    RestrictNamespaces = true;
                    RestrictRealtime = true;
                    RestrictSUIDSGID = true;

                    # needs the ipc syscall in order to run
                    SystemCallFilter = [
                        "@system-service"
                        "~@aio" "~@clock" "~@cpu-emulation" "~@chown" "~@debug" "~@keyring"
                        "~@memlock" "~@module" "~@mount" "~@raw-io" "~@reboot" "~@swap"
                        "~@privileged" "~@resources" "~@setuid" "~@sync" "~@timer"
                    ];
                    SystemCallArchitectures = "native";
                    SystemCallErrorNumber = "EPERM";
                };
            };

            ncipher-raserv = mkIf cfg.raserv.enable {
                description = "nCipher Remote Administration Service";
                after = [ "syslog.target" "network.target" "ncipher-hardserver.service" ];
                wantedBy = [ "multi-user.target" ];

                environment = {
                    NFAST_HOME = home;
                };

                serviceConfig = {
                    ExecStart = pkgs.writeShellScript "raserv-start" (builtins.readFile ./scripts/raserv-start.sh);
                    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

                    Restart = "on-failure";
                    RestartSec = "30s";

                    User = cfg.raserv.user;
                    Group = cfg.raserv.group;
                    PermissionsStartOnly = true;

                    WorkingDirectory = home;
                    ReadWritePaths = home;

                    # Hardening
                    CapabilityBoundingSet = "";
                    DeviceAllow = "";
                    IPAddressDeny = [ "" ];
                    KeyringMode = "private";
                    LockPersonality = true;
                    MemoryDenyWriteExecute = true;
                    NoNewPrivileges = true;
                    NotifyAccess = "none";
                    ProcSubset = "pid";
                    RemoveIPC = true;

                    PrivateDevices = true;
                    PrivateMounts = true;
                    PrivateNetwork = false;
                    PrivateTmp = true;
                    PrivateUsers = true;

                    ProtectClock = true;
                    ProtectControlGroups = true;
                    ProtectHome = true;
                    ProtectKernelLogs = true;
                    ProtectKernelModules = true;
                    ProtectKernelTunables = true;
                    ProtectHostname = true;
                    ProtectProc = "invisible";
                    ProtectSystem = "strict";
                    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
                    RestrictNamespaces = true;
                    RestrictRealtime = true;
                    RestrictSUIDSGID = true;

                    # needs the ipc syscall in order to run
                    SystemCallFilter = [
                        "@system-service"
                        "~@aio" "~@clock" "~@cpu-emulation" "~@chown" "~@debug" "~@keyring"
                        "~@memlock" "~@module" "~@mount" "~@raw-io" "~@reboot" "~@swap"
                        "~@privileged" "~@resources" "~@setuid" "~@sync" "~@timer"
                    ];
                    SystemCallArchitectures = "native";
                    SystemCallErrorNumber = "EPERM";
                };
            };

            "ncipher-edge-handler@" = mkIf cfg.enableEdge {
                description = "Service to invoke the Edge Handler";
                bindsTo = [ "dev-%i.device" ];

                environment = {
                    NFAST_HOME = home;
                };

                serviceConfig = let
                    script = pkgs.writeShellScript "edge-handler" (builtins.readFile ./scripts/edge-handler.sh);
                in {
                    Type = "simple";
                    ExecStart = "${script} insert /dev/%I";
                    ExecStop = "${script} remove /dev/%I";
                    RemainAfterExit = true;
                };
            };
        };

        systemd.tmpfiles.rules = [
            "d /var/opt/nfast-edge-handler 0750 root root - -"
        ];

        system.activationScripts.linkNfastOpt = {
            text = ''
                if [ ! -d /opt ]; then
                    mkdir /opt
                    chmod 0755 /opt
                fi

                mkdir -p /opt/nfast
                chown nfast:nfast /opt/nfast
                chmod 0755 /opt/nfast

                linkDir()
                {
                    ln -sfT "${pkgs.secworld}/opt/nfast/$1" "/opt/nfast/$1"
                }

                linkDir bin
                linkDir c
                linkDir document
                linkDir driver
                linkDir femcerts
                linkDir gcc
                linkDir java
                linkDir lib
                linkDir man
                linkDir nethsm-firmware
                linkDir openssl
                linkDir python
                linkDir python3
                linkDir sbin
                linkDir scripts
                linkDir share
                linkDir sslclient
                linkDir sslproxy
                linkDir tcl
                linkDir testdata
                linkDir toolkits
            '';
        };
    };
}
