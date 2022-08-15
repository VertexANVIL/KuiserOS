{ lib, pkgs, ... }:
{
  system.activationScripts = {
    bash = ''
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
    '';

    # ty gytis-ivaskevicius!
    ldso = ''
      mkdir -m 0755 -p /lib64
      ln -sfn ${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2.tmp
      mv -f /lib64/ld-linux-x86-64.so.2.tmp /lib64/ld-linux-x86-64.so.2 # atomically replace
    '';
  };
}
