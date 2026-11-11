{
  lib,
  stdenvNoCC,
  buildFHSEnv,
  writeText,
  writeShellScript,
  src,
  products ? [
    "MATLAB"
    "Symbolic_Math_Toolbox"
    "Parallel_Computing_Toolbox"
    "Optimization_Toolbox"
    "Global_Optimization_Toolbox"
    "Curve_Fitting_Toolbox"
    "Statistics_and_Machine_Learning_Toolbox"
    "Partial_Differential_Equation_Toolbox"
    "Signal_Processing_Toolbox"
    "Wavelet_Toolbox"
    "Image_Processing_Toolbox"
    "Deep_Learning_Toolbox"
    "MATLAB_Coder"
    "Control_System_Toolbox"
  ],
  withDocs ? true,
}:
let
  commonTargetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      bash
      cairo
      coreutils
      cups
      curl
      dbus
      expat
      findutils
      fontconfig
      freeglut
      freetype
      fribidi
      gawk
      gcc
      gdk-pixbuf
      gfortran
      glib
      glibc
      gnugrep
      gnused
      gnutar
      gtk2
      gtk3
      gzip
      libdrm
      libgbm
      libGL
      libGLU
      libICE
      libnsl
      libSM
      libsndfile
      libtirpc
      libunwind
      libuuid
      libX11
      libXcomposite
      libXcursor
      libXdamage
      libXdmcp
      libXext
      libXfixes
      libXfont2
      libXft
      libXi
      libXinerama
      libxkbcommon
      libxml2
      libXmu
      libXp
      libXpm
      libXrandr
      libXrender
      libXScrnSaver
      libxslt
      libXt
      libXtst
      libXxf86vm
      mesa
      ncurses
      ncurses5
      nspr
      nss
      numactl
      openssl
      pam
      pango
      pciutils
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      perl
      pixman
      procps
      python3
      stdenv.cc.cc.lib
      systemd
      tzdata
      unzip
      util-linux
      wayland
      which
      xdg-utils
      xz
      zlib
      zstd
    ];

  builder = buildFHSEnv {
    name = "matlab-installer-fhs";
    targetPkgs = pkgs: (commonTargetPkgs pkgs) ++ [ pkgs.libarchive ];
    extraBwrapArgs = [
      "--bind"
      "$out"
      "$out"
    ];
  };

  installerInput = writeText "installer_input.txt" (
    ''
      destinationFolder=@OUT@/opt/matlab
      fileInstallationKey=${src.fileInstallationKey}
      agreeToLicense=yes
      outputFile=@TMPDIR@/mathworks_install.log
      enableLNU=no
      improveProducts=no
      licensePath=${src.license}
    ''
    + lib.concatMapStringsSep "\n" (p: "product.${p}") products
    + "\n"
  );

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "matlab-unwrapped";
    version = "R2025b";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    dontStrip = true;

    installPhase = ''
      export HOME=$TMPDIR/home
      mkdir -p $HOME $out/opt/matlab

      echo "Extracting MATLAB installer ISO..."
      mkdir -p $TMPDIR/iso
      ${builder}/bin/matlab-installer-fhs -c "bsdtar -xf ${src.iso} -C $TMPDIR/iso"
      chmod -R +w $TMPDIR/iso
      chmod +x $TMPDIR/iso/install $TMPDIR/iso/bin/glnxa64/* || true

      sed -e "s|@OUT@|$out|g" -e "s|@TMPDIR@|$TMPDIR|g" ${installerInput} > $TMPDIR/iso/installer_input.txt

      echo "Running MathWorks Product Installer..."
      ${builder}/bin/matlab-installer-fhs -c "$TMPDIR/iso/install -mode silent -inputFile $TMPDIR/iso/installer_input.txt" || {
        echo "Installer failed! Log output:"
        cat $TMPDIR/mathworks_install.log || true
        exit 1
      }
      cat $TMPDIR/mathworks_install.log || true
      rm -rf $TMPDIR/iso

      echo "Installing license and library override..."
      mkdir -p $out/opt/matlab/licenses
      cp -f ${src.license} $out/opt/matlab/licenses/license.lic
      cp -f ${src.crack} $out/opt/matlab/bin/glnxa64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.so
      chmod 755 $out/opt/matlab/bin/glnxa64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.so

      ${lib.optionalString withDocs ''
        echo "Extracting and installing MATLAB offline documentation..."
        mkdir -p $TMPDIR/doc-iso
        ${builder}/bin/matlab-installer-fhs -c "bsdtar -xf ${src.docIso} -C $TMPDIR/doc-iso"
        chmod -R +w $TMPDIR/doc-iso
        chmod +x $TMPDIR/doc-iso/bin/glnxa64/mpm || true
        ${builder}/bin/matlab-installer-fhs -c "$TMPDIR/doc-iso/bin/glnxa64/mpm install-doc --matlabroot=$out/opt/matlab --destination=$out/opt/matlab"
        rm -rf $TMPDIR/doc-iso
      ''}
    '';
  };

  startScript = writeShellScript "matlab-start" ''
    export QT_QPA_PLATFORM=xcb
    export _JAVA_AWT_WM_NONREPARENTING=1
    export MATLAB_LOG_DIR="''${TMPDIR:-/tmp}"

    PREF_DIR="''${MATLAB_PREFDIR:-$HOME/.matlab/R2025b}"
    DOC_INIT_MARKER="$PREF_DIR/.nix_doc_location_initialized"
    if [ ! -f "$DOC_INIT_MARKER" ]; then
      mkdir -p "$PREF_DIR"
      "${unwrapped}/opt/matlab/bin/matlab" -nojvm -nosplash -nodisplay -r \
        "try; s = settings; s.matlab.help.DocLocation.PersonalValue = 'INSTALLED'; end; exit" \
        >/dev/null 2>&1 && touch "$DOC_INIT_MARKER" || true
    fi

    exec "${unwrapped}/opt/matlab/bin/matlab" "$@"
  '';
in
buildFHSEnv {
  pname = "matlab";
  version = "R2025b";
  targetPkgs = commonTargetPkgs;
  runScript = startScript;
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/pixmaps
    ln -s ${unwrapped}/opt/matlab/bin/glnxa64/cef_resources/matlab_icon.png $out/share/pixmaps/matlab.png
    cat > $out/share/applications/matlab.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=MATLAB R2025b
    Comment=Language of Technical Computing
    Exec=$out/bin/matlab -desktop
    Icon=matlab
    Categories=Science;Math;Development;
    Terminal=false
    StartupNotify=true
    EOF
  '';
  passthru = {
    inherit unwrapped builder;
  };
  meta = {
    description = "MATLAB R2025b - The Language of Technical Computing";
    homepage = "https://www.mathworks.com/products/matlab.html";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "matlab";
  };
}
