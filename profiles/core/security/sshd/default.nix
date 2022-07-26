{
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "prohibit-password";
  };

  # networking.firewall.extraCommands = ''
  #     # allow connections from Arctarus ACI ranges
  #     ip6tables -w -A nixos-fw -s 2a10:4a80::/38 -p tcp --dport 22 -j nixos-fw-accept
  # '';
}
