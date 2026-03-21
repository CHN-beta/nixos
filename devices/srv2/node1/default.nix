{ config, ... }:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "skylake";
        network.settings =
          { static.eno2 = { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; }; trust = [ "eno2" ]; };
        fileSystems.swap = [ "/nix/swap/swap" ];
      };
      services =
      {
        beesd."/" = {};
        lumericalLicenseManager.macAddress = "70:20:84:09:a3:52";
      };
    };
    systemd =
    {
      tmpfiles.rules = [ "w /sys/devices/system/cpu/intel_pstate/no_turbo - - - - 1" ];
      services.nvidia-power-limit =
      {
        wantedBy = [ "multi-user.target" ];
        path = [ config.hardware.nvidia.package ];
        script = "nvidia-smi -pl 200";
        serviceConfig.Type = "oneshot";
      };
    };
  };
}
