{ inputs }:
let
  inherit (inputs.self.packages.x86_64-linux) dns-push pkgs lib;
  build = inputs.self.nixosConfigurations
    |> builtins.attrNames
    |> builtins.map (name:
      ''
        echo building ${name}
        nix --store /nix/tf build .#nixosConfigurations.${name}.config.system.build.toplevel
      '')
    |> builtins.concatStringsSep "\n"
    |> pkgs.writeShellScript "build";
  deployKdl = inputs.self.nixosConfigurations
    |> builtins.attrNames
    |> lib.subtractLists [ "pe" ]
    |> builtins.map (host:
      ''
        tab name="${host}" {
          pane command="nixos-rebuild" {
            args "switch" "--flake" ".#${host}" "--target-host" "root@ts.${host}" "--option" "store" "/nix/tf"
          }
        }
      '')
    |> (hosts: pkgs.writeText "deploy.kdl"
      ''
        layout {
          default_tab_template {
            pane size=1 borderless=true {
              plugin location="zellij:tab-bar"
            }
            children
            pane size=2 borderless=true {
              plugin location="zellij:status-bar"
            }
          }
          ${lib.concatStringsSep "\n" hosts}
        }
      '');
    deploy = pkgs.writeShellScript "deploy" "zellij --layout ${deployKdl}";
in
  { inherit dns-push build deploy; }
  |> builtins.mapAttrs (_: v: { type = "app"; program = "${v}"; })
