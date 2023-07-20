{ intelBusId, nvidiaBusId }: inputs:
{
	config =
	{
		services.xserver.videoDrivers = inputs.lib.mkBefore [ "intel" "nvidia" ];
		hardware.nvidia.prime =
		{
			offload = { enable = true; enableOffloadCmd = true; };
			# sync.enable = true;
			# forceFullCompositionPipeline = true;
			intelBusId = intelBusId;
			nvidiaBusId = nvidiaBusId;
		};
		hardware.nvidia.powerManagement = { finegrained = true; enable = true; };
	};
}
