This is my NixOS configuration. I use it to manage:
* some vps serving some websites and services (misskey, synapse), etc.
* my laptop (Lenovo R9000P 2023), and my tablet (One Netbook One Mix 4).
* some cluster for scientific computing (vasp, lammps, etc).
With the following highlights:
* All binary is compiled for specific CPU (`-march=xxx`, like that on Gentoo). 
* All packages and configurations are managed by Nix, as much reproducible as possible.

## Using overlay

An overlay is provided through `outputs.overlays.default`, you could use it in your `configuration.nix` like this:

```nix
{
  inputs.chn-nixos.url = "github:CHN-beta/nixos";
  outputs.nixosConfigurations.my-host = inputs.nixpkgs.lib.nixosSystem
  {
    modules = [({pkgs, ...}: { config =
    {
      nixpkgs.overlays = [ inputs.chn-nixos.overlays.default ];
      environment.systemPackages = [ pkgs.localPackages.vasp.intel ];
    };})];
  };
}
```

## TODO

* Write this readme file. Something have been outdate.
* Servers in XMU should use vps9 to run proxy.
* Allow to specify oneapiArch and nvhpcArch per package.
* Update document. Something is outdate.
