inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    nixos.users.sharedModules = [{ config =
    {
      programs.firefox =
      {
        enable = true;
        # TODO: switch to 24.05
        # nativeMessagingHosts = [ inputs.pkgs.plasma-browser-integration ];
        package = inputs.pkgs.firefox.override { nativeMessagingHosts = [ inputs.pkgs.plasma-browser-integration ]; };
        policies.DefaultDownloadDirectory = "\${home}/Downloads";
        profiles.default =
        {
          extensions = with inputs.pkgs.firefox-addons;
          [
            immersive-translate tampermonkey bitwarden cookies-txt dualsub firefox-color i-dont-care-about-cookies
            metamask pakkujs switchyomega rsshub-radar rsspreview tabliss tree-style-tab ublock-origin wallabagger
            wappalyzer grammarly
            (
              buildFirefoxXpiAddon
              {
                pname = "zotero-connector";
                version = "5.0.114";
                addonId = "zotero@chnm.gmu.edu";
                url = "https://download.zotero.org/connector/firefox/release/Zotero_Connector-5.0.114.xpi";
                sha256 = "1g9d991m4vfj5x6r86sw754bx7r4qi8g5ddlqp7rcw6wrgydhrhw";
                meta = {};
              }
            )
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
    };}];
    # still enable global firefox, to install language packs
    programs.firefox = { enable = true; languagePacks = [ "zh-CN" "en-US" ]; };
  };
}
