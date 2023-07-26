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
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.config.nixos) hardware;
			inherit (builtins) listToAttrs map concatLists;
		in mkMerge
		[
			# bluetooth
			(mkIf hardware.bluetooth.enable { hardware.bluetooth.enable = true; })
			# joystick
			(mkIf hardware.joystick.enable { hardware = { xone.enable = true; xpadneo.enable = true; }; })
			# printer
			(
				mkIf hardware.printer.enable
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
				mkIf hardware.sound.enable
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
			(
				mkIf (hardware.cpu != [])
				{
					hardware.cpu = listToAttrs (map (name: { inherit name; value = { updateMicrocode = true; }; }) hardware.cpu);
					boot.initrd.availableKernelModules =
						let
							modules =
							{
								intel = [ "intel_cstate" "aesni_intel" ];
								amd = [];
							};
						in
							concatLists (map (cpu: modules.${cpu}) hardware.cpu);
				}
			)
			# gpu
			(
				mkIf (hardware.gpu != [])
				{
					boot.initrd.availableKernelModules =
						let
							modules =
							{
								intel = [ "i915" ];
								nvidia = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
							};
						in
							concatLists (map (gpu: modules.${gpu}) hardware.gpu);
					hardware.opengl =
					{
						enable = true;
						driSupport = true;
						extraPackages =
							with inputs.pkgs;
							let
								packages =
								{
									intel = [ intel-compute-runtime intel-media-driver intel-vaapi-driver libvdpau-va-gl ];
									nvidia = [ vaapiVdpau ];
								};
							in
								concatLists (map (gpu: packages.${gpu}) hardware.gpu);
						driSupport32Bit = true;
					};
				}
			)
		];
}
