inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.packages =
    let
      inherit (inputs.lib) mkOption types;
      packageSets =
      [
        # no gui, only used for specific purpose
        "server"
        "server-extra"
        # gui, for daily use, but not install large programs such as matlab
        "desktop"
        "desktop-extra"
        # nearly everything
        "workstation"
      ];
    in
    {
      packageSet = mkOption { type = types.enum packageSets; default = "server"; };
      extraPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      excludePackages = mkOption { type = types.listOf types.unspecified; default = []; };
      extraPythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      excludePythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      extraPrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      excludePrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      _packageSets = mkOption
      {
        type = types.listOf types.nonEmptyStr;
        readOnly = true;
        default = builtins.genList (i: builtins.elemAt packageSets i)
          ((inputs.localLib.findIndex inputs.config.nixos.packages.packageSet packageSets) + 1);
      };
      _packages = mkOption { type = types.listOf types.unspecified; default = []; };
      _pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
      _prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    };
  config =
  {
    environment.systemPackages = let inherit (inputs.lib.lists) subtractLists; in with inputs.config.nixos.packages;
      (inputs.lib.lists.subtractLists excludePackages (_packages ++ extraPackages))
      ++ [
        (inputs.pkgs.python3.withPackages (pythonPackages:
          inputs.lib.lists.subtractLists
            (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
              excludePythonPackages))
            (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
              (_pythonPackages ++ extraPythonPackages)))))
        (inputs.pkgs.callPackage ({ stdenv }: stdenv.mkDerivation
        {
          name = "prebuild-packages";
          propagateBuildInputs = inputs.lib.lists.subtractLists excludePrebuildPackages
            (_prebuildPackages ++ extraPrebuildPackages);
          phases = [ "installPhase" ];
          installPhase =
          ''
            runHook preInstall
            mkdir -p $out
            runHook postInstall
          '';
        }) {})
      ];
  };
}

    # programs.firejail =
    # {
    #   enable = true;
    #   wrappedBinaries =
    #   {
    #     qq =
    #     {
    #       executable = "${inputs.pkgs.qq}/bin/qq";
    #       profile = "${inputs.pkgs.firejail}/etc/firejail/linuxqq.profile";
    #     };
    #   };
    # };

# config.nixpkgs.config.replaceStdenv = { pkgs }: pkgs.ccacheStdenv;
  # only replace stdenv for large and tested packages
  # config.programs.ccache.packageNames = [ "webkitgtk" "libreoffice" "tensorflow" "linux" "chromium" ];
  # config.nixpkgs.overlays = [(final: prev:
  # {
  #   libreoffice-qt = prev.libreoffice-qt.override (prev: { unwrapped = prev.unwrapped.override
  #     (prev: { stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; }); });
  #   python3 = prev.python3.override { packageOverrides = python-final: python-prev:
  #     {
  #       tensorflow = python-prev.tensorflow.override
  #         { stdenv = final.ccacheStdenv.override { stdenv = python-prev.tensorflow.stdenv; }; };
  #     };};
  #   # webkitgtk = prev.webkitgtk.override (prev:
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; enableUnifiedBuilds = false; });
  #   wxGTK31 = prev.wxGTK31.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK31.stdenv; }; };
  #   wxGTK32 = prev.wxGTK32.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK32.stdenv; }; };
  #   # firefox-unwrapped = prev.firefox-unwrapped.override
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.firefox-unwrapped.stdenv; }; };
  #   # chromium = prev.chromium.override
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.chromium.stdenv; }; };
  #   # linuxPackages_xanmod_latest = prev.linuxPackages_xanmod_latest.override
  #   # {
  #   #   kernel = prev.linuxPackages_xanmod_latest.kernel.override
  #   #   {
  #   #     stdenv = final.ccacheStdenv.override { stdenv = prev.linuxPackages_xanmod_latest.kernel.stdenv; };
  #   #     buildPackages = prev.linuxPackages_xanmod_latest.kernel.buildPackages //
  #   #       { stdenv = prev.linuxPackages_xanmod_latest.kernel.buildPackages.stdenv; };
  #   #   };
  #   # };
  # })];
  # config.programs.ccache.packageNames = [ "libreoffice-unwrapped" ];

# cross-x86_64-pc-linux-musl/gcc
# dev-cpp/cpp-httplib ? how to use
# dev-cpp/cppcoro
# dev-cpp/date
# dev-cpp/nameof
# dev-cpp/scnlib
# dev-cpp/tgbot-cpp
# dev-libs/pocketfft
# dev-util/intel-hpckit
# dev-util/nvhpc
# kde-misc/wallpaper-engine-kde-plugin
# media-fonts/arphicfonts
# media-fonts/sarasa-gothic
# media-gfx/flameshot
# media-libs/libva-intel-driver
# media-libs/libva-intel-media-driver
# media-sound/netease-cloud-music
# net-vpn/frp
# net-wireless/bluez-tools
# sci-libs/mkl
# sci-libs/openblas
# sci-libs/pfft
# sci-libs/scalapack
# sci-libs/wannier90
# sci-mathematics/ginac
# sci-mathematics/mathematica
# sci-mathematics/octave
# sci-physics/lammps::touchfish-os
# sci-physics/vsim
# sci-visualization/scidavis
# sys-apps/flatpak
# sys-cluster/modules
# sys-devel/distcc
# sys-fs/btrfs-progs
# sys-fs/compsize
# sys-fs/dosfstools
# sys-fs/duperemove
# sys-fs/exfatprogs
# sys-fs/mdadm
# sys-fs/ntfs3g
# sys-kernel/dracut
# sys-kernel/linux-firmware
# sys-kernel/xanmod-sources
# sys-kernel/xanmod-sources:6.1.12
# sys-kernel/xanmod-sources::touchfish-os
# sys-libs/libbacktrace
# sys-libs/libselinux
# x11-apps/xinput
# x11-base/xorg-apps
# x11-base/xorg-fonts
# x11-base/xorg-server
# x11-misc/imwheel
# x11-misc/optimus-manager
# x11-misc/unclutter-xfixes

#   ++ ( with inputs.pkgs.pkgsCross.mingwW64.buildPackages; [ gcc ] );
