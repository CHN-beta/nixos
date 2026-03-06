{ src, stdenv, cmake, python3Packages, fcitx5, nlohmann_json }:
  let python = python3Packages.python.withPackages (ps: with ps; [ numpy ]);
  in stdenv.mkDerivation rec
  {
    name = "fcitx5-vocotype";
    inherit src;
    preUnpack =
    ''
      mkdir -p $sourceRoot
      cp -r ${src}/fcitx5/addon/* $sourceRoot/
    '';
    sourceRoot = "fcitx5/addon";
    buildInputs = [ fcitx5 python nlohmann_json ];
    nativeBuildInputs = [ cmake ];
    patches = [ ./vocotype-2.1.2-fcitx5-system-install.patch ];
    postPatch =
    ''
      substituteInPlace vocotype.cpp --replace-fail /usr/bin $out/bin
    '';
    postInstall =
    ''
      mkdir -p $out/bin
      cp ${src}/fcitx5/backend/audio_recorder.py $out/bin/vocotype-audio-recorder
      mkdir -p $out/share/fcitx5/addon
      cp ${src}/fcitx5/data/vocotype.conf $out/share/fcitx5/addon/vocotype.conf
      mkdir -p $out/share/fcitx5/inputmethod
      cp ${src}/fcitx5/data/vocotype.conf.in $out/share/fcitx5/inputmethod/vocotype.conf
    '';
  }
