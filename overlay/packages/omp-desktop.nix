{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cargo-tauri,
  nodejs,
  pkg-config,
  wrapGAppsHook4,
  webkitgtk_4_1,
  librsvg,
  alsa-lib,
  libayatana-appindicator,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "omp-desktop";
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "apoc";
    repo = "omp-desktop";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Cbsz0t8CpRaR12FcWEe3dRTT7YCxuPHETkl6Cn3B4Dc=";
  };

  strictDeps = true;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-38xedwg5ymz/yit92XWIImaN7sHomk958rUPFD4GMWw=";

  # `Option::map_or_default` / `Result::map_or_default` stabilized in Rust 1.98 (#138099);
  # nixpkgs currently ships Rust 1.95.0 (26.05).
  postPatch = ''
    substituteInPlace src-tauri/src/agent/mod.rs \
      --replace-fail 'ext_ui.lock().map_or_default(|s| s.clone())' 'ext_ui.lock().map(|s| s.clone()).unwrap_or_default()'
    substituteInPlace src-tauri/src/approval.rs \
      --replace-fail '.map_or_default(|file| {' '.map(|file| {' \
      --replace-fail $'                    .collect()\n            });' $'                    .collect()\n            })\n            .unwrap_or_default();'
    substituteInPlace src-tauri/src/browser/proxy/discovery.rs \
      --replace-fail 'value.get_mut(key).map_or_default(Value::take)' 'value.get_mut(key).map(Value::take).unwrap_or_default()'
    substituteInPlace src-tauri/src/external_open.rs \
      --replace-fail '.map_or_default(|mut pending| std::mem::take(&mut *pending))' '.map(|mut pending| std::mem::take(&mut *pending)).unwrap_or_default()'
    substituteInPlace src-tauri/src/widgets/context.rs \
      --replace-fail '.map_or_default(|name| name.shorten().to_string());' '.map(|name| name.shorten().to_string()).unwrap_or_default();'
  '';

  tauriBuildFlags = [
    "--config"
    "tauri.dist.conf.json"
  ];

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook4
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    webkitgtk_4_1
    librsvg
    alsa-lib
    libayatana-appindicator
  ];

  doCheck = false;

  meta = {
    description = "Native desktop application for interacting with oh-my-pi (omp)";
    homepage = "https://github.com/apoc/omp-desktop";
    changelog = "https://github.com/apoc/omp-desktop/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    inherit (cargo-tauri.hook.meta) platforms;
    mainProgram = "omp-desktop";
  };
})
