```bash
nixos-install --flake .#vps4 --option substituters https://nix-store.chn.moe \
  --option require-sigs false --option system-features gccarch-znver2 \
  --option extra-experimental-features ca-derivations
nix-serve -p 5000
nix copy --substitute-on-destination --to ssh://server /run/current-system
nix copy --to ssh://nixos@192.168.122.56 ./result
sudo nixos-install --flake .#bootstrap --option substituters http://192.168.122.1:5000 --option require-sigs false
sudo chattr -i var/empty
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
sudo nixos-rebuild switch --flake .#vps6 --log-format internal-json -v |& nom --json
boot.shell_on_fail systemd.setenv=SYSTEMD_SULOGIN_FORCE=1
sudo usbipd
ssh -R 3240:127.0.0.1:3240 root@192.168.122.57
modprobe vhci-hcd
sudo usbip bind -b 3-6
usbip attach -r 127.0.0.1 -b 3-6
systemd-cryptenroll --fido2-device=auto /dev/vda2
systemd-cryptsetup attach root /dev/vda2
ssh-keygen -t rsa -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_rsa_key
ssh-keygen -t ed25519 -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
systemd-machine-id-setup --root=/mnt/nix/persistent
pg_dump -h 127.0.0.1 -U synapse -Fc -f synaps.dump synapse
pg_restore -h 127.0.0.1 -U misskey -d misskey --data-only --jobs=4 misskey.dump
cryptsetup luksUUID --uuid=<the new UUID> /dev/sda1
mungekey -k munge.key
mv munge.key munge.key.orig
sops -e --input-type binary --output-type binary munge.key.orig > munge.key
rm munge.key.orig
```
