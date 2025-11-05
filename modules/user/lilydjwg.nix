inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "lilydjwg" user.users)
  {
    users.users = inputs.lib.mkIf (inputs.config.nixos.model.hostname == "pc")
    {
      lilydjwg.extraGroups = [ "wheel" ];
      root.openssh.authorizedKeys.keys = [(builtins.readFile ./keys/lilydjwg)];
    };
  };
}
