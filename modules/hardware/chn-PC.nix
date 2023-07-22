{ pkgs, ... }@inputs:
{
	config =
	{
		nixpkgs =
		{
			overlays =
			[(
				final: prev:
					let
						generic-pkgs = (inputs.topInputs.nixpkgs.lib.nixosSystem
						{
							system = "x86_64-linux";
							modules = [{ config.nixpkgs.config.allowUnfree = true; }];
						}).pkgs;
					in
						{
							# pandoc = generic-pkgs.pandoc;
							# fwupd = generic-pkgs.fwupd;
						}
			)];
		};
		hardware.opengl =
		{
			extraPackages = with inputs.pkgs; [ intel-media-driver intel-ocl ];
			driSupport32Bit = true;
		};
		systemd.services =
		{
			reload-iwlwifi-after-hibernate =
			{
				description = "reload iwlwifi after resume from hibernate";
				after = [ "systemd-hibernate.service" ];
				serviceConfig =
				{
					Type = "oneshot";
					ExecStart = let inherit (inputs.pkgs) kmod bash; in
					[
						"${kmod}/bin/modprobe -r iwlwifi" "${kmod}/bin/modprobe iwlwifi"
						"${bash}/bin/bash -c 'echo 0 /sys/devices/system/cpu/intel_pstate/no_turbo'"
					];
				};
				wantedBy = [ "systemd-hibernate.service" ];
			};
			lid-no-wakeup =
			{
				description = "lid no wake up";
				serviceConfig.ExecStart = let inherit (inputs.pkgs) bash coreutils gnugrep; in
					"${bash}/bin/bash -c '"
						+ "if ${coreutils}/bin/cat /proc/acpi/wakeup | "
						+ "${gnugrep}/bin/grep LID0 | "
						+ "${gnugrep}/bin/grep -q enabled; then "
							+ "echo LID0 > /proc/acpi/wakeup; "
						+ "fi"
					+ "'";
				wantedBy = [ "multi-user.target" ];
			};
		};
	};
}
