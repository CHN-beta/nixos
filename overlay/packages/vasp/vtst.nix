{ src, stdenv, autoPatchelfHook, perl, writeScriptBin }:
let vtst = stdenv.mkDerivation
{
  name = "vtst";
  inherit src;
  buildInputs = [ autoPatchelfHook perl ];
  installPhase =
  ''
    mkdir -p $out/lib/vtst
    cp -r * $out/lib/vtst
    patchShebangs $out/lib/vtst
  '';
};
in writeScriptBin "vtst"
''
  export PERL5LIB=${vtst}/lib/vtst''${PERL5LIB:+:$PERL5LIB}
  export PATH=${vtst}/lib/vtst''${PATH:+:$PATH}
  exec "$@"
''
