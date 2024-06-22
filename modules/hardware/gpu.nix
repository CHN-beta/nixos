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
      driver = mkOption { type = types.enum [ "production" "beta" ]; default = "production"; };
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
            nvidia = [ "nvidia" "nvidia_drm" "nvidia_modeset" ]; # nvidia-uvm should not be loaded
            amd = [ "amdgpu" ];
          };
          in builtins.concatLists (builtins.map (gpu: modules.${gpu}) gpus);
        hardware =
        {
          opengl =
          {
            enable = true;
            extraPackages =
              let packages = with inputs.pkgs;
              {
                intel = [ intel-vaapi-driver libvdpau-va-gl intel-media-driver ];
                nvidia = [ vaapiVdpau ];
                amd = [ amdvlk rocmPackages.clr rocmPackages.clr.icd ];
              };
              in builtins.concatLists (builtins.map (gpu: packages.${gpu}) gpus);
            extraPackages32 =
              let packages = { intel = []; nvidia = []; amd = [ inputs.pkgs.driversi686Linux.amdvlk ]; };
              in builtins.concatLists (builtins.map (gpu: packages.${gpu}) gpus);
          };
          nvidia = inputs.lib.mkIf (builtins.elem "nvidia" gpus)
          {
            modesetting.enable = true;
            powerManagement.enable = true;
            dynamicBoost.enable = inputs.lib.mkIf gpu.nvidia.dynamicBoost true;
            nvidiaSettings = true;
            forceFullCompositionPipeline = true;
            package =
              let actualDriver = { production = "legacy_535"; }.${gpu.nvidia.driver} or gpu.nvidia.driver;
              in inputs.config.boot.kernelPackages.nvidiaPackages.${actualDriver};
            prime.allowExternalGpu = true;
            # nvidia 555 package have some bug, should use open
            open = inputs.lib.mkIf (gpu.nvidia.driver == "beta") true;
          };
        };
        boot =
        {
          kernelParams = inputs.lib.mkIf (builtins.elem "amd" gpus)
            [ "radeon.cik_support=0" "amdgpu.cik_support=1" "radeon.si_support=0" "amdgpu.si_support=1" ];
          blacklistedKernelModules = [ "nouveau" ];
        };
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
  ]);
}
