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
    prime.busId = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
  };
  config = let inherit (inputs.config.nixos.hardware) gpu; in inputs.lib.mkIf (gpu.type != null) (inputs.lib.mkMerge
  [
    # generic settings, install drivers (but do not config)
    (
      let gpus = inputs.lib.strings.splitString "+" gpu.type; in
      {
        boot.initrd.availableKernelModules =
          let modules =
          {
            intel = [ "i915" ];
            nvidia = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
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
              with inputs.pkgs;
              let packages =
              {
                intel = [ intel-compute-runtime intel-media-driver libvdpau-va-gl ]; # intel-vaapi-driver
                nvidia = [ vaapiVdpau ];
                amd = [ amdvlk rocmPackages.clr rocmPackages.clr.icd ];
              };
              in builtins.concatLists (builtins.map (gpu: packages.${gpu}) gpus);
          };
          nvidia = inputs.lib.mkIf (builtins.elem "nvidia" gpus)
          {
            modesetting.enable = true;
            powerManagement.enable = true;
            dynamicBoost.enable = true;
            nvidiaSettings = true;
            # package = inputs.config.boot.kernelPackages.nvidiaPackages.production;
          };
        };
      }
    )
    # if use intel or amd as output, use modesetting; else, use nvidia
    {
      services.xserver.videoDrivers = inputs.localLib.mkConditional
        (builtins.any (primayGpu: inputs.lib.strings.hasPrefix primayGpu gpu.type) [ "intel" "amd" ])
        [ "modesetting" ] [ "nvidia" ];
    }
    # nvidia prime offload
    (
      inputs.lib.mkIf (inputs.lib.strings.hasSuffix "+nvidia" gpu.type) { hardware.nvidia =
      {
        prime =
        {
          offload = { enable = true; enableOffloadCmd = true; };
        }
        // builtins.listToAttrs (builtins.map
          (gpu: { name = "${gpu.name}BusId"; inherit (gpu) value; })
          (inputs.localLib.attrsToList gpu.prime.busId));
        powerManagement = { finegrained = true; enable = true; };
      };}
    )
  ]);
}
