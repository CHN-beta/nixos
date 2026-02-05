{ lib, config, pkgs, topInputs, ... }:
{
  options.nixos.hardware.ugreen = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.hardware) ugreen; in lib.mkIf (ugreen != null)
  (
    let
      cli = pkgs.ugreen-leds-cli.overrideAttrs (prev:
      {
        src = topInputs.ugreen;
        sourceRoot = "source/cli";
        nativeBuildInputs = prev.nativeBuildInputs or [] ++ [ pkgs.makeWrapper ];
        postInstall =
        ''
          g++ $src/scripts/blink-disk.cpp -o $out/bin/ugreen-blink-disk
          g++ $src/scripts/check-standby.cpp -o $out/bin/ugreen-check-standby
          cp $src/scripts/ugreen-{diskiomon,probe-leds} $out/bin
          substituteInPlace $out/bin/ugreen-diskiomon \
            --replace-fail /usr/sbin/smartctl ${pkgs.smartmontools}/bin/smartctl
          wrapProgram $out/bin/ugreen-probe-leds \
            --suffix PATH : ${lib.makeBinPath (with pkgs; [ i2c-tools kmod ])} \
            --set STANDBY_MON_PATH $out/bin/ugreen-check-standby \
            --set BLINK_MON_PATH $out/bin/ugreen-blink-disk
          wrapProgram $out/bin/ugreen-diskiomon \
            --suffix PATH : ${lib.makeBinPath (with pkgs; [ which dmidecode kmod gawk ])}
        '';
      });
      inherit (config.boot.kernelPackages) kernel;
      kernelModule = pkgs.stdenv.mkDerivation
      {
        name = "ugreen-leds-kmod";
        src = topInputs.ugreen;
        sourceRoot = "source/kmod";
        nativeBuildInputs = kernel.moduleBuildDependencies;
        KERNELRELEASE = kernel.modDirVersion;
        KDIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
        buildPhase =
        ''
          make -C $KDIR M=$(pwd) modules
        '';
        installPhase =
        ''
          # Install in extra directory for boot.extraModulePackages
          mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
          cp led-ugreen.ko $out/lib/modules/${kernel.modDirVersion}/extra/
        '';
      };
    in
    {
      environment.systemPackages = [ cli ];
      boot = { kernelModules = [ "i2c-dev" "led-ugreen" ]; extraModulePackages = [ kernelModule ]; };
      systemd =
      {
        tmpfiles.rules = [ "w /sys/bus/i2c/devices/i2c-15/new_device - - - - jc42 0x44" ];
        services =
        {
          ugreen-diskiomon =
          {
            after = [ "ugreen-probe-leds.service" ];
            requires = [ "ugreen-probe-leds.service" ];
            serviceConfig =
            {
              ExecStart = "${cli}/bin/ugreen-diskiomon";
              StandardOutput = "journal";
              ProtectKernelTunables = false;
              ReadWritePaths = "/sys/class/leds";
            };
            wantedBy = [ "multi-user.target" ];
          };
          ugreen-probe-leds =
          {
            after = [ "systemd-modules-load.service" ];
            requires = [ "systemd-modules-load.service" ];
            serviceConfig =
            {
              Type = "oneshot";
              ExecStart = "${cli}/bin/ugreen-probe-leds";
              RemainAfterExit = true;
              StandardOutput = "journal";
            };
            wantedBy = [ "multi-user.target" ];
          };
        };
      };
    }
  );
}
