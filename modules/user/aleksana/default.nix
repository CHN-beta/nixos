inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "aleksana" user.users)
    { users.users.aleksana.extraGroups = inputs.lib.mkIf (inputs.config.nixos.model.hostname == "srv3") [ "wheel" ]; };
}
