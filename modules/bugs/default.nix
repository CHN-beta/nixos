inputs:
	let
		inherit (inputs.localLib) stripeTabs;
		inherit (builtins) map attrNames;
		inherit (inputs.lib) mkMerge mkIf mkOption types;
		bugs =
		{
			# intel i915 hdmi
			intel-hdmi.boot.kernelPatches = [{ name = "intel-hdmi"; patch = ./intel-hdmi.patch; }];
			# suspend & hibernate do not use platform
			suspend-hibernate-no-platform.systemd.sleep.extraConfig = stripeTabs
			"
				SuspendState=freeze
				HibernateMode=shutdown
			";
			# reload iwlwifi after resume from hibernate
			hibernate-iwlwifi.systemd.services.reload-iwlwifi-after-hibernate =
			{
				description = "reload iwlwifi after resume from hibernate";
				after = [ "systemd-hibernate.service" ];
				serviceConfig.Type = "oneshot";
				script = let modprobe = "${inputs.pkgs.kmod}/bin/modprobe"; in stripeTabs
				"
					${modprobe} -r iwlwifi
					${modprobe} iwlwifi
					echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
				";
				wantedBy = [ "systemd-hibernate.service" ];
			};
			# disable wakeup on lid open
			suspend-lid-no-wakeup.systemd.services.lid-no-wakeup =
			{
				description = "lid no wake up";
				serviceConfig.Type = "oneshot";
				script =
					let
						cat = "${inputs.pkgs.coreutils}/bin/cat";
						grep = "${inputs.pkgs.gnugrep}/bin/grep";
					in stripeTabs
					"
						if ${cat} /proc/acpi/wakeup | ${grep} LID0 | ${grep} -q enabled
						then
							echo LID0 > /proc/acpi/wakeup
						fi
					";
				wantedBy = [ "multi-user.target" ];
			};
			# xmunet use old encryption
			xmunet.nixpkgs.config.packageOverrides = pkgs: 
			{
				wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs (attrs: { patches = attrs.patches ++ [ ./xmunet.patch ];});
			};
			suspend-hibernate-waydroid.systemd.services =
				let
					systemctl = "${inputs.pkgs.systemd}/bin/systemctl";
				in
				{
					"waydroid-hibernate" =
					{
						description = "waydroid hibernate";
						wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						serviceConfig.Type = "oneshot";
						script = "${systemctl} stop waydroid-container";
					};
					"waydroid-resume" =
					{
						description = "waydroid resume";
						wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						serviceConfig.Type = "oneshot";
						script = "${systemctl} start waydroid-container";
					};
				};
		};
	in
		{
			options.nixos.bugs = mkOption
			{
				type = types.listOf (types.enum (attrNames bugs));
				default = [];
			};
			config = mkMerge (map (bug: mkIf (builtins.elem bug inputs.config.nixos.bugs) bugs.${bug}) (attrNames bugs));
		}
