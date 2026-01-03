{ inputs }: let inherit (inputs.self.nixosConfigurations.pc) pkgs; in
{
  biu = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.biu ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  hpcstat = pkgs.mkShell
  {
    inputsFrom = [ (pkgs.localPackages.hpcstat.override { version = null; }) ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  sbatch-tui = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.sbatch-tui ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  ufo = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.ufo ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  chn-bsub = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.chn-bsub ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
  };
  info = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.info ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  vm = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.vm ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  xinli = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.xinli ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  missgram = pkgs.mkShell
  {
    inputsFrom = [ pkgs.localPackages.missgram ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
}
