{ config.services = { qemuGuest.enable = true; spice-vdagentd.enable = true; xserver.videoDrivers = [ "qxl" ]; }; }
