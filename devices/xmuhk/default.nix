{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = null; cuda = null; nixRoot = null; };
  });
  lumericalLicenseManager = 
    let
      ip = "${pkgs.iproute2}/bin/ip";
      awk = "${pkgs.gawk}/bin/awk";
      sed = "${pkgs.gnused}/bin/sed";
      chmod = "${pkgs.coreutils}/bin/chmod";
      sing = "${pkgs.singularity}/bin/singularity";
    in pkgs.writeShellScriptBin "lumericalLicenseManager"
    ''
      echo "Cleaning up..."
      rm -rf /tmp/lumerical
      mkdir -p /tmp/lumerical

      echo 'Searching for en* interface...'
      iface=$(${ip} -o link show | ${awk} -F': ' '/^[0-9]+: en/ {print $2; exit}')
      if [ -n "$iface" ]; then
        echo "Found interface: $iface"
        echo 'Extracting MAC address...'
        mac=$(${ip} link show "$iface" | ${awk} '/link\/ether/ {print $2}' | ${sed} 's/://g')
        echo "Extracted MAC address: $mac"
      else
        echo "No interface starting with 'en' found." >&2
        exit 1
      fi

      echo 'Creating license file...'
      cp ${inputs.self.src.lumerical.licenseManager.sifImageFile} /tmp/lumerical/license.txt
      ${chmod} +w /tmp/lumerical/license.txt
      ${sed} -i "s|xxxxxxxxxxxxx|$mac|" /tmp/lumerical/license.txt
      ${sed} -i 's|2022.1231|2035.1231|g' /tmp/lumerical/license.txt

      echo "Starting license manager..."
      ${sing} run --pwd /home/ansys_inc/shared_files/licensing --writable-tmpfs \
        ${inputs.self.src.lumerical.licenseManager.sifImageFile}
    '';
in pkgs.symlinkJoin
{
  name = "xmuhk";
  paths = (with pkgs; [ hello ]) ++ [ lumericalLicenseManager ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
}
