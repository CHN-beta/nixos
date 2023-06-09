{ intelBusId, nvidiaBusId }: { pkgs, ... }@inputs:
{
	config =
	{
		services.xserver.videoDrivers = [ "nvidia" "intel" ];
		hardware.nvidia.prime =
		{
			offload.enable = true;
			intelBusId = intelBusId;
			nvidiaBusId = nvidiaBusId;
		};
		environment.systemPackages =
		[(
			inputs.pkgs.writeShellScriptBin "nvidia-offload"
			''
				export __NV_PRIME_RENDER_OFFLOAD=1
				export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
				export __GLX_VENDOR_LIBRARY_NAME=nvidia
				export __VK_LAYER_NV_optimus=NVIDIA_only
				exec "$@"
			''
		)];
	};
}
