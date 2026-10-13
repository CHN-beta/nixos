{ lib, config, ... }: {
  options.nixos.services.samba = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          # make shares visible for windows 10 clients
          wsdd = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          private = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          hostsAllowed = lib.mkOption {
            type = lib.types.str;
            default = "127.";
          };
          shares = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  comment = lib.mkOption {
                    type = lib.types.nullOr lib.types.nonEmptyStr;
                    default = null;
                  };
                  path = lib.mkOption { type = lib.types.nonEmptyStr; };
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
      inherit (config.nixos.services) samba;
    in
    lib.mkIf (samba != null) {
      services = {
        samba-wsdd.enable = samba.wsdd;
        samba = {
          enable = true;
          # TCP 139 445 UDP 137 138
          openFirewall = !samba.private;
          settings = {
            global = {
              "smb2 leases" = false;
              "oplocks" = false;
              "level2 oplocks" = false;
              "hosts allow" = "${samba.hostsAllowed}";
            };
          }
          // lib.mapAttrs (n: share: {
            comment = if share.comment != null then share.comment else n;
            path = share.path;
            browseable = true;
            writeable = true;
            "create mask" = "644";
            "force create mode" = "644";
            "directory mask" = "2755";
            "force directory mode" = "2755";
            "acl allow execute always" = true;
          }) samba.shares;
        };
      };
    };
}
