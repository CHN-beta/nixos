{ fetchurl }:
[
  {
    url = "https://cdn.jsdelivr.net/npm/flexsearch@0.8.143/dist/flexsearch.bundle.min.js";
    file = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/flexsearch@0.8.143/dist/flexsearch.bundle.min.js";
      sha256 = "0k3g87h84s667m7zphlsaqzvkdka4rszq5pw66cvngjpi8d98gj3";
    };
    status_code = 200;
    headers = {
      "content-type" = "application/javascript; charset=utf-8";
      "content-length" = "46087";
    };
  }
]
