inputs:
{
  options.nixos.system.sysctl = let inherit (inputs.lib) mkOption types; in
  {
    laptop-mode = mkOption { type = types.nullOr types.int; default = null; };
  };
  config = let inherit (inputs.config.nixos.system) sysctl; in inputs.lib.mkMerge
  [
    {
      boot.kernel.sysctl =
      {
        "vm.oom_kill_allocating_task" = true;
        "vm.oom_dump_tasks" = false;
        "vm.overcommit_memory" = 1;
        "kernel.sysrq" = 438;
      };
    }
    (inputs.lib.mkIf (sysctl.laptop-mode != null) { boot.kernel.sysctl."vm.laptop_mode" = sysctl.laptop-mode; })
  ];
}
