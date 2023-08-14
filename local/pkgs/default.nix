{ lib, pkgs }: with pkgs;
{
	typora = callPackage ./typora {};
	upho = python3Packages.callPackage ./upho {};
	spectral = python3Packages.callPackage ./spectral {};
	vesta = callPackage ./vesta {};
	oneapi = callPackage ./oneapi {};
	send = callPackage ./send {};
	misskey = callPackage ./misskey {};
}
