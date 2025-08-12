inputs:
{
  options.nixos.system.nix-ld = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.arch == "x86_64" then {} else null;
  };
  config = let inherit (inputs.config.nixos.system) nix-ld; in inputs.lib.mkIf (nix-ld != null)
  {
    programs.nix-ld =
    {
      enable = true;
      libraries = [(inputs.pkgs.runCommand "steamrun-lib" {}
        "mkdir $out; ln -s ${inputs.pkgs.steam-run.fhsenv}/usr/lib64 $out/lib")];
    };
  };
}
