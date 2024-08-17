inputs:
{
  options.nixos.hardware.gpu = let inherit (inputs.lib) mkOption types; in
  {
    type = mkOption
    {
      type = types.nullOr (types.enum
      [
        # single gpu
        "intel" "nvidia" "amd"
        # hibrid gpu: use nvidia prime offload mode
        "intel+nvidia" "amd+nvidia"
      ]);
      default = null;
    };
    nvidia =
    {
      dynamicBoost = mkOption { type = types.bool; default = false; };
      prime =
      {
        mode = mkOption { type = types.enum [ "offload" "sync" ]; default = "offload"; };
        busId = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      };
      driver = mkOption { type = types.enum [ "production" "latest" "beta" ]; default = "production"; };
    };
  };
  config = let inherit (inputs.config.nixos.hardware) gpu; in inputs.lib.mkIf (gpu.type != null) (inputs.lib.mkMerge
  [
    # generic settings
    (
      let gpus = inputs.lib.strings.splitString "+" gpu.type; in
      {
        boot.initrd.availableKernelModules =
          let modules =
          {
            intel = [ "i915" ];
            nvidia = []; # early loading breaks resume from hibernation
            amd = [];
          };
          in builtins.concatLists (builtins.map (gpu: modules.${gpu}) gpus);
        hardware =
        {
          graphics =
          {
            enable = true;
            extraPackages =
              let packages = with inputs.pkgs;
              {
                intel = [ intel-vaapi-driver libvdpau-va-gl intel-media-driver ];
                nvidia = [ vaapiVdpau ];
                amd = [];
              };
              in builtins.concatLists (builtins.map (gpu: packages.${gpu}) gpus);
          };
          nvidia = inputs.lib.mkIf (builtins.elem "nvidia" gpus)
          {
            modesetting.enable = true;
            powerManagement.enable = true;
            dynamicBoost.enable = inputs.lib.mkIf gpu.nvidia.dynamicBoost true;
            nvidiaSettings = true;
            forceFullCompositionPipeline = true;
            package = inputs.config.boot.kernelPackages.nvidiaPackages.${gpu.nvidia.driver};
            open = true; # TODO: remove when 560 is stable
            prime.allowExternalGpu = true;
          };
        };
        boot.blacklistedKernelModules = [ "nouveau" ];
        environment.variables.VDPAU_DRIVER = inputs.lib.mkIf (builtins.elem "intel" gpus) "va_gl";
        services.xserver.videoDrivers =
          let driver = { intel = "modesetting"; amd = "amdgpu"; nvidia = "nvidia"; };
          in builtins.map (gpu: driver.${gpu}) gpus;
      }
    )
    # nvidia prime offload
    (
      inputs.lib.mkIf (inputs.lib.strings.hasSuffix "+nvidia" gpu.type) { hardware.nvidia =
      {
        prime =
        {
          offload = inputs.lib.mkIf (gpu.nvidia.prime.mode == "offload") { enable = true; enableOffloadCmd = true; };
          sync = inputs.lib.mkIf (gpu.nvidia.prime.mode == "sync") { enable = true; };
        }
        // builtins.listToAttrs (builtins.map
          (gpu: { name = "${if gpu.name == "amd" then "amdgpu" else gpu.name}BusId"; value = "PCI:${gpu.value}"; })
          (inputs.localLib.attrsToList gpu.nvidia.prime.busId));
        powerManagement.finegrained = inputs.lib.mkIf (gpu.nvidia.prime.mode == "offload") true;
      };}
    )
    # amdgpu
    (
      inputs.lib.mkIf (inputs.lib.strings.hasPrefix "amd" gpu.type) { hardware.amdgpu =
      {
        opencl.enable = true;
        legacySupport.enable = true;
        initrd.enable = true;
        amdvlk = { enable = true; support32Bit.enable = true; supportExperimental.enable = true; };
      };}
    )
  ]);
}
