{ lib, llvmPackages }:

llvmPackages.stdenv.mkDerivation
{
	pname = "clang-hello";
	version = "0";

	phases = [ "installPhase" ];

  installPhase =
	''
		clang --version > $out
	'';
}
