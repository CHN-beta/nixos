{
	config.virtualisation.docker =
	{
		enable = true;
		rootless = { enable = true; setSocketVariable = true; };
		enableNvidia = true;
		storageDriver = "overlay2";
	};
}
