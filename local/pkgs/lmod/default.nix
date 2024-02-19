{
  stdenv, src,
  tcl,
  procps, bc, lua
}:
stdenv.mkDerivation
{
  name = "lmod";
  inherit src;
  buildInputs = [ tcl ];
  nativeBuildInputs = [ procps bc (lua.withPackages (ps: with ps; [ luaposix ])) ];
  postUnpack = "patchShebangs .";
}
