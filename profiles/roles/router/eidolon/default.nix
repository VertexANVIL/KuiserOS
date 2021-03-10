{ config, pkgs, ... }:

# Base configuration for routers that are part of the Eidolon Routing Infrastructure System (RIS)
{
    boot = {
        loader.grub = {
            enable = true;
            version = 2;
        };

        # Forcing the kernel version to 5.2.
        # I'm sick and tired of the stupid fucking BIRD bug with 5.3
        kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_5_4.override {
            argsOverride = rec {
                version = "5.2";
                modDirVersion = "5.2.0";

                src = pkgs.fetchurl {
                    url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
                    sha256 = "1ry11b5sc20jh7flnp94m20627jzl3l09rzmfjsk3a71fbv6dbal";
                };
            };
        });
    };

    networking = {
        useDHCP = false;
        nameservers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
    };

    # programs & services
    services.routinator.enable = true;
    services.eidolon.firewall.enable = true;
}