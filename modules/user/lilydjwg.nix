inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "lilydjwg" user.users)
  {
    users.users = inputs.lib.mkMerge
    [
      {
        lilydjwg.openssh.authorizedKeys.keys =
          [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0P/hglDmmb77qkTpAEwxx6KH+3MI9sn/nb4fNafI8V root@wikis" ];
      }
      (inputs.lib.mkIf (inputs.config.nixos.model.hostname == "pc")
      {
        lilydjwg.extraGroups = [ "wheel" ];
        root.openssh.authorizedKeys.keys = [(builtins.readFile ./keys/lilydjwg)];
      })
    ];
  };
}
