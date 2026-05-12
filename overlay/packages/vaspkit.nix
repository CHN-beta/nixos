{ stdenv, src, autoPatchelfHook, makeWrapper, python3, lib, gnused }:
let
  unwrapped = stdenv.mkDerivation
  {
    pname = "vaspkit-unwrapped";
    inherit (src) version;
    src = src.vaspkit;
    buildInputs = [ autoPatchelfHook stdenv.cc.cc ];
    installPhase =
    ''
      runHook preInstall
      mkdir -p $out
      cp -r * $out
      runHook postInstall
    '';
  };
  python = python3.withPackages (pythonPackages: with pythonPackages; [ numpy scipy matplotlib ]);
  envirmentVariables = let inherit (src) potcar; in
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
      (lib.attrsToList envirmentVariables));
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
