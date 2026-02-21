{
  stdenv, fetchurl, autoPatchelfHook, wrapGAppsHook3, copyDesktopItems, makeDesktopItem,
  xdotool, openssl, alsa-lib, libxtst, webkitgtk_4_1, libsoup_3, libappindicator
}: stdenv.mkDerivation rec
{
  pname = "lazytyper";
  version = "1.8.7";
  src = fetchurl
  {
    url = "https://github.com/oldcai/LazyTyper-releases/releases/download/v${version}-linux/LazyTyper-${version}-linux-x64.tar.gz";
    sha256 = "0wb3dn2icv0b3g1w6kf73j0w0faxai8pkcv3nv32iclv3slh862i";
  };
  buildInputs = [ xdotool openssl alsa-lib libxtst webkitgtk_4_1 libsoup_3 libappindicator ];
  nativeBuildInputs = [ autoPatchelfHook wrapGAppsHook3 copyDesktopItems ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out/{lib,bin}
    cp LazyTyper $out/bin
    cp lib/* $out/lib
    for i in 32 64 128; do
      mkdir -p $out/share/icons/hicolor/''${i}x''${i}/apps
      cp icons/''${i}x''${i}.png $out/share/icons/hicolor/''${i}x''${i}/apps
    done
    runHook postInstall
  '';
  preFixup =
  ''
    patchelf --add-needed libappindicator3.so.1 $out/bin/LazyTyper
  '';
  copyDesktopItems = [(makeDesktopItem
  {
    name = "lazytyper";
    desktopName = "LazyTyper";
    comment = "Voice to text transcription";
    exec = "LazyTyper";
    icon = "lazytyper";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "AudioVideo" ];
  })];
}
