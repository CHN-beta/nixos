{ localLib, lib, config, pkgs, ... }:
{
  imports = localLib.findModules ./.;
  options.nixos.hardware =
    let genericOption = lib.mkOption
    {
      type = lib.types.nullOr (lib.types.submodule {});
      default = if builtins.elem config.nixos.model.type [ "desktop" "server" ] then {} else null;
    };
    in { joystick = genericOption; printer = genericOption; sound = genericOption; bolt = genericOption; };
  config = let inherit (config.nixos) hardware; in lib.mkMerge
  [
    (lib.mkIf (hardware.joystick != null) { hardware = { xone.enable = true; xpadneo.enable = true; }; })
    (
      lib.mkIf (hardware.printer != null)
      {
        services =
        {
          printing = { enable = true; drivers = [ pkgs.cnijfilter2 ]; };
          avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
        };
      }
    )
    (
      lib.mkIf (hardware.sound != null)
      {
        services.pulseaudio.enable = false;
        services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
        security.rtkit.enable = true;
      }
    )
    (lib.mkIf (hardware.bolt != null) { services.hardware.bolt.enable = true; })
    (lib.mkIf (config.nixos.model.arch == "x86_64") { hardware.cpu.x86.msr.enable = true; })
  ];
}
