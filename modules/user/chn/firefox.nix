inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.packages.firefox != null)
  {
    home-manager.users.chn.config =
    {
      programs.firefox =
      {
        enable = true;
        nativeMessagingHosts = with inputs.pkgs; [ plasma-browser-integration uget-integrator firefoxpwa ];
        # TODO: use fixed-version of plugins
        policies.DefaultDownloadDirectory = "\${home}/Downloads";
        profiles.default =
        {
          extensions = with inputs.pkgs.firefox-addons;
          [
            immersive-translate tampermonkey bitwarden cookies-txt dualsub firefox-color i-dont-care-about-cookies
            metamask pakkujs switchyomega rsshub-radar rsspreview tabliss tree-style-tab ublock-origin wallabagger
            wappalyzer grammarly plasma-integration zotero-connector 
            (buildFirefoxXpiAddon
            {
              pname = "pwas-for-firefox";
              version = "2.12.1";
              addonId = "firefoxpwa@filips.si";
              url = "https://addons.mozilla.org/firefox/downloads/file/4293028/pwas_for_firefox-2.12.1.xpi";
              sha256 = "sha256-m8BCAlQt37RxVnWw+2hIPnmofTicNa5OWkwXp/IXdWY=";
              meta = {};
            })
          ];
          search = { default = "Google"; force = true; };
          userChrome = builtins.readFile "${inputs.topInputs.lepton}/userChrome.css";
          userContent = builtins.readFile "${inputs.topInputs.lepton}/userContent.css";
          extraConfig = builtins.readFile "${inputs.topInputs.lepton}/user.js";
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
            # automatically enable extensions
            "extensions.autoDisableScopes" = 0;
          };
        };
      };
      home.file.".mozilla/firefox/profiles.ini".force = true;
    };
  };
}
