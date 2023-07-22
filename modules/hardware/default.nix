inputs:
{
	options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
	{
		bluetooth.enable = mkOption { type = types.bool; default = false; };
		joystick.enable = mkOption { type = types.bool; default = false; };
		printer.enable = mkOption { type = types.bool; default = false; };
		sound.enable = mkOption { type = types.bool; default = false; };
		cpu = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
		gpu = mkOption { type = types.listOf (types.enum [ "intel" "nvidia" ]); default = []; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
	[
		# bluetooth
		(mkIf inputs.config.nixos.hardware.bluetooth.enable { hardware.bluetooth.enable = true; })
		# joystick
		(mkIf inputs.config.nixos.hardware.joystick.enable { hardware = { xone.enable = true; xpadneo.enable = true; }; })
		# printer
		(
			mkIf inputs.config.nixos.hardware.printer.enable
			{
				services =
				{
					printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
					avahi = { enable = true; nssmdns = true; openFirewall = true; };
				};
			}
		)
		# sound
		(
			mkIf inputs.config.nixos.hardware.sound.enable
			{
				hardware.pulseaudio.enable = false;
				services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
				sound.enable = true;
				security.rtkit.enable = true;
				environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
					let
						content = builtins.readFile
							("/." + inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
						matched = builtins.match
							".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
						spaces = builtins.elemAt matched 0;
						comment = builtins.elemAt matched 1;
						config = ''["session.suspend-timeout-seconds"] = 0'';
					in
						builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
			}
		)
		# cpu
		{
			hardware.cpu = builtins.listToAttrs (builtins.map
				(name: { inherit name; value = { updateMicrocode = true; }; })
				inputs.config.nixos.hardware.cpu);
			boot.initrd.availableKernelModules =
				let
					modules =
					{
						intel = [ "intel_cstate" "aesni_intel" ];
						amd = [];
					};
				in
					builtins.concatLists (builtins.map (cpu: modules.${cpu}) inputs.config.nixos.hardware.cpu);
		}
		# gpu
		{
			boot.initrd.availableKernelModules =
				let
					modules =
					{
						intel = [ "i915" ];
						nvidia = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
					};
				in
					builtins.concatLists (builtins.map (cpu: modules.${cpu}) inputs.config.nixos.hardware.cpu);
		}
	];
}
