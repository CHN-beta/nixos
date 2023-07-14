{ pkgs }: with pkgs;
{
	typora = callPackage ./typora {};
	upho = python3Packages.callPackage ./upho {};
	spectral = python3Packages.callPackage ./spectral {};
	vesta = callPackage ./vesta {};
	clang-hello = callPackage ./clang-hello {};
}
