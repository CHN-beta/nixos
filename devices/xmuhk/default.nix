# sudo nix build --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' .#xmuhk
# sudo nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' -qR ./result | sudo xargs nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' --export | pv | xz -T0 > xmuhk.nar.xz
# cat data.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = null; cuda = null; nixRoot = "/public/home/xmuhk/.nix"; };
  });
  # go = pkgs.go.overrideAttrs (prev:
  # {
  #   buildInputs = builtins.filter (x: x != pkgs.glibc.static) prev.buildInputs;
  # });
  # buildGoModule = pkgs.buildGoModule.override { inherit go; };
  # singularity = (pkgs.singularity.override { inherit buildGoModule; }).overrideAttrs (prev:
  # {
  #   configureFlags = builtins.filter (x: x != "--without-libsubid") prev.configureFlags;
  #   buildInputs = prev.buildInputs ++ [ pkgs.shadow ];
  #   # env.CGO_ENABLED = "1";
  #   # autoPatchelfFlags = [ "--keep-libc" ];
  # });
  singularity = pkgs.singularity.overrideAttrs (prev:
  {
    configureFlags = builtins.filter (x: x != "--without-libsubid") prev.configureFlags;
    buildInputs = prev.buildInputs ++ [ pkgs.shadow ];
    # env.CGO_ENABLED = "1";
    # autoPatchelfFlags = [ "--keep-libc" ];
  });
  lumericalLicenseManager = 
    let
      ip = "${pkgs.iproute2}/bin/ip";
      awk = "${pkgs.gawk}/bin/awk";
      sed = "${pkgs.gnused}/bin/sed";
      chmod = "${pkgs.coreutils}/bin/chmod";
      sing = "${singularity}/bin/singularity";
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
        --bind /tmp/lumerical/license.txt:/home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic \
        ${inputs.self.src.lumerical.licenseManager.sifImageFile}
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
  passthru = { inherit pkgs singularity; };
}
