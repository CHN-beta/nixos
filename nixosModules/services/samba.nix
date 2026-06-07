inputs: {
  options.nixos.services.samba =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            # make shares visible for windows 10 clients
            wsdd = mkOption {
              type = types.bool;
              default = false;
            };
            private = mkOption {
              type = types.bool;
              default = false;
            };
            hostsAllowed = mkOption {
              type = types.str;
              default = "127.";
            };
            shares = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    comment = mkOption {
                      type = types.nullOr types.nonEmptyStr;
                      default = null;
                    };
                    path = mkOption { type = types.nonEmptyStr; };
                  };
                }
              );
              default = { };
            };
          };
        }
      );
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) samba;
    in
    inputs.lib.mkIf (samba != null) {
      services = {
        samba-wsdd.enable = samba.wsdd;
        samba = {
          enable = true;
          # TCP 139 445 UDP 137 138
          openFirewall = !samba.private;
          settings = {
            global."hosts allow" = "${samba.hostsAllowed}";
          }
          // builtins.listToAttrs (
            builtins.map (share: {
              name = share.name;
              value = {
                comment = if share.value.comment != null then share.value.comment else share.name;
                path = share.value.path;
                browseable = true;
                writeable = true;
                "create mask" = "644";
                "force create mode" = "644";
                "directory mask" = "2755";
                "force directory mode" = "2755";
                "acl allow execute always" = true;
              };
            }) (inputs.lib.attrsToList samba.shares)
          );
        };
      };
    };
}
