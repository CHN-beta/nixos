# install nix

1. Build nix using `nix build github:NixOS/nixpkgs/nixos-24.11#nixStatic`, upload, create symlink `nix-store` `nix-build` etc. pointing to it.
2. Upload `.config/nix/nix.conf`.

# install or update packages

1. On nixos, make sure `/public/home/xmuhk/.nix` is mounted correctly.
2. Build using `sudo nix build --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' .#xmuhk` .
3. Diff store using `sudo nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' -qR ./result | grep -Fxv -f <(ssh xmuhk find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/public/home/xmuhk/.nix/store&state=/public/home/xmuhk/.nix/state&log=/public/home/xmuhk/.nix/log' --export | xz -T0 | pv > xmuhk.nar.xz` .
4. Upload `xmuhk.nar.xz` to hpc.
5. On hpc, `pv xmuhk.nar.xz | xz -d | nix-store --import` .
6. Create gcroot using `nix build /xxx-xmuhk -o .nix/state/gcroots/current`, where `/xxx-xmuhk` is the last path printed by `nix-store --import` .
