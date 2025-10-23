# port from nixpkgs ad10336d56fcc811dc4bc5af2f8f2d0b71a407d0
{
  fetchurl, stdenv,
  wrapGAppsHook3, dpkg, autoPatchelfHook, glibc, gcc-unwrapped, nss, libdrm, libgbm, alsa-lib, xdg-utils, systemd
}: stdenv.mkDerivation rec
{
  pname = "dida";
  version = "6.0.40";
  src = fetchurl
  {
    url = "https://cdn.dida365.cn/download/linux/linux_deb_x64/dida-${version}-amd64.deb";
    sha256 = "08wy9blzkhkn2fl8sv2prv7bzp77skg5m32jzvz3sy4j8x2nanmi";
  };
  nativeBuildInputs = [ wrapGAppsHook3 autoPatchelfHook dpkg ];
  buildInputs = [ nss glibc libdrm gcc-unwrapped libgbm alsa-lib xdg-utils ];
  runtimeDependencies = [ systemd ];
  unpackPhase =
  ''
    runHook preUnpack
    mkdir -p "$out/share" "$out/opt/dida" "$out/bin"
    dpkg-deb --fsys-tarfile "$src" | tar --extract --directory="$out"
    runHook postUnpack
  '';
  installPhase = ''
    runHook preInstall
    mv $out/usr/share $out
    rm -r $out/usr
    ln -sf "$out/opt/dida/dida" "$out/bin/dida"
    substituteInPlace "$out/share/applications/dida.desktop" --replace "Exec=/opt/dida/dida" "Exec=$out/bin/dida"
    runHook postInstall
  '';
  preFixup =
  ''
    gappsWrapperArgs+=(
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
    )
  '';
}
