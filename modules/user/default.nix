inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.user = let inherit (inputs.lib) mkOption types; in
  {
    users = mkOption { type = types.listOf types.nonEmptyStr; default = [ "chn" ]; };
    sharedModules = mkOption { type = types.listOf types.anything; default = []; };
    uid = mkOption
    {
      type = types.attrsOf types.ints.unsigned;
      readOnly = true;
      default =
      {
        chn = 1000;
        xll = 1001;
        yjq = 1002;
        yxy = 1003;
        zem = 1004;
        gb = 1005;
        test = 1006;
        wp = 1007;
        hjp = 1008;
        zzn = 1009;
        wm = 1010;
        GROUPIII-1 = 1011;
        GROUPIII-2 = 1012;
        GROUPIII-3 = 1013;
        lly = 1014;
        yxf = 1015;
        hss = 1016;
        aleksana = 1017;
        alikia = 1018;
        pen = 1019;
        reonokiy = 1020;
        zqq = 1021;
        zgq = 1022;
        qmx = 1023;
        yumieko = 1024;
        xly = 1025;
        ccy = 1026;
        twr = 1027;
        lsp = 1028;
        lilydjwg = 1029;
        stq = 1030;
        misskey-misskey = 2000;
        misskey-misskey-old = 2001;
        frp = 2002;
        mirism = 2003;
        httpapi = 2004;
        httpua = 2005;
        rsshub = 2006;
        v2ray = 2007;
        fz-new-order = 2008;
        synapse-synapse = 2009;
        synapse-matrix = 2010;
        hpcstat = 2011;
        speedtest = 2012;
        tailscale = 2013;
      };
    };
    gid = mkOption
    {
      type = types.attrsOf types.ints.unsigned;
      readOnly = true;
      default = inputs.config.nixos.user.uid //
      {
        groupshare = 3000;
        telegram = 3001;
      };
    };
  };
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkMerge
  [
    {
      users =
      {
        users = builtins.listToAttrs (builtins.map
          (userName:
          {
            name = userName;
            value =
            {
              uid = user.uid.${userName};
              group = userName;
              isNormalUser = true;
              shell = inputs.pkgs.zsh;
              createHome = true;
              extraGroups = inputs.lib.intersectLists [ "users" "video" "audio" ]
                (builtins.attrNames inputs.config.users.groups);
              # ykman fido credentials list
              # ykman fido credentials delete f2c1ca2d
              # ssh-keygen -t ed25519-sk -O resident
              # ssh-keygen -K
              openssh.authorizedKeys.keys =
                inputs.lib.optionals (builtins.pathExists ./keys/${userName}) [(builtins.readFile ./keys/${userName})];
            };
          })
          user.users);
        groups = builtins.listToAttrs (builtins.map
          (name: { inherit name; value.gid = user.gid.${name}; })
          user.users);
      };
      home-manager.users = builtins.listToAttrs (builtins.map
        (name: { inherit name; value.imports = user.sharedModules; })
        user.users);
    }
    # set hashedPassword if it exist in secrets
    (
      let hashedPasswordExist = userName: inputs.lib.lists.any
        (inputs.lib.lists.hasPrefix [ "users" userName ]) inputs.config.nixos.system.sops.availableKeys;
      in
      {
        users.users = builtins.listToAttrs (builtins.map
          (name: { inherit name; value.hashedPasswordFile = inputs.config.sops.secrets."users/${name}".path; })
          (builtins.filter (user: hashedPasswordExist user) user.users));
        nixos.system.sops.secrets = builtins.listToAttrs (builtins.map
          (name: inputs.lib.nameValuePair "users/${name}" { neededForUsers = true; })
          (builtins.filter (user: hashedPasswordExist user) user.users));
      }
    )
    # setup root
    {
      users.users.root =
      {
        shell = inputs.pkgs.zsh;
        openssh.authorizedKeys.keys = [(builtins.readFile ./keys/chn)];
        hashedPassword = "$y$j9T$.UyKKvDnmlJaYZAh6./rf/$65dRqishAiqxCE6LEMjqruwJPZte7uiyYLVKpzdZNH5";
      };
      home-manager.users.root = homeInputs:
      {
        imports = user.sharedModules;
        config =
        {
          programs.git =
          {
            userName = "chn";
            userEmail = "chn@chn.moe";
            # allow root operate on git repositories owned by others
            extraConfig.safe.directory = "*";
          };
          home.file = inputs.lib.mkIf inputs.config.nixos.model.private
          {
            ".ssh/id_ed25519_sk".source = homeInputs.config.lib.file.mkOutOfStoreSymlink
              inputs.config.nixos.system.sops.secrets."root/ed25519_sk".path;
          };
        };
      };
    }
    # setup test
    (inputs.lib.mkIf (builtins.elem "test" user.users) { users.users.test.password = "test"; })
  ];
}
