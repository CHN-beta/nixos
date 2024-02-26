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
    dynamicBoost = mkOption { type = types.bool; default = false; };
    prime.busId = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
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
            driSupport = true;
            driSupport32Bit = true;
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
            dynamicBoost.enable = inputs.lib.mkIf gpu.dynamicBoost true;
            nvidiaSettings = true;
            forceFullCompositionPipeline = true;
            # package = inputs.config.boot.kernelPackages.nvidiaPackages.production;
            prime.allowExternalGpu = true;
          };
        };
        boot =
        {
          kernelParams = inputs.lib.mkIf (builtins.elem "amd" gpus)
            [ "radeon.cik_support=0" "amdgpu.cik_support=1" "radeon.si_support=0" "amdgpu.si_support=1" "iommu=pt" ];
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
        prime = { offload = { enable = true; enableOffloadCmd = true; }; }
          // builtins.listToAttrs (builtins.map
            (gpu: { name = "${if gpu.name == "amd" then "amdgpu" else gpu.name}BusId"; value = "PCI:${gpu.value}"; })
            (inputs.localLib.attrsToList gpu.prime.busId));
        powerManagement.finegrained = true;
      };}
    )
  ]);
}
