inputs:
{
  config =
  {
    programs.java = { enable = true; binfmt = true; };
    boot.binfmt.emulatedSystems = [ "aarch64-linux" "x86_64-windows" ];
  };
}
