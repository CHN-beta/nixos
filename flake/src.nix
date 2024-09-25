{ inputs }: let inherit (inputs.self.packages.x86_64-linux) pkgs; in
{
  nixos-wallpaper = pkgs.fetchgit
  {
    url = "https://git.chn.moe/chn/nixos-wallpaper.git";
    rev = "1ad78b20b21c9f4f7ba5f4c897f74276763317eb";
    sha256 = "0faahbzsr44bjmwr6508wi5hg59dfb57fzh5x6jh7zwmv4pzhqlb";
    fetchLFS = true;
  };
  git-lfs-transfer = "sha256-AXXYo00ewbg656KiDasHrf3Krh6ZPUabmB3De090zCw=";
}
