{ pkgs, ... }@inputs:
{
	config =
	{
		nix.settings.system-features = [ "nixos-test" "benchmark" "kvm" "gccarch-alderlake" ];
		nixpkgs =
		{
			hostPlatform = { system = "x86_64-linux"; gcc = { arch = "alderlake"; tune = "alderlake"; }; };
			config.allowUnfree = true;
			overlays =
			[(
				final: prev: let generic-pkgs = (inputs.topInputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					modules = [{ config.nixpkgs.config.allowUnfree = true; }];
				}).pkgs;
				in
				{
					mono = generic-pkgs.mono;
					pandoc = generic-pkgs.pandoc;
					fwupd = generic-pkgs.fwupd;
				}
			)];
		};
		services.dbus.implementation = "broker";
		programs.dconf.enable = true;
		hardware.opengl.extraPackages = with inputs.pkgs; [ intel-media-driver intel-ocl ];
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
		boot.kernel.sysctl =
		{
			"net.core.rmem_max" = 67108864;
			"net.core.wmem_max" = 67108864;
			"net.ipv4.tcp_rmem" = "4096 87380 67108864";
			"net.ipv4.tcp_wmem" = "4096 65536 67108864";
			"net.ipv4.tcp_mtu_probing" = true;
			"net.ipv4.tcp_tw_reuse" = true;
			"vm.swappiness" = 10;
			"net.ipv4.tcp_max_syn_backlog" = 8388608;
			"net.core.netdev_max_backlog" = 8388608;
			"net.core.somaxconn" = 8388608;
			"vm.oom_kill_allocating_task" = true;
			"vm.oom_dump_tasks" = false;
			"vm.overcommit_kbytes" = 22020096;
			"dev.i915.perf_stream_paranoid" = false;
		};
	};
}
