# install nix

1. download [nix-portable](https://github.com/DavHau/nix-portable),
  move the executable file to `$PATH`, rename it to `nix-portable` and make it executable.
2. create several symlinks (including `nix` `nix-store` etc.) to it.
3. create file `~/.config/nix/nix.conf` with the following content: `ignored-acls = lustre.lov`
4. run `nix --version`, wait for it to initialize and print the version.

# install or update packages

1. run `nix build github:CHN-beta/nixos#xmuhk` elsewhere (on NixOS is better, to avoid impure from FHS envs)
2. `nix-store --export $(nix-store -qR ./result) | xz -T0 | pv > xmuhk.nar.xz`
3. copy `xmuhk.nar.xz` to hpc, import it with `cat xmuhk.nar.xz | nix-store --import`
4. create gcroot symlink: `ln -s /nix/store/xxxx-xmuhk ~/.nix-portable/nix/var/nix/gcroots/current`
5. optionally `nix gc`
6. create `nix-exec` in `$PATH` with the following content, make it executable:
   ```sh
   #!/usr/bin/env sh
   nix shell ~/.nix-portable/nix/var/nix/gcroots/current -c "$(basename "$0")" "$@"
   ```
7. make symlinks to `nix-exec` for needed commands, e.g. `ln -s singularity nix-exec`
