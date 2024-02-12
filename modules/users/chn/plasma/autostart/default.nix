inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config.home.file =
      let
        devices =
        {
          pc = [ "nheko" "kclockd" "yakuake" "telegram" ];
          surface = [ "kclockd" "yakuake" "telegram" ];
        };
      in builtins.listToAttrs (builtins.map
        (file: { name = ".config/autostart/${file}.desktop"; value.source = ./. + "/${file}.desktop"; })
        (devices.${inputs.config.nixos.system.networking.hostname}));
    environment.persistence =
      let impermanence = inputs.config.nixos.system.impermanence;
      in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.root}".users.chn.directories = [ ".config/autostart" ];
      };
  };
}
