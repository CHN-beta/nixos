self:
let
  inherit (self.nixosConfigurations.pc) pkgs;
in
{
  biu = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.biu ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  hpcstat = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.hpcstat ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  sbatch-tui = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.sbatch-tui ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  ufo = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.ufo ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  chn-bsub = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.chn-bsub ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
  };
  info = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.info ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  vm = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.vm ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
  xinli = pkgs.mkShell {
    inputsFrom = [ pkgs.localPkgs.xinli ];
    packages = [ pkgs.llvmPackages.clang-tools ];
    CMAKE_EXPORT_COMPILE_COMMANDS = "1";
    hardeningDisable = [ "all" ];
  };
}
