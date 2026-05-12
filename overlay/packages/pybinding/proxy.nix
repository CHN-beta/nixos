{ fetchurl }:
[
  {
    url = "https://gitlab.com/libeigen/eigen/-/archive/3.3.3/eigen-3.3.3.tar.gz";
    file = fetchurl
    {
      url = "https://gitlab.com/libeigen/eigen/-/archive/3.3.3/eigen-3.3.3.tar.gz";
      hash = "sha256-/XJpQ5C9joFYYgVxfSz4I+cY9YS3eaFV23R9HmhIGi4=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "application/octet-stream";
      "content-disposition" = "attachment; filename=eigen-3.3.3.tar.gz";
    };
  }
  {
    url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/variant.hpp";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/variant.hpp";
      hash = "sha256-TsAoFQ3nrnXwS8cxg2RLiu6U7CxZGYHmIm7mHemTgSA=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "31575";
    };
  }
  {
    url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/recursive_wrapper.hpp";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/recursive_wrapper.hpp";
      hash = "sha256-Su1xw27Ctf7TM8isDU8SGXiKg9rM9LvxEh8bUiaGnR0=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "2632";
    };
  }
  {
    url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/variant_visitor.hpp";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/mapbox/variant/v1.1.4/include/mapbox/variant_visitor.hpp";
      hash = "sha256-JiPsMvUm0V8P/cXxM3BMHrCAk+cU2JGzWAoK5T2e9DI=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "743";
    };
  }
  {
    url = "https://github.com/p12tic/libsimdpp/archive//v2.0-rc2.tar.gz";
    file = fetchurl
    {
      url = "https://github.com/p12tic/libsimdpp/archive//v2.0-rc2.tar.gz";
      hash = "sha256-dLYHn29FfiMm8HGclKiB/XN4Xu71mpKGjGmTWcuXndg=";
    };
    status_code = 200;
    headers =
    {
      "content-disposition" = "attachment; filename=libsimdpp-2.0-rc2.tar.gz";
      "content-type" = "application/x-gzip";
      "content-length" = "287439";
    };
  }
  {
    url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/format.h";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/format.h";
      hash = "sha256-7v0pfyt2c2KDtMhot68W9nt13pN+j2OswuuKeB/ZnBs=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "119800";
    };
  }
  {
    url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/format.cc";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/format.cc";
      hash = "sha256-cwjmLJljDJ/iQbF5dD6PHnvUSGYfx1Elfq1kebFVzE0=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "28777";
    };
  }
  {
    url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/ostream.h";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/ostream.h";
      hash = "sha256-is8VgEdM7FovPR6X3MuRGoPfd+Gm7vtHT+3r6rZasII=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "2830";
    };
  }
  {
    url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/ostream.cc";
    file = fetchurl
    {
      url = "https://raw.githubusercontent.com/fmtlib/fmt/3.0.2/fmt/ostream.cc";
      hash = "sha256-NKg67BJHmwd5YAIkOqjNEDjvqSspLFHN2+23W5XImSQ=";
    };
    status_code = 200;
    headers =
    {
      "content-type" = "text/plain; charset=utf-8";
      "content-length" = "1073";
    };
  }
]
