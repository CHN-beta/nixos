{ pkgs }: with pkgs;
{
	vesta = callPackage ./vesta {};
	typora = callPackage ./typora {};
}
