{
	config.sops =
	{
		defaultSopsFile = ../../secrets/chn-PC.yaml;
		age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
	};
}
