inputs: {
  options.nixos.system.sysctl =
    let
      inherit (inputs.lib) mkOption types;
    in
    {
      laptop-mode = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
    };
  config =
    let
      inherit (inputs.config.nixos.system) sysctl;
    in
    inputs.lib.mkMerge [
      {
        boot.kernel.sysctl = {
          "vm.oom_kill_allocating_task" = true;
          "vm.oom_dump_tasks" = false;
          "vm.overcommit_memory" = inputs.lib.mkDefault 1;
          # enable all sysrq
          "kernel.sysrq" = 1;
          # set to larger value, otherwise the system will be very slow on low memory machines
          "vm.vfs_cache_pressure" = 100;
          # when building archive, nix need more than 100k mounts
          "fs.mount-max" = 1000000;
          # use bbr
          "net.core.default_qdisc" = "fq";
          "net.ipv4.tcp_congestion_control" = "bbr";
          # other optimize recommended by gemini
          "net.ipv4.tcp_max_tw_buckets" = 262144;
          "net.ipv4.tcp_fin_timeout" = 15;
          "net.ipv4.tcp_keepalive_time" = 600;
          "net.ipv4.tcp_keepalive_intvl" = 30;
          "net.ipv4.tcp_keepalive_probes" = 5;
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.ipv4.tcp_no_metrics_save" = 1;
          "net.ipv4.tcp_fastopen" = 3;
          "net.ipv4.tcp_notsent_lowat" = 16384;
          "net.netfilter.nf_conntrack_max" = 1048576;
          "net.nf_conntrack_max" = 1048576;
          "net.netfilter.nf_conntrack_tcp_timeout_established" = 21600;
          "vm.swappiness" = 10;
        };
      }
      (inputs.lib.mkIf (sysctl.laptop-mode != null) {
        boot.kernel.sysctl."vm.laptop_mode" = sysctl.laptop-mode;
      })
    ];
}
