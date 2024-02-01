inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./nix.nix
    ./fileSystems
    ./grub.nix
    ./initrd.nix
    ./kernel.nix
    ./impermanence.nix
    ./gui.nix
    ./nixpkgs.nix
    ./networking
    ./systemd.nix
    ./security.nix
    ./sops.nix
    ./user.nix
    ./sysctl.nix
    ./envfs.nix
  ];
  config =
  {
    services = { dbus.implementation = "broker"; fstrim.enable = true; };
    time.timeZone = "Asia/Shanghai";
    boot =
    {
      supportedFilesystems = [ "ntfs" ];
      # consoleLogLevel = 7;
    };
    hardware.enableAllFirmware = true;
    environment.sessionVariables = rec
    {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      # ANDROID_HOME = "${XDG_DATA_HOME}/android";
      HISTFILE= "${XDG_STATE_HOME}/bash/history";
      CUDA_CACHE_PATH = "${XDG_CACHE_HOME}/nv";
      DOCKER_CONFIG = "${XDG_CONFIG_HOME}/docker";
      GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
      GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc";
      XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
      MATHEMATICA_USERBASE = "${XDG_CONFIG_HOME}/mathematica";
      _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java";
    };
    i18n =
      { defaultLocale = "C.UTF-8"; supportedLocales = [ "zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8" ]; };
    users.mutableUsers = false;
    # environment.pathsToLink = [ "/include" ];
    # environment.variables.CPATH = "/run/current-system/sw/include";
    # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
    virtualisation.oci-containers.backend = "docker";
    home-manager.sharedModules = [{ home.stateVersion = "22.11"; }];
    system =
    {
      stateVersion = "22.11";
      configurationRevision = inputs.topInputs.self.rev or "dirty";
      nixos.versionSuffix = inputs.lib.mkForce "";
    };
  };
}
