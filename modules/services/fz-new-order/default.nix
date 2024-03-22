inputs:
{
  options.nixos.services.fz-new-order = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) fz-new-order; in inputs.lib.mkIf (fz-new-order != null)
  {
    users =
    {
      users.fz-new-order =
      {
        uid = inputs.config.nixos.user.uid.fz-new-order;
        group = "fz-new-order";
        home = "/var/lib/fz-new-order";
        createHome = true;
        isSystemUser = true;
      };
      groups.fz-new-order.gid = inputs.config.nixos.user.gid.fz-new-order;
    };
    systemd =
    {
      timers.fz-new-order =
      {
        wantedBy = [ "timers.target" ];
        timerConfig = { OnBootSec = "10m"; OnUnitActiveSec = "10m"; Unit = "fz-new-order.service"; };
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
      [
        "d /var/lib/fz-new-order 0700 fz-new-order fz-new-order"
        "Z /var/lib/fz-new-order - fz-new-order fz-new-order"
      ];
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
          uids = builtins.map (j: placeholder."fz-new-order/uids/user${builtins.toString j}")
            (builtins.genList (n: n) userNum);
          config = builtins.map
            (i: builtins.listToAttrs (builtins.map
              (attrName: { name = attrName; value = placeholder."fz-new-order/config${toString i}/${attrName}"; })
              [ "username" "password" "comment" ]))
            (builtins.genList (n: n) configNum);
        };
      };
      secrets =
        { "fz-new-order/manager" = {}; "fz-new-order/token" = {}; }
        // (builtins.listToAttrs (builtins.map
          (i: { name = "fz-new-order/uids/user${toString i}"; value = {}; })
          (builtins.genList (n: n) userNum)))
        // (builtins.listToAttrs (builtins.concatLists (builtins.map
          (i: builtins.map
            (attrName: { name = "fz-new-order/config${builtins.toString i}/${attrName}"; value = {}; })
            [ "username" "password" "comment" ])
          (builtins.genList (n: n) configNum))));
    };
  };
}
