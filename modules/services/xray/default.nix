{ localLib, config, ... }:
{
  imports = localLib.findModules ./.;
  config = let inherit (config.nixos.services) xray; in
  {
    assertions =
    [{
      assertion = !(xray.client != null && xray.server != null);
      message = "Currenty xray.client and xray.server could not be simutaniusly enabled.";
    }];
  };
}
