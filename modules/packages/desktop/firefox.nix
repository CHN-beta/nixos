inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    nixos.users.sharedModules =
    [{
      config.programs.firefox =
      {
        enable = true;
        # TODO: switch to 24.05
        # nativeMessagingHosts = [ inputs.pkgs.plasma-browser-integration ];
        package = inputs.pkgs.firefox.override { nativeMessagingHosts = [ inputs.pkgs.plasma-browser-integration ]; };
        policies.DefaultDownloadDirectory = "\${home}/Downloads";
        profiles.default =
        {
          # dualsub pakkujs RSSPreview zotero-connector
          extensions = with inputs.pkgs.firefox-addons;
          [
            tampermonkey bitwarden cookies-txt i-dont-care-about-cookies metamask switchyomega rsshub-radar tabliss
            ublock-origin wallabagger wappalyzer immersive-translate
          ];
          search.default = "Google";
        };
      };
    }];
  };
}
