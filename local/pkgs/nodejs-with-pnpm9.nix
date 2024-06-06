{ nodejs, fetchurl }: nodejs.overrideAttrs (prev:
{
  passthru.pkgs = prev.passthru.pkgs.extend (final: prev:
  {
    pnpm = prev.pnpm.override
    {
      version = "9.1.0";
      src = fetchurl
      {
        url = "https://registry.npmjs.org/pnpm/-/pnpm-9.1.0.tgz";
        sha512 = "Z/WHmRapKT5c8FnCOFPVcb6vT3U8cH9AyyK+1fsVeMaq07bEEHzLO6CzW+AD62IaFkcayDbIe+tT+dVLtGEnJA==";
      };
    };
  });
})
