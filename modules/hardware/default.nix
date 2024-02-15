inputs:
{
  imports = inputs.localLib.mkModules [ ./gpu.nix ./legion.nix ];
  options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
  {
    bluetooth.enable = mkOption { type = types.bool; default = false; };
    joystick.enable = mkOption { type = types.bool; default = false; };
    printer.enable = mkOption { type = types.bool; default = false; };
    sound.enable = mkOption { type = types.bool; default = false; };
    cpus = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
    halo-keyboard.enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.config.nixos) hardware;
      inherit (builtins) listToAttrs map concatLists;
      inherit (inputs.localLib) attrsToList;
    in mkMerge
    [
      # bluetooth
      (mkIf hardware.bluetooth.enable { hardware.bluetooth.enable = true; })
      # joystick
      (mkIf hardware.joystick.enable { hardware = { xone.enable = true; xpadneo.enable = true; }; })
      # printer
      (
        mkIf hardware.printer.enable
        {
          services =
          {
            printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
            avahi = { enable = true; nssmdns = true; openFirewall = true; };
          };
        }
      )
      # sound
      (
        mkIf hardware.sound.enable
        {
          hardware.pulseaudio.enable = false;
          services.pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; };
          sound.enable = true;
          security.rtkit.enable = true;
          environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
            let
              content = builtins.readFile
                (inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
              matched = builtins.match
                ".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
              spaces = builtins.elemAt matched 0;
              comment = builtins.elemAt matched 1;
              config = ''["session.suspend-timeout-seconds"] = 0'';
            in
              builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
        }
      )
      # cpus
      (
        mkIf (hardware.cpus != [])
        {
          hardware.cpu = listToAttrs
            (map (name: { inherit name; value = { updateMicrocode = true; }; }) hardware.cpus);
          boot.initrd.availableKernelModules =
            let
              modules =
              {
                intel =
                [
                  "intel_cstate" "aesni_intel" "intel_cstate" "intel_uncore" "intel_uncore_frequency" "intel_powerclamp"
                ];
                amd = [];
              };
            in
              concatLists (map (cpu: modules.${cpu}) hardware.cpus);
        }
      )
      # halo-keyboard
      (mkIf hardware.halo-keyboard.enable
      (
        let
          keyboard = inputs.pkgs.localPackages.chromiumos-touch-keyboard;
          support = inputs.pkgs.localPackages.yoga-support;
        in
        {
          services.udev.packages = [ keyboard support ];
          systemd.services =
          {
            touch-keyboard-handler.serviceConfig =
            {
              Type = "simple";
              WorkingDirectory = "/etc/touch_keyboard";
              ExecStart = "${keyboard}/bin/touch_keyboard_handler";
            };
            yogabook-modes-handler.serviceConfig =
            {
              Type = "simple";
              ExecStart = "${support}/bin/yogabook-modes-handler";
              StandardOutput = "journal";
            };
            monitor-sensor =
            {
              wantedBy = [ "default.target" ];
              serviceConfig =
              {
                Type = "simple";
                ExecStart = "${inputs.pkgs.iio-sensor-proxy}/bin/monitor-sensor --hinge";
              };
            };
          };
          environment.etc."touch_keyboard".source = "${keyboard}/etc/touch_keyboard";
          boot.initrd =
          {
            services.udev.packages = [ keyboard support ];
            systemd =
            {
              extraBin =
              {
                touch_keyboard_handler = "${keyboard}/bin/touch_keyboard_handler";
                yogabook-modes-handler = "${support}/bin/yogabook-modes-handler";
              };
              services =
              {
                touch-keyboard-handler =
                {
                  serviceConfig =
                  {
                    Type = "simple";
                    WorkingDirectory = "/etc/touch_keyboard";
                    ExecStart = "${keyboard}/bin/touch_keyboard_handler";
                  };
                };
                yogabook-modes-handler.serviceConfig =
                {
                  Type = "simple";
                  ExecStart = "${support}/bin/yogabook-modes-handler";
                  StandardOutput = "journal";
                };
              };

            };
            extraFiles."/etc/touch_keyboard".source = "${keyboard}/etc/touch_keyboard";
          };
        }
      ))
    ];
}
