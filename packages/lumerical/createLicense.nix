{ writeShellScriptBin, src, iproute2, gawk, gnused, coreutils }:
let
  ip = "${iproute2}/bin/ip";
  awk = "${gawk}/bin/awk";
  sed = "${gnused}/bin/sed";
  chmod = "${coreutils}/bin/chmod";
in writeShellScriptBin "createLicense"
''
  echo 'Searching for ens* interface...'
  iface=$(${ip} -o link show | ${awk} -F': ' '/^[0-9]+: ens/ {print $2; exit}')
  if [ -n "$iface" ]; then
    echo "Found interface: $iface"
    echo 'Extracting MAC address...'
    mac=$(${ip} link show "$iface" | ${awk} '/link\/ether/ {print $2}' | ${sed} 's/://g')
    echo "Extracted MAC address: $mac"
  else
    echo "No interface starting with 'ens' found." >&2
    exit 1
  fi

  echo 'Creating license file at /tmp/lumerical/license.txt...'
  mkdir -p /tmp/lumerical
  cp ${src} /tmp/lumerical/license.txt
  ${chmod} +w /tmp/lumerical/license.txt
  ${sed} -i "s|xxxxxxxxxxxxx|$mac|" /tmp/lumerical/license.txt
  ${sed} -i 's|2022.1231|2035.1231|g' /tmp/lumerical/license.txt
''
