{
  stdenvNoCC, fetchurl, buildFHSEnv,
  ncurses
}:
let
  versions =
  {
    "2022.2" =
    {
      basekit =
      {
        id = "18673";
        version = "2022.2.0.262";
        sha256 = "03qx6sb58mkhc7iyc8va4y1ihj6l3155dxwmqj8dfw7j2ma7r5f6";
        components =
        [
          "intel.oneapi.lin.dpcpp-ct"
          "intel.oneapi.lin.dpcpp_dbg"
          "intel.oneapi.lin.dpl"
          "intel.oneapi.lin.tbb.devel"
          "intel.oneapi.lin.ccl.devel"
          "intel.oneapi.lin.dpcpp-cpp-compiler"
          "intel.oneapi.lin.dpl"
          "intel.oneapi.lin.mkl.devel"
        ];
      };
      hpckit =
      {
        id = "18679";
        version = "2022.2.0.191";
        sha256 = "0swz4w9bn58wwqjkqhjqnkcs8k8ms9nn9s8k7j5w6rzvsa6817d2";
      };
    };
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
    targetPkgs = pkgs: with pkgs; [ coreutils zlib ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
    runScript = "sh";
  };
  componentString = components: if components == null then "--components default" else
    " --components " + (builtins.concatStringsSep ":" components);
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
    ${builder}/bin/builder ${basekit} -a --silent --eula accept --install-dir $out/share/intel \
      ${componentString versions.${version}.basekit.components or null}
    ${builder}/bin/builder ${hpckit} -a --silent --eula accept --install-dir $out/share/intel \
      ${componentString versions.${version}.hpckit.components or null}
    ${builder}/bin/builder $out/share/intel/modulefiles-setup.sh --output-dir=$out/share/intel/modulefiles \
      --ignore-latest
  '';
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
};
in builtins.mapAttrs (version: _: buildOneapi version) versions
