inputs: {
  options.nixos.system.nixpkgs =
    let
      inherit (inputs.lib) mkOption types;
    in
    {
      march = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
      };
      cuda = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              enableForAllPackages = mkOption {
                type = types.bool;
                default = true;
              };
              capabilities = mkOption {
                type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr);
                default = null;
              };
              forwardCompat = mkOption {
                type = types.nullOr types.bool;
                default = false;
              };
            };
          }
        );
        default = null;
      };
      rocm = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              enableForAllPackages = mkOption {
                type = types.bool;
                default = true;
              };
              targets = mkOption {
                type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr);
                default = null;
              };
            };
          }
        );
        default = null;
      };
    };
  config =
    let
      inherit (inputs.config.nixos.system) nixpkgs;
    in
    {
      nixpkgs = inputs.self.lib.buildNixpkgsConfig (
        nixpkgs
        // {
          nixos = true;
          inherit (inputs.config.nixos.model) arch;
        }
      );
    };
}
