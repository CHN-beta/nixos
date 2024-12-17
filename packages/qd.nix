{ src, stdenv }: stdenv.mkDerivation
{
  name = "qd";
  inherit src;
}
