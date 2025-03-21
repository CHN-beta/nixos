{ src, runCommand, coreutils, gawk }: runCommand "lumericalLicenseManager"
{
  nativeBuildInputs = [ coreutils gawk ];
}
''
  mkdir -p $out
  sh ${src}/INSTALL -silent -nochecks -install_dir $out -no-random-temp-subdir -usetempdir $out/tmp -lm
''
