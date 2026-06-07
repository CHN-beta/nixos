inputs: {
  options.nixos.system.uboot =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule (submoduleInputs: {
          options = {
            buildArgs = mkOption { type = types.attrsOf types.anything; };
            package = mkOption {
              type = types.package;
              readOnly = true;
              default = inputs.pkgs.buildUBoot submoduleInputs.config.buildArgs;
            };
          };
        })
      );
      default =
        {
          x86_64 = null;
          aarch64 = { };
        }
        .${inputs.config.nixos.model.arch};
    };
  config =
    let
      inherit (inputs.config.nixos.system) uboot;
    in
    inputs.lib.mkIf (uboot != null) { boot.loader.generic-extlinux-compatible.enable = true; };
}
