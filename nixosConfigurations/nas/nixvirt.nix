{ self, ... }: {
  config.nixos.services.nixvirt.instance.ddml = {
    owner = "chn";
    storage = {
      mountFrom = "ssd";
      iso = "${self.src.iso.nixos}";
    };
    memory.sizeMB = 4096;
    cpu.count = 4;
    network.address = 2;
  };
}
