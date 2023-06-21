{ pkgs, ... }@inputs:
{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		services.dbus.implementation = "broker";
		programs.dconf.enable = true;
		hardware.opengl.enable = true;
		systemd.services =
		{
			reload-iwlwifi-after-hibernate =
			{
				description = "reload iwlwifi after resume from hibernate";
				after = [ "systemd-hibernate.service" ];
				serviceConfig =
				{
					Type = "oneshot";
					ExecStart =
					[
						"${pkgs.kmod}/bin/modprobe -r iwlwifi"
						"${pkgs.kmod}/bin/modprobe iwlwifi"
						"${pkgs.bash}/bin/bash -c '<<< 0 > /sys/devices/system/cpu/intel_pstate/no_turbo'"
					];
				};
				wantedBy = [ "systemd-hibernate.service" ];
			};
			lid-no-wakeup =
			{
				description = "lid no wake up";
				serviceConfig.ExecStart = "${pkgs.bash}/bin/bash -c '<<< LID0 > /proc/acpi/wakeup'";
				wantedBy = [ "multi-user.target" ];
			};
		};
		boot.kernel.sysctl =
		{
			"net.core.rmem_max" = 67108864;
			"net.core.wmem_max" = 67108864;
			# check
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
