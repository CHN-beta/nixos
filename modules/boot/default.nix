inputs:
{
  options.nixos.boot = let inherit (inputs.lib) mkOption types; in
  {
    network.enable = mkOption { type = types.bool; default = false; };
    sshd =
    {
      enable = mkOption { type = types.bool; default = false; };
      hostKeys = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) mkConditional attrsToList stripeTabs;
      inherit (inputs.config.nixos) boot;
      inherit (builtins) concatStringsSep map;
    in mkMerge
    [
      # generic
      {
        boot =
        {
          initrd.systemd.enable = true;
        };
      }
      # network
      (
        mkIf boot.network.enable
        { boot = { initrd.network.enable = true; kernelParams = [ "ip=dhcp" ]; }; }
      )
      # sshd
      (
        mkIf boot.sshd.enable
        { boot.initrd.network.ssh = { enable = true; hostKeys = boot.sshd.hostKeys; };}
      )
    ];
}
