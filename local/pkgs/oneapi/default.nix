{
  stdenvNoCC, fetchurl, buildFHSEnv,
  ncurses
}:
let
  versions =
  {
    "2024.0" =
    {
      basekit =
      {
        id = "163da6e4-56eb-4948-aba3-debcec61c064";
        version = "2024.0.1.46";
        sha256 = "1sp1fgjv8xj8qxf8nv4lr1x5cxz7xl5wv4ixmfmcg0gyk28cjq1g";
      };
      hpckit =
      {
        id = "67c08c98-f311-4068-8b85-15d79c4f277a";
        version = "2024.0.1.38";
        sha256 = "06vpdz51w2v4ncgk8k6y2srlfbbdqdmb4v4bdwb67zsg9lmf8fp9";
      };
    };
  };
  builder = buildFHSEnv
  {
    name = "builder";
    targetPkgs = pkgs: with pkgs; [ coreutils ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
    runScript = "sh";
  };
in let buildOneapi = version: stdenvNoCC.mkDerivation rec
{
  pname = "oneapi";
  inherit version;
  basekit = fetchurl
  {
    url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/${versions.${version}.basekit.id}/"
      + "l_BaseKit_p_${versions.${version}.basekit.version}_offline.sh";
    sha256 = versions.${version}.basekit.sha256;
  };
  hpckit = fetchurl
  {
    url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/${versions.${version}.hpckit.id}/"
      + "l_HPCKit_p_${versions.${version}.hpckit.version}_offline.sh";
    sha256 = versions.${version}.hpckit.sha256;
  };
  phases = [ "installPhase" ];
  nativeBuildInputs = [ ncurses ];
  installPhase =
  ''
    mkdir -p $out
    ${builder}/bin/builder ${basekit} -a --silent --eula accept --install-dir $out/share/intel
    ${builder}/bin/builder ${hpckit} -a --silent --eula accept --install-dir $out/share/intel
    ${builder}/bin/builder $out/share/intel/modulefiles-setup.sh --output-dir=$out/share/intel/modulefiles
  '';
};
in builtins.mapAttrs (version: _: buildOneapi version) versions
