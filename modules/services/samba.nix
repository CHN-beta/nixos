inputs:
{
  options.nixos.services.samba = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    wsdd = mkOption { type = types.bool; default = false; };
    private = mkOption { type = types.bool; default = false; };
    hostsAllowed = mkOption { type = types.str; default = "127."; };
    shares = mkOption
    {
      type = types.attrsOf (types.submodule { options =
      {
        comment = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        path = mkOption { type = types.nonEmptyStr; };
      };});
      default = {};
    };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) samba;
      inherit (builtins) map listToAttrs;
    in mkIf samba.enable
    {
      services =
      {
        # make shares visible for windows 10 clients
        samba-wsdd.enable = samba.wsdd;
        samba =
        {
          enable = true;
          # TCP 139 445 UDP 137 138
          openFirewall = !samba.private;
          securityType = "user";
          extraConfig =
          ''
            workgroup = WORKGROUP
            server string = Samba Server
            server role = standalone server
            hosts allow = ${samba.hostsAllowed}
            dns proxy = no
          '';
          #  obey pam restrictions = yes
          #  encrypt passwords = no
          shares = listToAttrs (map
            (share:
            {
              name = share.name;
              value =
              {
                comment = if share.value.comment != null then share.value.comment else share.name;
                path = share.value.path;
                browseable = true;
                writeable = true;
                "create mask" = "644";
                "force create mode" = "644";
                "directory mask" = "2755";
                "force directory mode" = "2755";
              };
            })
            (attrsToList samba.shares));
        };
      };
    };
}
