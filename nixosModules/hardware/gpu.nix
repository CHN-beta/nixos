{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.nixos.hardware.gpu = {
    type = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.listOf (
          lib.types.enum [
            "intel"
            "nvidia"
            "amd"
          ]
        )
      );
      default = null;
    };
    nvidia = {
      dynamicBoost = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      open = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      datacenter = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      driver = lib.mkOption {
        type = lib.types.enum [
          "production"
          "latest"
          "beta"
          "dc"
        ];
        default = if config.nixos.hardware.gpu.nvidia.datacenter then "dc" else "production";
      };
      persistence = lib.mkOption {
        type = lib.types.bool;
        default = !config.nixos.hardware.gpu.nvidia.dynamicBoost;
      };
      disableFabricmanager = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
  config =
    let
      inherit (config.nixos.hardware) gpu;
    in
    lib.mkIf (gpu.type != null) (
      lib.mkMerge [
        # generic settings
        {
          boot.blacklistedKernelModules = [ "nouveau" ];
          hardware.graphics = {
            enable = true;
            extraPackages = with pkgs; [
              vulkan-loader
              vulkan-validation-layers
              vulkan-extension-layer
              vulkan-tools
            ];
          };
        }
        # amdgpu
        (lib.mkIf (builtins.elem "amd" gpu.type) {
          hardware.amdgpu = {
            opencl.enable = true;
            initrd.enable = true;
            legacySupport.enable = true;
          };
          services.xserver.videoDrivers = [ "amdgpu" ];
          environment.systemPackages = with pkgs; [
            radeontop
            rocmPackages.rocm-smi
          ];
        })
        # intel
        (lib.mkIf (builtins.elem "intel" gpu.type) {
          boot.initrd.availableKernelModules = [ "i915" ];
          hardware.graphics.extraPackages = with pkgs; [
            intel-vaapi-driver
            libvdpau-va-gl
            intel-media-driver
          ];
          services.xserver.videoDrivers = [ "modesetting" ];
          environment.systemPackages = with pkgs; [ intel-gpu-tools ];
        })
        # nvidia
        (lib.mkIf (builtins.elem "nvidia" gpu.type) {
          # do not load nvidia kernel module in initrd, otherwise breaking hibernation
          # boot.initrd.availableKernelModules = [ "nvidia" ];
          hardware = {
            firmware = lib.optional (gpu.nvidia.driver == "dc") config.hardware.nvidia.package.firmware;
            graphics.extraPackages = with pkgs; [ libva-vdpau-driver ];
            nvidia = {
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
          services.xserver.videoDrivers = lib.optionals (gpu.nvidia.driver != "dc") [ "nvidia" ];
          environment = {
            etc."nvidia/nvidia-application-profiles-rc.d/vram" = lib.mkIf (gpu.type == "nvidia") {
              source = pkgs.writeText "save-vram" (
                builtins.toJSON {
                  rules = [
                    {
                      pattern = {
                        feature = "true";
                        matches = "";
                      };
                      profile = "save-vram";
                    }
                  ];
                  profiles = [
                    {
                      name = "save-vram";
                      settings = [
                        {
                          key = "GLVidHeapReuseRatio";
                          value = 0;
                        }
                      ];
                    }
                  ];
                }
              );
            };
            systemPackages = with pkgs; [ nvtopPackages.full ];
          };
          systemd.services.nvidia-fabricmanager = lib.mkIf gpu.nvidia.disableFabricmanager {
            enable = lib.mkForce false;
          };
        })
      ]
    );
}
