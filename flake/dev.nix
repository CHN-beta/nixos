{ inputs }: let inherit (inputs.self.nixosConfigurations.pc) pkgs; in
{
  biu = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
  {
    inputsFrom = [ pkgs.localPackages.biu ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  hpcstat = pkgs.mkShell.override { stdenv = pkgs.gcc14Stdenv; }
  {
    inputsFrom = [ (pkgs.localPackages.hpcstat.override { version = null; }) ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  sbatch-tui = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
  {
    inputsFrom = [ pkgs.localPackages.sbatch-tui ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  ufo = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
  {
    inputsFrom = [ pkgs.localPackages.ufo ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  chn-bsub = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.chn-bsub ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
  };
  winjob =
    let inherit (pkgs) clang-tools_18; in let inherit (inputs.self.packages.x86_64-w64-mingw32) pkgs winjob;
    in pkgs.mkShell.override { stdenv = pkgs.gcc14Stdenv; }
    {
      inputsFrom = [ winjob ];
      packages = [ clang-tools_18 ];
      CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    };
  mirism = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
  {
    inputsFrom = [ pkgs.localPackages.mirism ];
    packages = [ pkgs.clang-tools_18 ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
  };
}
