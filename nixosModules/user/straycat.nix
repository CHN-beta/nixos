{ lib, config, ... }:
{
  config = lib.mkIf (builtins.elem "straycat" config.nixos.user.users) {
    users.users.straycat.openssh.authorizedKeys.keys = [ (builtins.readFile ./keys/chn) ];
    nixos.system.sops.secrets = lib.mkMerge
    [
      ([
        "mineru"
        "cliproxyapi"
        "deepseek"
        "qdrant"
        "github"
        "hindsight"
        "siliconflow"
        "openrouter"
        "vikunja"
      ]
      |> lib.flip lib.genAttrs' (
        s:
        lib.nameValuePair "straycat/${s}" {
          group = "straycat";
          mode = "0440";
        }
      ))
      {
        "straycat/github".key = "github/token";
      }
    ];
  };
}
