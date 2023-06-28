{ pkgs }: with pkgs;
{
	mathtools = callPackage ./mathtools {};
	vesta = callPackage ./vesta {};
	typora = callPackage ./typora {};
	upho = callPackage ./upho {};
}
