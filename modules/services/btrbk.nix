inputs:
{
  options.nixos.services.btrbk = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.listOf types.nonEmptyStr; default = []; };
  config = let inherit (inputs.config.nixos.services) btrbk; in inputs.lib.mkMerge
  [
    {
      services.btrbk.sshAccess =
      [{
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6VCXHvPZO7tB0Xo2VNEXkaijWCDxVIpfSuz8OrcUfU btrbk";
        roles = [ "source" "info" ];
      }];
    }
    (inputs.lib.mkIf (btrbk != [])
    {
      services.btrbk =
      {
        ioSchedulingClass = "idle";
        instances.btrbk =
        {
          onCalendar = "*-*-* 4:00:00";
          settings =
          {
            timestamp_format = "short";
            snapshot_dir = "/nix/btrbk/snapshot";
            snapshot_preserve_min = "1w";
            target_preserve_min = "1m";
            ssh_user = "btrbk";
            ssh_identity = inputs.config.sops.secrets.btrbk.path;
            volume = builtins.listToAttrs (builtins.map
              (host:
              {
                name = "ssh://wg1.${host}.chn.moe/nix";
                value = { subvolume.persistent= {}; target = "/nix/btrbk/${host}"; };
              })
              btrbk);
          };
        };
      };
      sops.secrets.btrbk.owner = "btrbk";
    })
  ];
}
