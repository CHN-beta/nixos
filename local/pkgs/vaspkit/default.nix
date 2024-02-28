{ stdenv, fetchurl, requireFile, autoPatchelfHook, makeWrapper, python3, attrsToList, gnused }:
let
  potcar = requireFile
  {
    name = "POTCAR";
    sha256 = "01adpp9amf27dd39m8svip3n6ax822vsyhdi6jn5agj13lis0ln3";
    hashMode = "recursive";
    message = "POTCAR not found.";
  };
  unwrapped = stdenv.mkDerivation rec
  {
    pname = "vaspkit-unwrapped";
    version = "1.5.1";
    buildInputs = [ autoPatchelfHook stdenv.cc.cc ];
    src = fetchurl
    {
      url = "mirror://sourceforge/vaspkit/Binaries/vaspkit.${version}.linux.x64.tar.gz";
      sha256 = "1cbj1mv7vx18icwlk9d2vfavsfd653943xg2ywzd8b7pb43xrfs1";
    };
    installPhase =
    ''
      runHook preInstall
      mkdir -p $out
      cp -r * $out
      runHook postInstall
    '';
  };
  python = python3.withPackages (pythonPackages: with pythonPackages; [ numpy scipy matplotlib ]);
  envirmentVariables =
  {
    LDA_PATH = "${potcar}/PAW_LDA";
    PBE_PATH = "${potcar}/PAW_PBE";
    GGA_PATH = "${potcar}/PAW_PW91";
    VASPKIT_UTILITIES_PATH = "${unwrapped}/utilities";
    PYTHON_BIN = "${python}/bin/python";
    AUTO_PLOT = ".TRUE.";
  };
in
  stdenv.mkDerivation rec
  {
    pname = "vaspkit";
    inherit (unwrapped) version;
    phases = [ "installPhase" ];
    buildInputs = [ makeWrapper ];
    nativeBuildInputs = [ gnused ];
    replaceEnv = builtins.concatStringsSep "" (map
      (variable: ''sed 's|\(${variable.name}\s*=\s*\)\(\S\+\)|\1${variable.value}|g' -i $out/.vaspkit'' + "\n")
      (attrsToList envirmentVariables));
    installPhase =
    ''
      runHook preInstall

      # setup ~/.vaspkit
      mkdir -p $out
      cp ${unwrapped}/how_to_set_environment_variables $out/.vaspkit

      # setup wrapper
      makeWrapper ${unwrapped}/bin/vaspkit $out/bin/vaspkit --set HOME $out;
    ''
    + replaceEnv
    + ''
      runHook postInstall
    '';
  }
