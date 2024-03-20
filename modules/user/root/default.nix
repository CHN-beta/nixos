inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in
    {
      users.users.root.hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
      home-manager.users.root =
      {
        config.programs.git =
          { extraConfig.core.editor = inputs.lib.mkForce "vim"; userName = "chn"; userEmail = "chn@chn.moe"; };
      };
    };
}
