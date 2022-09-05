{ lib, pkgs, ... }:
{
  system.activationScripts = {
    bash = ''
      mkdir -m 0775 -p /bin
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
      ln -sfn ${pkgs.coreutils}/bin/cat /bin/cat
    '';

    # ty gytis-ivaskevicius!
    ldso = ''
      mkdir -m 0755 -p /lib64
      ln -sfn ${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2.tmp
      mv -f /lib64/ld-linux-x86-64.so.2.tmp /lib64/ld-linux-x86-64.so.2 # atomically replace
    '';
  };
}
