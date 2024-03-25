inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
  {
    bluetooth = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
    joystick = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
    printer = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
    sound = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
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
          printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
          avahi = { enable = true; nssmdns = true; openFirewall = true; };
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
        environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
          let
            content = builtins.readFile
              (inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
            matched = builtins.match
              ".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
            spaces = builtins.elemAt matched 0;
            comment = builtins.elemAt matched 1;
            config = ''["session.suspend-timeout-seconds"] = 0'';
          in
            builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
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
