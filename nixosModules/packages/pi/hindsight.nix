# Import with { inherit pkgs; }; this is a helper, not a NixOS module.
{ pkgs }:
let
  version = "0.6.1";
  package = pkgs.stdenvNoCC.mkDerivation {
    pname = "hindsight-coding-agents-pi";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@vectorize-io/hindsight-coding-agents/-/hindsight-coding-agents-${version}.tgz";
      hash = "sha512-7CdHjyRsvkWqK6k2aa4QifGh3iJfdYL7o2jW+JzgKltI/QKka0XI1YJt3zX6e0b+HXO5ll2/c3+3DVhD8N6BSA==";
    };
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist skill package.json README.md "$out/"
      runHook postInstall
    '';
  };
  config = builtins.fromJSON (builtins.readFile ./hindsight.json);
in
{
  inherit package config;
  # Keep package.json and the bundle's relative assets together; no npm install.
  extension = "${package}/dist/pi.js";
  skill = "${package}/skill";
  settings = {
    extensions = [ "${package}/dist/pi.js" ];
    skills = [ "${package}/skill" ];
  };
  # Credentials and API URL are deliberately absent: inherited runtime env only.
  configFile = pkgs.writeText "pi-hindsight.json" (builtins.toJSON config);
}
