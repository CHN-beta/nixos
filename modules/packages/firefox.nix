inputs:
{
  options.nixos.packages.firefox = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) firefox; in inputs.lib.mkIf (firefox != null)
  {
    # still enable global firefox, to install language packs
    programs.firefox =
    {
      enable = true;
      languagePacks = [ "zh-CN" "en-US" ];
      nativeMessagingHosts.packages = [ inputs.pkgs.uget-integrator ];
    };
    nixos =
    {
      user.sharedModules =
      [{
        config =
        {
          programs.firefox =
          {
            enable = true;
            nativeMessagingHosts = [ inputs.pkgs.uget-integrator ];
            # TODO: use fixed-version of plugins
            policies.DefaultDownloadDirectory = "\${home}/Downloads";
            profiles.default =
            {
              extensions.packages = with inputs.pkgs.firefox-addons;
              [
                tampermonkey bitwarden cookies-txt dualsub firefox-color i-dont-care-about-cookies
                metamask pakkujs rsshub-radar rsspreview tabliss tree-style-tab ublock-origin
                wappalyzer grammarly zotero-connector smartproxy kiss-translator readeck
              ];
              search = { default = "google"; force = true; };
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
                # copy as-is URLs (not escape)
                "browser.urlbar.decodeURLsOnCopy" = true;
              };
            };
          };
          home.file.".mozilla/firefox/profiles.ini".force = true;
        };
      }];
    };
  };
}
