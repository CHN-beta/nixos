{ lib, config, ... }:
{
  config = lib.mkIf (builtins.elem "straycat" config.nixos.user.users) {
    users.users.straycat = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./keys/chn)
        (builtins.readFile ./keys/straycat)
      ];
      hashedPassword = "$y$j9T$1nnqD525KXm/G3xc.bqXD1$jR5ZVT1XsF2Qp0wVy4vc2QiHTkUhqgAkALPaPTrLML7";
    };
    nixos.system.sops.secrets = lib.mkMerge [
      (
        [
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
        )
      )
      {
        "straycat/github".key = "github/token";
        "straycat/ssh" = {
          owner = "straycat";
          group = "straycat";
          mode = "0400";
        };
      }
    ];
    home-manager.users.straycat = homeInputs: {
      config.home.file = {
        ".ssh/id_ed25519".source =
          homeInputs.config.lib.file.mkOutOfStoreSymlink
            config.nixos.system.sops.secrets."straycat/ssh".path;
        ".ssh/id_ed25519.pub".source = ./keys/straycat;
      };
    };
  };
}
