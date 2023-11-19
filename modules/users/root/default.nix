inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "root" users.users)
    {
      users.users.root =
      {
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
        hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
        openssh.authorizedKeys.keys =
        [
          (builtins.concatStringsSep ""
          [
            "sk-ssh-ed25519@openssh.com "
            "AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEU/JPpLxsk8UWXiZr8CPNG+4WKFB92o1Ep9OEstmPLzAAAABHNzaDo= "
            "chn@pc"
          ])
        ];
      };
      home-manager.users.root =
      {
        imports = users.sharedModules;
        config.programs.git =
          { extraConfig.core.editor = inputs.lib.mkForce "vim"; userName = "chn"; userEmail = "chn@chn.moe"; };
      };
    };
}
