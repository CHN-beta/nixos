inputs:
{
  options.nixos.packages.firefox = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) firefox; in inputs.lib.mkIf (firefox != null)
  {
    # still enable global firefox, to install language packs
    programs.firefox =
    {
      enable = true;
      languagePacks = [ "zh-CN" "en-US" ];
      nativeMessagingHosts.packages = with inputs.pkgs; [ uget-integrator firefoxpwa ];
    };
    nixos =
    {
      packages.packages._packages = [ inputs.pkgs.firefoxpwa ];
      user.sharedModules =
      [{
        config =
        {
          programs.firefox =
          {
            enable = true;
            nativeMessagingHosts = with inputs.pkgs;
              [ kdePackages.plasma-browser-integration uget-integrator firefoxpwa ];
            # TODO: use fixed-version of plugins
            policies.DefaultDownloadDirectory = "\${home}/Downloads";
            profiles.default =
            {
              extensions = with inputs.pkgs.firefox-addons;
              [
                tampermonkey bitwarden cookies-txt dualsub firefox-color i-dont-care-about-cookies
                metamask pakkujs switchyomega rsshub-radar rsspreview tabliss tree-style-tab ublock-origin wallabagger
                wappalyzer grammarly plasma-integration zotero-connector pwas-for-firefox smartproxy kiss-translator
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
      }];
    };
  };
}
