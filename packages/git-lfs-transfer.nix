{ buildGoModule, src, hash }: buildGoModule
{
  name = "git-lfs-transfer";
  inherit src;
  vendorHash = hash;
}
