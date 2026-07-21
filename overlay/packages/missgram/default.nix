{
  lib,
  rustPlatform,
  pkg-config,
  versionCheckHook,
}:

rustPlatform.buildRustPackage {
  pname = "missgram";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [
    pkg-config
  ];
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  meta = with lib; {
    description = "Misskey to Telegram forwarder bot";
    license = licenses.mit; # Or whichever license was applicable
    maintainers = [ ];
  };
}
