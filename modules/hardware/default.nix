inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.hardware =
    let
      inherit (inputs.lib) mkOption types;
      default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
    in
    {
      joystick = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      printer = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      sound = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
    };
  config = let inherit (inputs.config.nixos) hardware; in inputs.lib.mkMerge
  [
    # joystick
    (inputs.lib.mkIf (hardware.joystick != null) { hardware = { xone.enable = true; xpadneo.enable = true; }; })
    # printer
    (
      inputs.lib.mkIf (hardware.printer != null)
      {
        services =
        {
          printing =
          {
            enable = true;
            drivers = [ inputs.pkgs.cnijfilter2 ];
            # TODO: remove in next update
            browsed.enable = false;
          };
          avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
        };
      }
    )
    # sound
    (
      inputs.lib.mkIf (hardware.sound != null)
      {
        services.pulseaudio.enable = false;
        services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
        security.rtkit.enable = true;
      }
    )
  ];
}
