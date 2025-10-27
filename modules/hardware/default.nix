inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.hardware =
    let
      inherit (inputs.lib) mkOption types;
      genericOption = mkOption
      {
        type = types.nullOr (types.submodule {});
        default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
      };
    in
    { joystick = genericOption; printer = genericOption; sound = genericOption; bolt = genericOption; };
  config = let inherit (inputs.config.nixos) hardware; in inputs.lib.mkMerge
  [
    (inputs.lib.mkIf (hardware.joystick != null) { hardware = { xone.enable = true; xpadneo.enable = true; }; })
    (
      inputs.lib.mkIf (hardware.printer != null)
      {
        services =
        {
          printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
          avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
        };
      }
    )
    (
      inputs.lib.mkIf (hardware.sound != null)
      {
        services.pulseaudio.enable = false;
        services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
        security.rtkit.enable = true;
      }
    )
    (inputs.lib.mkIf (hardware.bolt != null) { services.hardware.bolt.enable = true; })
  ];
}
