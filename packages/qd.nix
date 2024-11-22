{ src, stdenv, autoPatchelfHook }:
let unwrapped = stdenv.mkDerivation
{
  pname = "qd";
  inherit (src) src version;
  langFortran = true;
  buildInputs = [ stdenv.cc.cc.lib libz ];
  nativeBuildInputs = [ autoPatchelfHook ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r install_components/Linux_x86_64/${src.version}/compilers/{bin,include,lib} $out
  '';
};
in unwrapped
