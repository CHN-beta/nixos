inputs:
{
	options.nixos.bugs = let inherit (inputs.lib) mkOption types; in mkOption
	{
		type = types.listOf (types.enum
		[
			# intel i915 hdmi
			"intel-hdmi"
			# suspend & hibernate do not use platform
			"suspend-hibernate-no-platform"
			# reload iwlwifi after resume from hibernate
			"hibernate-iwlwifi"
			# disable wakeup on lid open
			"suspend-lid-no-wakeup"
		]);
		default = [];
	};
	config =
		let
			inherit (inputs.localLib) stripeTabs;
			inherit (builtins) map;
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.config) bugs;
			patches =
			{
				intel-hdmi.boot.kernelPatches = { name = "intel-hdmi"; patch = ./intel-hdmi.patch; };
				suspend-hibernate-no-platform.systemd.sleep.extraConfig = stripeTabs
				"
					SuspendState=freeze
					HibernateMode=shutdown
				";
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
			};
		in
			mkMerge (map (bug: patches.${bug}) bugs);
}
