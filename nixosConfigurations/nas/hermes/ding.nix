{
  config,
  pkgs,
  ...
}:
{
  config = {
    systemd.services.hermes-dingtalk-punch = {
      description = "DingTalk Auto Punch-in via Hermes Agent and ADB";
      serviceConfig = {
        Type = "oneshot";
        User = config.services.hermes-agent.user;
        Group = config.services.hermes-agent.group;
        WorkingDirectory = "/tmp";
        EnvironmentFile = [ config.nixos.system.sops.templates."hermes.env".path ];
      };
      environment = {
        HOME = config.services.hermes-agent.stateDir;
        HERMES_HOME = "${config.services.hermes-agent.stateDir}/.hermes";
      };
      path = [ config.system.path ];
      script = ''
        set -euo pipefail

        SERIAL="1164e38d"
        TMP_DIR=$(mktemp -d /tmp/dingtalk-punch.XXXXXX)
        chmod 0700 "$TMP_DIR"
        trap 'rm -rf "$TMP_DIR"' EXIT

        # 1. 前置 ADB 设备连接检测
        if ! adb -s "$SERIAL" get-state 2>/dev/null | grep -q "device"; then
          hermes send --to matrix "打卡失败：未检测到 ADB 目标设备 ($SERIAL) 连接或调试未授权。"
          exit 1
        fi

        # 2. 构造 Hermes Agent 任务提示词
        PROMPT=$(cat <<EOF
        # 任务：用 ADB 帮我在钉钉上打卡

        你面前有一台通过 USB 连接、已开启 USB 调试的安卓手机。请用 \`adb\` 操作它，在钉钉里完成当前时段的考勤打卡，并在结束后报告结果。

        ## 一、环境事实（实测确认，可直接依赖）
        - 设备序列号：\`$SERIAL\`（OnePlus 9 / LE2110，分辨率 1080 × 2400）
        - 钉钉包名：\`com.alibaba.android.rimet\`
        - 启动 Activity：\`com.alibaba.android.rimet/.biz.LaunchHomeActivity\`
        - 锁屏：无密码，上滑即可解锁
        - 临时工作目录：所有过程检查截图与成功截图统一保存在 \`$TMP_DIR\` 目录下。

        ## 二、关键操作与坐标（1080×2400）
        - 唤醒与解锁：\`adb -s $SERIAL shell input keyevent KEYCODE_WAKEUP && adb -s $SERIAL shell input swipe 540 2000 540 800 200\`
        - 冷启动钉钉：\`adb -s $SERIAL shell am start -n com.alibaba.android.rimet/.biz.LaunchHomeActivity\`
        - 进考勤页：
          1. 底部导航「Workplace」：点击坐标 (334, 2224)，等待 4 秒
          2. Workplace 页「My」区「Attendance」图标：点击坐标 (134, 882)，等待 10 秒
        - 考勤页中央打卡大圆按钮：坐标 (540, 1440)
        - 打卡成功后广告弹窗右上角关闭按钮 X：坐标 (908, 374)

        ## 三、定位异常处理规则（重要）
        打开考勤页后若显示灰色“Unable to clock in/out”或“Out of range”：这通常是 LSPosed 定位模块注入延迟，并非真实超出范围。
        处理步骤：
        1. 原地等待 10 秒后重新截图检查是否变成蓝色按钮 + 绿字“Within range”；
        2. 若仍未恢复，按 KEYCODE_BACK 退出并重新点击 Attendance 进考勤页，等待 10 秒；
        3. 若仍未恢复，使用 \`am force-stop com.alibaba.android.rimet\` 强制停止钉钉并重新冷启动走一遍导航；
        4. 最多重试 3 轮。若仍不在范围内则判定打卡失败，绝对不要盲点打卡按钮。

        ## 四、执行与核验
        1. 截图确认进入考勤页且在打卡范围内；
        2. 点击中央打卡大圆按钮 (540, 1440) 进行当前班次打卡，等待 8 秒；
        3. 将打卡成功页面截图保存为 \`$TMP_DIR/punch_success.png\`；
        4. 点击 (908, 374) 关闭可能遮挡页面的广告浮层；
        5. 返回钉钉首页，通过 \`uiautomator dump\` 或查看聊天列表确认收到“打卡·成功”通知进行独立复核。

        ## 五、汇报要求（严格遵守）
        - 若打卡成功：
          必须以“打卡成功”字样开头，并包含截图的 MEDIA 绝对路径，格式如下：
          打卡成功
          MEDIA:$TMP_DIR/punch_success.png
          打卡班次与详细信息...

          ⚠️ 严禁将图片上传到 MicroBin，严禁使用 markdown 图片链接语法 \`![...](...)\`，必须使用纯文本 \`MEDIA:$TMP_DIR/punch_success.png\`。

        - 若打卡失败：
          必须以“打卡失败”字样开头，并详细说明失败时的屏幕状态和遇到的原因。
        EOF
        )

        # 3. 调用 Hermes 单次运行，TERMINAL_CWD 设为临时目录避免受工作区 AGENTS.md 干扰
        OUTPUT=$(TERMINAL_CWD="$TMP_DIR" hermes -z "$PROMPT" -t "terminal,file") || {
          hermes send --to matrix "打卡失败：Hermes agent 执行发生异常错误退出。"
          exit 1
        }

        # 4. 处理最终输出并发送 Matrix 消息
        if echo "$OUTPUT" | grep -q "打卡成功"; then
          echo "$OUTPUT" | hermes send --to matrix --subject "钉钉打卡通知"
        else
          if ! echo "$OUTPUT" | grep -q "打卡失败"; then
            OUTPUT="打卡失败：Agent 返回未预期状态
        $OUTPUT"
          fi
          echo "$OUTPUT" | hermes send --to matrix --subject "钉钉打卡失败提醒"
          exit 1
        fi
      '';
    };

    systemd.timers.hermes-dingtalk-punch = {
      description = "DingTalk Auto Punch-in Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon..Sat *-*-* 07,11,13,17:00:00";
        Persistent = true;
      };
    };
  };
}
