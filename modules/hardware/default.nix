inputs:
{
  options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
  {
    bluetooth.enable = mkOption { type = types.bool; default = false; };
    joystick.enable = mkOption { type = types.bool; default = false; };
    printer.enable = mkOption { type = types.bool; default = false; };
    sound.enable = mkOption { type = types.bool; default = false; };
    cpus = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
    gpus = mkOption { type = types.listOf (types.enum [ "intel" "nvidia" ]); default = []; };
    prime =
    {
      enable = mkOption { type = types.bool; default = false; };
      mode = mkOption { type = types.enum [ "offload" "sync" ]; default = "offload"; };
      busId = mkOption { type = types.attrsOf types.str; default = {}; };
    };
    gamemode.drmDevice = mkOption { type = types.int; default = 0; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.config.nixos) hardware;
      inherit (builtins) listToAttrs map concatLists;
      inherit (inputs.localLib) attrsToList;
    in mkMerge
    [
      # bluetooth
      (mkIf hardware.bluetooth.enable { hardware.bluetooth.enable = true; })
      # joystick
      (mkIf hardware.joystick.enable { hardware = { xone.enable = true; xpadneo.enable = true; }; })
      # printer
      (
        mkIf hardware.printer.enable
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
        mkIf hardware.sound.enable
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
        mkIf (hardware.cpus != [])
        {
          hardware.cpu = listToAttrs
            (map (name: { inherit name; value = { updateMicrocode = true; }; }) hardware.cpus);
          boot.initrd.availableKernelModules =
            let
              modules =
              {
                intel = [ "intel_cstate" "aesni_intel" ];
                amd = [];
              };
            in
              concatLists (map (cpu: modules.${cpu}) hardware.cpus);
        }
      )
      # gpus
      (
        mkIf (hardware.gpus != [])
        {
          boot.initrd.availableKernelModules =
            let
              modules =
              {
                intel = [ "i915" ];
                nvidia = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
              };
            in
              concatLists (map (gpu: modules.${gpu}) hardware.gpus);
          hardware =
          {
            opengl =
            {
              enable = true;
              driSupport = true;
              extraPackages =
                with inputs.pkgs;
                let
                  packages =
                  {
                    intel = [ intel-compute-runtime intel-media-driver intel-vaapi-driver libvdpau-va-gl ];
                    nvidia = [ vaapiVdpau ];
                  };
                in
                  concatLists (map (gpu: packages.${gpu}) hardware.gpus);
              driSupport32Bit = true;
            };
            nvidia.nvidiaSettings = builtins.elem "nvidia" hardware.gpus;
          };
        }
      )
      (
        mkIf (builtins.elem "intel" hardware.gpus)
        {
          services.xserver.deviceSection =
          ''
            Identifier "Intel Graphics"
            Driver "intel"
          '';
        }
      )
      # prime
      (
        mkIf hardware.prime.enable
        {
          hardware.nvidia = mkMerge
          [
            (
              mkIf (hardware.prime.mode == "offload")
              {
                prime.offload = { enable = true; enableOffloadCmd = true; };
                powerManagement = { finegrained = true; enable = true; };
              }
            )
            (
              mkIf (hardware.prime.mode == "sync")
              {
                prime = { sync.enable = true; };
                # prime.forceFullCompositionPipeline = true;
              }
            )
            {
              prime = listToAttrs
                (map (gpu: { inherit (gpu) value; name = "${gpu.name}BusId"; }) (attrsToList hardware.prime.busId));
            }
            
          ];
        }
      )
      { programs.gamemode.settings.gpu.gpu_device = "${toString hardware.gamemode.drmDevice}"; }
    ];
}
