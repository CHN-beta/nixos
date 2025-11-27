inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.type == "desktop")
  {
    environment.persistence."/nix/rootfs/current".users.chn.directories = [ ".config/autostart" ];
  };
}
