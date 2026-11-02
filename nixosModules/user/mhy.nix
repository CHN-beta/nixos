{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "mhy" config.nixos.user.users) {
    users.users.mhy.extraGroups = [
      "straycat"
    ];
  };
}
