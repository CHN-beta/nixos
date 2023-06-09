inputs:
{
	config.sops =
	{
		defaultSopsFile = ../secrets/${inputs.config.networking.hostName}.yaml;
		age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
	};
}
