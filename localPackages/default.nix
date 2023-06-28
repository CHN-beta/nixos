{ pkgs }: with pkgs;
{
	typora = callPackage ./typora {};
	upho = python3Packages.callPackage ./upho {};
	vesta = callPackage ./vesta {};
}
