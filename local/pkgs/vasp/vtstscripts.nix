{ fetchzip, stdenv, autoPatchelfHook, perl, writeScriptBin }:
  let vtstscript-unwrapped = stdenv.mkDerivation
  {
    name = "vtstscript-unwrapped";
    src = fetchzip
    {
      url = "http://theory.cm.utexas.edu/code/vtstscripts.tgz";
      sha256 = "04476wgxvja15jijh9dxbzwy4mdrdqnd93s66jsm26rf73caj7lr";
    };
    buildInputs = [ autoPatchelfHook perl ];
    installPhase =
    ''
      mkdir -p $out/lib/vtstscripts
      cp -r * $out/lib/vtstscripts
      patchShebangs $out/lib/vtstscripts
    '';
  };
  in writeScriptBin "vtstscripts"
  ''
    # add vtstscript-unwrapped in PERL5LIB
    export PERL5LIB=${vtstscript-unwrapped}/lib/vtstscripts''${PERL5LIB:+:$PERL5LIB}
    export PATH=${vtstscript-unwrapped}/lib/vtstscripts''${PATH:+:$PATH}
    exec "$@"
  ''
