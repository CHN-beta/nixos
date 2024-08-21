# 使用 SSH 隧道连接

在学校外且不使用厦大 VPN 时，无法直接连接到学校的服务器，可以通过下面的方法连接到：
  首先连接到 vps6.chn.moe。这个服务器在校外（洛杉矶），因此可以直接连接到。
  同时，它通过别的方式与学校的服务器保持着连接，利用这个保持着的连接，跳回到学校的服务器。

这个跳转的过程不需要手动操作，只需要将软件设置好即可。

## PuTTY

1. 首先设置一个名为 `vps6` 的会话。
   1. 在 Session 页，填入 `vps6.chn.moe` 作为 Host Name。
   2. 在 Connection -> SSH -> Auth -> Credentials 页，在 “Private key file for authentication“ 选择密钥文件。
   3. 在 Connection -> Data 页，在 “Auto-login username” 填写用户名。
   4. 回到 Session 页，在 “Saved Sessions” 填入 `vps6` 并点击 “Save” 保存配置。
2. 再设置一个名为 `wireguard.xmupc1` 的会话。
   1. 在 Session 页，填入 `wireguard.xmupc1.chn.moe` 作为 Host Name。
   2. 在 Connection -> SSH -> Auth -> Credentials 页和 Connection -> Data 页，需要修改的设置与在 `vps6` 会话中相同。
   3. 在 Connection -> Proxy 页，设置 Proxy type 为 `SSH to proxy and use port forwarding`，Proxy hostname 为 `vps6`。
   4. 回到 Session 页，在 “Saved Sessions” 填入 `wireguard.xmupc1` 并点击 “Save” 保存配置。

之后双击双击 `wireguard.xmupc1` 会话即可连接到学校的服务器。

## WinSCP

1. 在登陆界面，点击 “新建站点”。
   1. 设置 “文件协议” 为 `SCP`，“主机名” 为 `wireguard.xmupc1.chn.moe`，并输入用户名。
   2. 然后点击右下角 “高级” 继续修改设置。
   3. 在 连接 -> 隧道 页，勾选 “通过 SSH 隧道进行连接”，主机名填写 `vps6.chn.moe`，选择密钥文件，并填写用户名。
   4. 在 SSH -> 验证 页，选择密钥文件。
   5. 点击 “确定”，再点击 “保存”。

## OpenSSH

下面是一个命令的示例：

```bash
ssh -J username@vps6.chn.moe username@wireguard.xmupc1.chn.moe
```
