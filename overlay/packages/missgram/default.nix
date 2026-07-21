{
  lib,
  rustPlatform,
  versionCheckHook,
}:

rustPlatform.buildRustPackage {
  pname = "missgram";
  version = "0.1.0";
  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  meta = with lib; {
    description = "Misskey to Telegram forwarder bot";
    license = licenses.mit; # Or whichever license was applicable
    mainProgram = "missgram";
    maintainers = [ ];
  };
}
