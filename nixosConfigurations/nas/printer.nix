{
  services = {
    printing = {
      listenAddresses = [ "*:631" ];
      allowFrom = [
        "localhost"
        "192.168.1.0/24"
        "192.168.2.0/24"
      ];
      browsing = true;
      defaultShared = true;
      openFirewall = true;
      startWhenNeeded = false;
      extraConf = ''
        ServerAlias *
      '';
    };
    avahi = {
      publish = {
        enable = true;
        userServices = true;
      };
      allowInterfaces = [
        "enp3s0"
        "nixvirt"
        "enp4s0.20"
      ];
      reflector = true;
    };
  };
  hardware.printers = {
    ensureDefaultPrinter = "Canon_G1010";
    ensurePrinters = [
      {
        name = "Canon_G1010";
        description = "Canon PIXMA G1010";
        location = "NAS";
        deviceUri = "usb://Canon/G1010%20series?serial=700FD5";
        model = "gutenprint.5.3://bjc-G1000-series/expert";
        ppdOptions = {
          PageSize = "A4";
          printer-is-shared = "true";
        };
      }
    ];
  };
}
