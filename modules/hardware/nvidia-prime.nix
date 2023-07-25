{ intelBusId, nvidiaBusId }: inputs:
{
	config =
	{
		services.xserver.videoDrivers = [ "nvidia" "intel" ];
		hardware.nvidia.prime =
		{
			offload = { enable = true; enableOffloadCmd = true; };
			# sync.enable = true;
			# forceFullCompositionPipeline = true;
			intelBusId = intelBusId;
			nvidiaBusId = nvidiaBusId;
		};
		hardware.nvidia.powerManagement = { finegrained = true; enable = true; };
		hardware.nvidia.nvidiaSettings = true;
		services.xserver.deviceSection = ''Driver "modesetting"'';
	};
}
