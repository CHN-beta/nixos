inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
    {
      programs.chromium = { enable = true; extraOpts.PasswordManagerEnabled = false; };
      nixos.user.sharedModules =
      [{
        config.programs.chromium =
        {
          enable = true;
          extensions =
          [
            { id = "mpkodccbngfoacfalldjimigbofkhgjn"; } # Aria2 Explorer
            { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
            { id = "kbfnbcaeplbcioakkpcpgfkobkghlhen"; } # Grammarly
            { id = "ihnfpdchjnmlehnoeffgcbakfmdjcckn"; } # Pixiv Fanbox Downloader
            { id = "cimiefiiaegbelhefglklhhakcgmhkai"; } # Plasma Integration
            { id = "dkndmhgdcmjdmkdonmbgjpijejdcilfh"; } # Powerful Pixiv Downloader
            { id = "padekgcemlokbadohgkifijomclgjgif"; } # Proxy SwitchyOmega
            { id = "kefjpfngnndepjbopdmoebkipbgkggaa"; } # RSSHub Radar
            { id = "abpdnfjocnmdomablahdcfnoggeeiedb"; } # Save All Resources
            { id = "nbokbjkabcmbfdlbddjidfmibcpneigj"; } # SmoothScroll
            { id = "onepmapfbjohnegdmfhndpefjkppbjkm"; } # SuperCopy 超级复制
            { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
            { id = "gppongmhjkpfnbhagpmjfkannfbllamg"; } # Wappalyzer
            { id = "hkbdddpiemdeibjoknnofflfgbgnebcm"; } # YouTube™ 双字幕
            { id = "ekhagklcjbdpajgpjgmbionohlpdbjgc"; } # Zotero Connector
            { id = "ikhdkkncnoglghljlkmcimlnlhkeamad"; } # 划词翻译
            { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # 篡改猴
            { id = "hipekcciheckooncpjeljhnekcoolahp"; } # Tabliss
            { id = "nkbihfbeogaeaoehlefnkodbefgpgknn"; } # MetaMask
            { id = "bpoadfkcbjbfhfodiogcnhhhpibjhbnh"; } # 沉浸式翻译
          ];
        };
      }];
    };
}
