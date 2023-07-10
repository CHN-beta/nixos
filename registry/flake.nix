{
	description = "CNH's NixOS Flake";

	inputs.nixos.url = "github:CHN-beta/nixos/main";

	outputs = inputs: { inherit (inputs.nixos.nixosConfigurations) pkgs; };
}
