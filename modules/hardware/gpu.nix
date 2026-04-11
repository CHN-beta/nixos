{ config, lib, pkgs, ... }:
{
  options.nixos.hardware.gpu =
  {
    type = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "intel" "nvidia" "amd" ]); default = null; };
    nvidia =
    {
      dynamicBoost = lib.mkOption { type = lib.types.bool; default = false; };
      open = lib.mkOption { type = lib.types.bool; default = true; };
      datacenter = lib.mkOption { type = lib.types.bool; default = false; };
      driver = lib.mkOption
      {
        type = lib.types.enum [ "production" "latest" "beta" "dc" ];
        default = if config.nixos.hardware.gpu.nvidia.datacenter then "dc" else "production";
      };
      persistence = lib.mkOption { type = lib.types.bool; default = !config.nixos.hardware.gpu.nvidia.dynamicBoost; };
      disableFabricmanager = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };
  config = let inherit (config.nixos.hardware) gpu; in lib.mkIf (gpu.type != null) (lib.mkMerge
  [
    # generic settings
    (
      let gpus = lib.strings.splitString "+" gpu.type; in
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
              let packages = with pkgs;
              {
                # TODO: import from nixos-hardware instead
                # enableHybridCodec is only needed for some old intel gpus (Atom, Nxxx, etc)
                intel =
                  [ intel-vaapi-driver libvdpau-va-gl intel-media-driver ];
                nvidia = [ libva-vdpau-driver ];
                amd = [];
              };
              in packages.${gpu.type} ++ (with pkgs;
              [
                vulkan-loader vulkan-validation-layers vulkan-extension-layer
                vulkan-tools
              ]);
          };
          nvidia = lib.mkIf (gpu.type == "nvidia")
          {
            modesetting.enable = true;
            powerManagement.enable = true;
            dynamicBoost.enable = gpu.nvidia.dynamicBoost;
            nvidiaSettings = true;
            package = config.boot.kernelPackages.nvidiaPackages.${gpu.nvidia.driver};
            inherit (gpu.nvidia) open;
            prime.allowExternalGpu = true;
            datacenter.enable = gpu.nvidia.datacenter;
            nvidiaPersistenced = gpu.nvidia.persistence;
          };
        };
        services.xserver.videoDrivers =
          let driver =
          {
            intel = [ "modesetting" ];
            amd = [ "amdgpu" ];
            nvidia = lib.optionals (gpu.nvidia.driver != "dc") [ "nvidia" ];
          };
          in driver.${gpu.type};
        nixos.packages.packages._packages =
          let packages = with pkgs;
          {
            intel = [ intel-gpu-tools ];
            nvidia = [ nvtopPackages.full ];
            amd = [ radeontop rocmPackages.rocm-smi ];
          };
          in packages.${gpu.type};
        environment.etc."nvidia/nvidia-application-profiles-rc.d/vram" = lib.mkIf (gpu.type == "nvidia")
        {
          source = pkgs.writeText "save-vram" (builtins.toJSON
          {
            rules = [{ pattern = { feature = "true"; matches = ""; }; profile = "save-vram"; }];
            profiles = [{ name = "save-vram"; settings = [{ key = "GLVidHeapReuseRatio"; value = 0; }]; }];
          });
        };
      }
    )
    # amdgpu
    (
      lib.mkIf (lib.strings.hasPrefix "amd" gpu.type)
        { hardware.amdgpu = { opencl.enable = true; initrd.enable = true; legacySupport.enable = true; };}
    )
    # sometimes dc gpu without nvlink or nvswitch
    (lib.mkIf gpu.nvidia.disableFabricmanager { systemd.services.nvidia-fabricmanager.enable = lib.mkForce false; })
  ]);
}
