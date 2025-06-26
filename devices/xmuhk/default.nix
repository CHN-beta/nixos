# sudo nix build --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' .#xmuhk
# sudo nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' -qR ./result | grep -Fxv -f <(ssh xmuhk find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' --export | xz -T0 | pv > xmuhk.nar.xz
# cat data.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = null; cuda = null; nixRoot = "/public/home/xmuhk/.nix"; };
  });
  lumericalLicenseManager = 
    let
      ip = "${pkgs.iproute2}/bin/ip";
      awk = "${pkgs.gawk}/bin/awk";
      sed = "${pkgs.gnused}/bin/sed";
      chmod = "${pkgs.coreutils}/bin/chmod";
      sing = "/public/software/singularity/singularity-3.8.3/bin/singularity";
    in pkgs.writeShellScriptBin "lumericalLicenseManager"
    ''
      echo "Cleaning up..."
      ${sing} instance stop lumericalLicenseManager || true
      [ -d /tmp/lumerical ] && chmod -R u+w /tmp/lumerical && rm -rf /tmp/lumerical || true
      mkdir -p /tmp/lumerical
      while true; do
        if ! ss -tan | grep -q ".*TIME-WAIT .*:1084 "; then break; fi
        sleep 10
      done

      echo "Extracting image..."
      ${sing} build --sandbox /tmp/lumerical/lumericalLicenseManager \
        ${inputs.self.src.lumerical.licenseManager.sifImageFile}
      mkdir /tmp/lumerical/lumericalLicenseManager/public

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
      ${sed} -i "s|xxxxxxxxxxxxx|$mac|" \
        /tmp/lumerical/lumericalLicenseManager/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic
      ${sed} -i 's|2022.1231|2035.1231|g' \
        /tmp/lumerical/lumericalLicenseManager/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic

      echo "Starting license manager..."
      ${sing} instance start --writable /tmp/lumerical/lumericalLicenseManager lumericalLicenseManager
      ${sing} exec instance://lumericalLicenseManager /bin/sh -c \
        "pushd /home/ansys_inc/shared_files/licensing; (./start_ansysli &); (./start_lmcenter &); tail -f /dev/null"

      cleanup() {
        echo "Stopping license manager..."
        ${sing} instance stop lumericalLicenseManager
        chmod -R u+w /tmp/lumerical && rm -rf /tmp/lumerical
      }
      trap cleanup SIGINT SIGTERM SIGHUP EXIT
      tail -f /dev/null
    '';
  lumericalFdtd = pkgs.writeShellScriptBin "lumericalFdtd"
  ''
    exec ${pkgs.mpi}/bin/mpirun \
      ${pkgs.localPackages.lumerical.lumerical.cmd}/opt/ansys_inc/v231/bin/fdtd-engine-ompi-lcl "$@"
  '';
in pkgs.symlinkJoin
{
  name = "xmuhk";
  paths = (with pkgs; [ hello btop htop iotop pv ]) ++ [ lumericalLicenseManager lumericalFdtd ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
  passthru = { inherit pkgs; };
}
