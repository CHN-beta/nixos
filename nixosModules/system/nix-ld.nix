inputs:
{
  options.nixos.system.nix-ld = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default =
      if (inputs.config.nixos.model.arch == "x86_64")
        && (builtins.elem inputs.config.nixos.model.variant [ "desktop" "server" ])
      then {} else null;
  };
  config = let inherit (inputs.config.nixos.system) nix-ld; in inputs.lib.mkIf (nix-ld != null)
  {
    programs.nix-ld =
    {
      enable = true;
      libraries = with inputs.pkgs;
      [
        (runCommand "steamrun-lib" {} "mkdir $out; ln -s ${steam-run.fhsenv}/usr/lib64 $out/lib")
        libice libsm
      ];
    };
  };
}
