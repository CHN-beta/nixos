{ src, runCommand }: runCommand "lumericalLicenseManager" {}
''
  mkdir -p $out
  ./${src}/INSTALL -silent -install_dir $out
''
