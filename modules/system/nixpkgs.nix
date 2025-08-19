inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    cuda = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        capabilities = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
        forwardCompat = mkOption { type = types.nullOr types.bool; default = false; };
      };});
      default = null;
    };
    rocm = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.system) nixpkgs; in
  {
    nixpkgs = inputs.localLib.buildNixpkgsConfig
    {
      inherit inputs;
      nixpkgs = nixpkgs // { nixos = true; inherit (inputs.config.nixos.model) arch; };
    };
    boot.kernelPatches = inputs.lib.mkIf (nixpkgs.march != null)
    [{
      name = "native kernel";
      patch = null;
      extraStructuredConfig =
        let kernelConfig = { znver2 = "MZEN2"; znver3 = "MZEN3"; znver4 = "MZEN4"; };
        in
        {
          GENERIC_CPU = inputs.lib.kernel.no;
          ${kernelConfig.${nixpkgs.march} or "M${inputs.lib.toUpper nixpkgs.march}"} = inputs.lib.kernel.yes;
        };
    }];
  };
}
