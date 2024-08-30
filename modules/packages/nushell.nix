inputs:
{
  options.nixos.packages.nushell = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = {};
  };
  config = let inherit (inputs.config.nixos.packages) nushell; in inputs.lib.mkIf (nushell != null)
  {
    nixos =
    {
      packages.packages._packages = [ inputs.pkgs.nushell ];
      user.sharedModules =
      [{
        config.programs =
        {
          nushell =
          {
            enable = true;
            extraConfig =
            ''
              source ${inputs.topInputs.nu-scripts}/aliases/git/git-aliases.nu
              $env.PATH = ($env.PATH | split row (char esep) | append "~/bin")
            '';
          };
          carapace.enable = true;
          oh-my-posh =
          {
            enable = true;
            enableZshIntegration = false;
            settings = inputs.localLib.deepReplace
              [
                {
                  path = [ "blocks" 0 "segments" (v: v.type or "" == "path") "properties" "style" ];
                  value = "powerlevel";
                }
                {
                  path = [ "blocks" 0 "segments" (v: v.type or "" == "executiontime") "template" ];
                  value = v: builtins.replaceStrings [ "⠀" ] [ " " ] v;
                }
              ]
              (builtins.fromJSON (builtins.readFile
                "${inputs.pkgs.oh-my-posh}/share/oh-my-posh/themes/atomic.omp.json"));
          };
          zoxide.enable = true;
          direnv.enable = true;
        };
      }];
    };
  };
}
