inputs:
{
	config.sops =
	{
		defaultSopsFile = ../secrets/${inputs.config.networking.hostName}.yaml;

		# sops start before impermanence, so we need to use the absolute path
		age.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_ed25519_key" ];
		gnupg.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_rsa_key" ];
	};
}
