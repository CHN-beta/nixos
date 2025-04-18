inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "aleksana" user.users)
  {
    users.users.aleksana.extraGroups = inputs.lib.intersectLists
      [ "wheel" "wireshark" "libvirtd" ] (builtins.attrNames inputs.config.users.groups);
  };
}
