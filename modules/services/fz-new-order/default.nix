inputs:
{
  options.nixos.services.fz-new-order = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) fz-new-order;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.lib) mkIf;
      inherit (builtins) map listToAttrs toString concatLists;
    in mkIf fz-new-order.enable
    {
      users =
      {
        users.fz-new-order =
        {
          uid = inputs.config.nixos.system.user.user.fz-new-order;
          group = "fz-new-order";
          home = "/var/lib/fz-new-order";
          createHome = true;
          isSystemUser = true;
        };
        groups.fz-new-order.gid = inputs.config.nixos.system.user.group.fz-new-order;
      };
      systemd =
      {
        timers.fz-new-order =
        {
          wantedBy = [ "timers.target" ];
          timerConfig =
          {
            OnBootSec = "10m";
            OnUnitActiveSec = "10m";
            Unit = "fz-new-order.service";
          };
        };
        services.fz-new-order = rec
        {
          description = "fz-new-order";
          after = [ "network.target" ];
          requires = after;
          serviceConfig =
          {
            User = inputs.config.users.users."fz-new-order".name;
            Group = inputs.config.users.users."fz-new-order".group;
            WorkingDirectory = "/var/lib/fz-new-order";
            ExecStart =
              let
                src = inputs.pkgs.substituteAll
                {
                  src = ./main.cpp;
                  config_file = inputs.config.sops.templates."fz-new-order/config.json".path;
                };
                binary = inputs.pkgs.stdenv.mkDerivation
                {
                  name = "fz-new-order";
                  inherit src;
                  buildInputs = with inputs.pkgs; [ jsoncpp.dev cereal fmt httplib ];
                  dontUnpack = true;
                  buildPhase =
                  ''
                    runHook preBuild
                    g++ -std=c++20 -O2 -o fz-new-order ${src} -ljsoncpp -lfmt
                    runHook postBuild
                  '';
                  installPhase =
                  ''
                    runHook preInstall
                    mkdir -p $out/bin
                    cp fz-new-order $out/bin/fz-new-order
                    runHook postInstall
                  '';
                };
              in "${binary}/bin/fz-new-order";
          };
        };
        tmpfiles.rules =
          let perm = "/var/lib/fz-new-order 0700 fz-new-order fz-new-order"; in [ "d ${perm}" "Z ${perm}" ];
      };
      sops = let userNum = 6; configNum = 2; in
      {
        templates."fz-new-order/config.json" =
        {
          owner = inputs.config.users.users."fz-new-order".name;
          group = inputs.config.users.users."fz-new-order".group;
          content = let placeholder = inputs.config.sops.placeholder; in builtins.toJSON
          {
            manager = placeholder."fz-new-order/manager";
            token = placeholder."fz-new-order/token";
            uids = map (j: placeholder."fz-new-order/uids/user${toString j}") (builtins.genList (n: n) userNum);
            config = map
              (i: listToAttrs (map
                (attrName: { name = attrName; value = placeholder."fz-new-order/config${toString i}/${attrName}"; })
                [ "username" "password" "comment" ]))
              (builtins.genList (n: n) configNum);
          };
        };
        secrets =
          { "fz-new-order/manager" = {}; "fz-new-order/token" = {}; }
          // (listToAttrs (map
            (i: { name = "fz-new-order/uids/user${toString i}"; value = {}; })
            (builtins.genList (n: n) userNum)))
          // (listToAttrs (concatLists (map
            (i: map
              (attrName: { name = "fz-new-order/config${toString i}/${attrName}"; value = {}; })
              [ "username" "password" "comment" ])
            (builtins.genList (n: n) configNum))));
      };
    };
}
