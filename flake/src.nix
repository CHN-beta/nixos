{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  git-lfs-transfer = "sha256-V2cnWCyzxwxlOXXTB8Kz4X4VHvu0H/SqHBzPFwlp73o=";
  iso = pkgs.fetchurl
  {
    url = "https://releases.nixos.org/nixos/24.11/nixos-24.11beta709057.0c582677378f"
      + "/nixos-plasma6-24.11beta709057.0c582677378f-x86_64-linux.iso";
    sha256 = "000wmfn6k5awqwsx9qldhdgahv4k09w4yzmvf0djs51qjdpha082";
  };
}
