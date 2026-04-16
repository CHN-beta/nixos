{ lib, config, pkgs, flakeInputs, localLib, ... }:
{
  options.nixos.packages.nushell = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) nushell; in lib.mkIf (nushell != null)
  {
    environment.systemPackages = [ pkgs.nushell ];
    nixos.user.sharedModules =
    [{
      config.programs =
      {
        nushell =
        {
          enable = true;
          extraConfig =
          ''
            source ${flakeInputs.nu-scripts}/aliases/git/git-aliases.nu
            $env.PATH = ($env.PATH | split row (char esep) | append "~/bin")
          '';
        };
        carapace.enable = true;
        oh-my-posh =
        {
          enable = true;
          enableZshIntegration = false;
          settings = localLib.deepReplace
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
              "${pkgs.oh-my-posh}/share/oh-my-posh/themes/atomic.omp.json"));
        };
        zoxide.enable = true;
      };
    }];
  };
}
