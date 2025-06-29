inputs:
{
  imports = inputs.localLib.findModules ./.;
  config = let inherit (inputs.config.nixos.services) xray; in
  {
    assertions =
    [{
      assertion = !(xray.client != null && xray.server != null);
      message = "Currenty xray.client and xray.server could not be simutaniusly enabled.";
    }];
  };
}
