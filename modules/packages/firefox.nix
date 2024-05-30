inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    # still enable global firefox, to install language packs
    programs.firefox =
    {
      enable = true;
      languagePacks = [ "zh-CN" "en-US" ];
      nativeMessagingHosts.packages = with inputs.pkgs; [ uget-integrator ];
    };
  };
}
