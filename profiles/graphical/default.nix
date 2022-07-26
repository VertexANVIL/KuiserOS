{ pkgs, ... }:
{
  sound.enable = true;
  console.useXkbConfig = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];

    gtkUsePortal = true;
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        intel-media-driver
        vaapiIntel
        vaapiVdpau
      ];
    };

    pulseaudio = {
      enable = true;
      support32Bit = true; # Steam, etc
      package = pkgs.pulseaudioFull;
    };
  };

  services = {
    xserver = {
      enable = true;
      wacom.enable = true;
      libinput.enable = true;
    };

    # Enable pipewire
    pipewire.enable = true;
  };

  # Also forces Chromium to rebuild which we don't want
  # security.chromiumSuidSandbox.enable = true;

  environment.systemPackages = with pkgs; [
    playerctl
    pavucontrol
    alsaTools
    modem-manager-gui
  ];

  programs = {
    dconf.enable = true;
    usbtop.enable = true;
  };
}
