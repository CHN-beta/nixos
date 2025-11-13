inputs:
{
  options.nixos.hardware.gpu = let inherit (inputs.lib) mkOption types; in
  {
    type = mkOption { type = types.nullOr (types.enum [ "intel" "nvidia" "amd" ]); default = null; };
    nvidia =
    {
      dynamicBoost = mkOption { type = types.bool; default = false; };
      driver = mkOption { type = types.enum [ "production" "latest" "beta" ]; default = "production"; };
      open = mkOption { type = types.bool; default = true; };
    };
  };
  config = let inherit (inputs.config.nixos.hardware) gpu; in inputs.lib.mkIf (gpu.type != null) (inputs.lib.mkMerge
  [
    # generic settings
    (
      let gpus = inputs.lib.strings.splitString "+" gpu.type; in
      {
        boot =
        {
          initrd.availableKernelModules =
            {
              intel = [ "i915" ];
              nvidia = []; # early loading breaks resume from hibernation
              amd = [];
            }.${gpu.type};
          blacklistedKernelModules = [ "nouveau" ];
        };
        hardware =
        {
          graphics =
          {
            enable = true;
            extraPackages =
              let packages = with inputs.pkgs;
              {
                # TODO: import from nixos-hardware instead
                # enableHybridCodec is only needed for some old intel gpus (Atom, Nxxx, etc)
                intel = [ intel-vaapi-driver libvdpau-va-gl intel-media-driver ];
                nvidia = [ vaapiVdpau ];
                amd = [];
              };
              in packages.${gpu.type};
          };
          nvidia = inputs.lib.mkIf (gpu.type == "nvidia")
          {
            modesetting.enable = true;
            powerManagement.enable = true;
            dynamicBoost.enable = inputs.lib.mkIf gpu.nvidia.dynamicBoost true;
            nvidiaSettings = true;
            package = inputs.config.boot.kernelPackages.nvidiaPackages.${gpu.nvidia.driver};
            inherit (gpu.nvidia) open;
            prime.allowExternalGpu = true;
          };
        };
        services.xserver.videoDrivers =
          let driver = { intel = "modesetting"; amd = "amdgpu"; nvidia = "nvidia"; };
          in [ driver.${gpu.type} ];
        nixos.packages.packages._packages =
          let packages = with inputs.pkgs;
          {
            intel = [ intel-gpu-tools ];
            nvidia = [ nvtopPackages.full ];
            amd = [ radeontop ];
          };
          in packages.${gpu.type};
        environment.etc."nvidia/nvidia-application-profiles-rc.d/vram" = inputs.lib.mkIf (gpu.type == "nvidia")
        {
          source = inputs.pkgs.writeText "save-vram" (builtins.toJSON
          {
            rules = [{ pattern = { feature = "true"; matches = ""; }; profile = "save-vram"; }];
            profiles = [{ name = "save-vram"; settings = [{ key = "GLVidHeapReuseRatio"; value = 0; }]; }];
          });
        };
      }
    )
    # amdgpu
    (
      inputs.lib.mkIf (inputs.lib.strings.hasPrefix "amd" gpu.type)
        { hardware.amdgpu = { opencl.enable = true; initrd.enable = true; legacySupport.enable = true; };}
    )
  ]);
}
