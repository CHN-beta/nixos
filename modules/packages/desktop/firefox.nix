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
          userChrome = builtins.concatStringsSep "\n" (builtins.map
            (file: builtins.readFile "${inputs.topInputs.cascade}/chrome/includes/cascade-${file}.css")
            [ "config-mouse" "colours" "layout" "responsive" "floating-panel" "nav-bar" "tabs" ]);
          settings =
          {
            # general
            "browser.search.region" = "CN";
            "intl.locale.requested" = "zh-CN,en-US";
            "browser.aboutConfig.showWarning" = false;
            "browser.bookmarks.showMobileBookmarks" = true;
            "browser.download.panel.shown" = true;
            "browser.download.useDownloadDir" = true;
            "browser.newtab.extensionControlled" = true;
            "browser.toolbars.bookmarks.visibility" = "never";
            # allow to apply userChrome.css
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          };
        };
      };
    }];
  };
}
