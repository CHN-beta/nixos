{ fetchurl }: [
  {
    url = "https://cdn.jsdelivr.net/npm/flexsearch@0.8.143/dist/flexsearch.bundle.min.js";
    file = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/flexsearch@0.8.143/dist/flexsearch.bundle.min.js";
      hash = "sha256-Qz6UGopXPruZMfwW/HUmara5P1aawvtPPcZoguBBb0w=";
    };
    status_code = 200;
    headers = {
      "content-type" = "application/javascript; charset=utf-8";
      "content-length" = "15422";
    };
  }
  {
    url = "https://cdn.jsdelivr.net/npm/mermaid@latest/dist/mermaid.min.js";
    file = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/mermaid@latest/dist/mermaid.min.js";
      hash = "sha256-cBN+d7snO7LvlyuG6LBADMqL5TyyW/xFkRoYbcmGZd4=";
    };
    status_code = 200;
    headers = {
      "content-type" = "application/javascript; charset=utf-8";
      "content-length" = "914605";
    };
  }
]
