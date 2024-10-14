{
  stdenv, src,
  tcl,
  procps, bc, lua, pkg-config
}:
stdenv.mkDerivation
{
  name = "lmod";
  inherit src;
  buildInputs = [ tcl ];
  nativeBuildInputs = [ pkg-config procps bc (lua.withPackages (ps: with ps; [ luaposix ])) ];
  configurePhase = ''./configure --prefix=$out/share'';
  postUnpack = "patchShebangs .";
}
