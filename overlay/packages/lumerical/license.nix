{ runCommand, src, macAddress ? "000123456789" }: runCommand "license.txt" {}
''
  cp ${src} $out
  sed -i 's|xxxxxxxxxxxxx|${macAddress}|' $out
  sed -i 's|2022.1231|2035.1231|g' $out
''
