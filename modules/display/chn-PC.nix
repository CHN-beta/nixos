{
	config =
	{
		services.xserver.videoDrivers = [ "nvidia" "intel" "qxl" ];
		hardware.nvidia.prime =
		{
			offload.enable = true;
			intelBusId = "PCI:0:2:0";
			nvidiaBusId = "PCI:1:0:0";
		};
	}
}
