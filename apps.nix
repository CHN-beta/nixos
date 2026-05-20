self:
let
  inherit (self.packages.x86_64-linux) pkgs lib;
  build = self.nixosConfigurations
    |> builtins.attrNames
    |> builtins.map (name:
      ''
        echo building ${name}
        nix --store /nix/tf build .#nixosConfigurations.${name}.config.system.build.toplevel "$@"
      '')
    |> builtins.concatStringsSep "\n"
    |> pkgs.writeShellScript "build";

  deploy =
    let
      doNotDeploy = [ "pe" ];
      doNotUseTailscale = [ "vps4" "vps6" "vps9" ];
      deployKdl = self.nixosConfigurations
        |> lib.attrNames
        |> lib.subtractLists doNotDeploy
        |> lib.map (host:
          let connect = if lib.elem host doNotUseTailscale then host else "ts.${host}"; in
          ''
            tab name="${host}" {
              pane command="nixos-rebuild" {
                args "switch" "--flake" ".#${host}" "--target-host" "root@${connect}" "--option" "store" "/nix/tf"
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
    in pkgs.writeShellScript "deploy" "zellij --layout ${deployKdl}";
in
  { inherit (self.packages.x86_64-linux) dns-push; inherit build deploy; }
  |> builtins.mapAttrs (_: v: { type = "app"; program = "${v}"; })
