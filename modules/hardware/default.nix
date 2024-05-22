inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.hardware =
    let
      inherit (inputs.lib) mkOption types;
      default = if inputs.config.nixos.system.gui.enable then {} else null;
    in
    {
      bluetooth = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      joystick = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      printer = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      sound = mkOption { type = types.nullOr (types.submodule {}); inherit default; };
      cpus = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
    };
  config = let inherit (inputs.config.nixos) hardware; in inputs.lib.mkMerge
  [
    # bluetooth
    (inputs.lib.mkIf (hardware.bluetooth != null) { hardware.bluetooth.enable = true; })
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
            drivers = inputs.lib.mkIf (inputs.config.nixos.system.nixpkgs.arch == "x86_64") [ inputs.pkgs.cnijfilter2 ];
          };
          avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
        };
      }
    )
    # sound
    (
      inputs.lib.mkIf (hardware.sound != null)
      {
        hardware.pulseaudio.enable = false;
        services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
        sound.enable = true;
        security.rtkit.enable = true;
      }
    )
    # cpus
    (
      inputs.lib.mkIf (hardware.cpus != [])
      {
        hardware.cpu = builtins.listToAttrs
          (map (name: { inherit name; value = { updateMicrocode = true; }; }) hardware.cpus);
        boot.initrd.availableKernelModules =
          let
            modules =
            {
              intel =
              [
                "intel_cstate" "aesni_intel" "intel_cstate" "intel_uncore" "intel_uncore_frequency" "intel_powerclamp"
              ];
              amd = [];
            };
          in
            builtins.concatLists (map (cpu: modules.${cpu}) hardware.cpus);
      }
    )
  ];
}
