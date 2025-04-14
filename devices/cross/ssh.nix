inputs:
let
  # ed25519 key of each device
  publicKey = rec
  {
    vps6 = "AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
    vps7 = "AAAAC3NzaC1lZDI1NTE5AAAAIF5XkdilejDAlg5hZZD0oq69k8fQpe9hIJylTo/aLRgY";
    nas = "AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
    one = "AAAAC3NzaC1lZDI1NTE5AAAAIC5i2Z/vK0D5DBRg3WBzS2ejM0U+w3ZPDJRJySdPcJ5d";
    pc = "AAAAC3NzaC1lZDI1NTE5AAAAIMSfREi19OSwQnhdsE8wiNwGSFFJwNGN0M5gN+sdrrLJ";
    # TODO: 正确设置dns
    srv1 = srv1-node0;
    srv1-node0 = "AAAAC3NzaC1lZDI1NTE5AAAAIDm6M1D7dBVhjjZtXYuzMj2P1fXNWN3O9wmwNssxEeDs";
    srv1-node1 = "AAAAC3NzaC1lZDI1NTE5AAAAIIFmG/ZzLDm23NeYa3SSI0a0uEyQWRFkaNRE9nB8egl7";
    srv1-node2 = "AAAAC3NzaC1lZDI1NTE5AAAAIDhgEApzHhVPDvdVFPRuJ/zCDiR1K+rD4sZzH77imKPE";
    srv2 = srv2-node0;
    srv2-node0 = "AAAAC3NzaC1lZDI1NTE5AAAAIJZ/+divGnDr0x+UlknA84Tfu6TPD+zBGmxWZY4Z38P6";
    srv2-node1 = "AAAAC3NzaC1lZDI1NTE5AAAAINTvfywkKRwMrVp73HfHTfjhac2Tn9qX/lRjLr09ycHp";
  };
  # initrd ed25519 key of each device
  initrdPublicKey =
  {
    vps6 = "AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
    vps7 = "AAAAC3NzaC1lZDI1NTE5AAAAIGZyQpdQmEZw3nLERFmk2tS1gpSvXwW0Eish9UfhrRxC";
    nas = "AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
  };
  # 除了使用域名（xxx.chn.moe initrd.xxx.chn.moe）以外，每个设备还可能通过什么访问
  # wireguard 导致的域名和 IP 不需要写在这里，由 wireguard 导入
  extraAccess.vps7 = [ "ssh.git.chn.moe" ];
in
{
  config =
  {
    programs.ssh.knownHosts =
      (builtins.mapAttrs
        # TODO: 分离 wireguard 相关
        (n: v:
        {
          publicKey = "ssh-ed25519 ${v}";
          hostNames = [ "${n}.chn.moe" "wg0.${n}.chn.moe" "wg1.${n}.chn.moe" ] ++ extraAccess.${n} or [];
        })
        publicKey)
      // (builtins.mapAttrs
        (n: v: { publicKey = "ssh-ed25519 ${v}"; hostNames = [ "initrd.${n}.chn.moe" ]; }) initrdPublicKey);
  };
}
