inputs:
{
  options.nixos.services.gamemode = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    drmDevice = mkOption { type = types.int; };
  };
  config = let inherit (inputs.config.nixos.services) gamemode; in inputs.lib.mkIf gamemode.enable
  {
    programs.gamemode =
    {
      enable = true;
      settings =
      {
        general.renice = 10;
        gpu =
        {
          apply_gpu_optimisations = "accept-responsibility";
          nv_powermizer_mode = 1;
          gpu_device = builtins.toString gamemode.drmDevice;
        };
        custom = let notify-send = "${inputs.pkgs.libnotify}/bin/notify-send"; in
        {
          start = "${notify-send} 'GameMode started'";
          end = "${notify-send} 'GameMode ended'";
        };
      };
    };
  };
}
