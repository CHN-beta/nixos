inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    home-manager.users.chn.config =
    {
      programs.firefox =
      {
        enable = true;
        nativeMessagingHosts = [ inputs.pkgs.plasma-browser-integration ];
        # TODO: switch to chromium as default browser
        # TODO: use fixed-version of plugins
        policies.DefaultDownloadDirectory = "\${home}/Downloads";
        profiles.default =
        {
          extensions = with inputs.pkgs.firefox-addons;
          [
            immersive-translate tampermonkey bitwarden cookies-txt dualsub firefox-color i-dont-care-about-cookies
            metamask pakkujs switchyomega rsshub-radar rsspreview tabliss tree-style-tab ublock-origin wallabagger
            wappalyzer grammarly plasma-integration zotero-connector
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
          };
        };
      };
      home.file.".mozilla/firefox/profiles.ini".force = true;
    };
    # still enable global firefox, to install language packs
    programs.firefox =
    {
      enable = true;
      languagePacks = [ "zh-CN" "en-US" ];
      nativeMessagingHosts.packages = with inputs.pkgs; [ uget-integrator ];
    };
  };
}
