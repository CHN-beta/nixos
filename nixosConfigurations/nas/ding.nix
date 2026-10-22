{
  config,
  pkgs,
  ...
}:
{
  config = {
    systemd.services.dingtalk-punch = {
      description = "DingTalk Auto Punch-in via omp and ADB";
      serviceConfig = {
        Type = "oneshot";
        User = "straycat";
        Group = "straycat";
        WorkingDirectory = "/tmp";
      };
      environment = {
        HOME = "/home/straycat";
        PI_CODING_AGENT_DIR = "/home/straycat/.omp/agent";
      };
      path = [
        "/etc/profiles/per-user/straycat"
        config.system.path
      ];
      script = ''
        set -euo pipefail

        SERIAL="1164e38d"
        TMP_DIR=$(mktemp -d /tmp/dingtalk-punch.XXXXXX)
        chmod 0700 "$TMP_DIR"
        trap 'rm -rf "$TMP_DIR"' EXIT

        PROMPT=$(cat <<EOF
        # 任务：用 ADB 在钉钉上完成考勤打卡，并通过 Matrix 私聊汇报结果

        你面前有一台通过 USB 连接、已开启 USB 调试的安卓手机。请用 \`adb\` 操作它，在钉钉里完成当前时段的考勤打卡，并在结束后通过 Matrix MCP 工具将结果私聊发送给 \`@chn:chn.moe\`。

        ## 一、环境事实
        - 设备序列号：\`$SERIAL\`（OnePlus 9 / LE2110）
        - 钉钉包名：\`com.alibaba.android.rimet\`
        - 启动 Activity：\`com.alibaba.android.rimet/.biz.LaunchHomeActivity\`
        - 锁屏：无密码，唤醒后上滑即可解锁
        - 临时工作目录：所有过程检查截图、UI 树导出与打卡成功截图统一保存在 \`$TMP_DIR\` 目录下。

        ## 二、操作原则（动态定位，严禁盲写固定坐标）
        钉钉页面布局或弹窗位置可能随版本或状态微调，因此**不要依赖硬编码的点击坐标**：
        1. 先检查 \`adb -s $SERIAL get-state\` 确认设备在线；若设备未连接或未授权，直接跳到第五步通过 Matrix 汇报失败并退出。
        2. 唤醒屏幕并上滑解锁：
           \`adb -s $SERIAL shell input keyevent KEYCODE_WAKEUP && adb -s $SERIAL shell input swipe 540 2000 540 800 200\`
        3. 启动钉钉：
           \`adb -s $SERIAL shell am start -n com.alibaba.android.rimet/.biz.LaunchHomeActivity\`
        4. 导航与点击（结合 \`uiautomator dump\` 与截图 \`screencap -p\` + \`read\` 视觉确认）：
           - 优先使用 \`adb -s $SERIAL shell uiautomator dump /sdcard/ui.xml && adb -s $SERIAL pull /sdcard/ui.xml $TMP_DIR/ui.xml\` 获取控件精确 \`bounds\`，或用 \`adb -s $SERIAL exec-out screencap -p > $TMP_DIR/screen.png\` 后通过 \`read\` 工具查看截图判断当前画面与控件位置（注意：钉钉考勤页多为 WebView，\`uiautomator\` 若拿不到内部节点则直接看截图定位）。
           - 依次进入底部导航「工作台 / Workplace」-> 找到并打开「考勤打卡 / Attendance」页面（等待页面加载完成）。

        ## 三、定位异常处理规则（重要）
        打开考勤页后若显示灰色“Unable to clock in/out”、“Out of range”或“不在打卡范围内”：这通常是 LSPosed 定位模块注入延迟，并非真实超出范围。
        处理步骤：
        1. 原地等待几秒后重新截图检查是否变成蓝色可打卡按钮（显示“Within range”或“已进入考勤范围”）；
        2. 若仍显示超出范围，不要重启钉钉，而是根据当前截图/控件位置点击“Out of range / 重新定位 / 查看原因”相关区域，等待几秒后按返回键（\`KEYCODE_BACK\`）返回考勤页；
        3. 返回后等待几秒重新截图检查；可重复上述步骤重试（最多重试 3 轮）；
        4. 若重试后仍不在范围内则判定打卡失败，绝对不要盲点打卡按钮。

        ## 四、执行打卡与收尾核验
        1. 截图确认已进入考勤页且处于可打卡范围内；
        2. 根据截图/控件位置点击中央打卡大圆按钮完成当前班次打卡，等待约 8 秒；
        3. 将打卡结果页面截图保存为 \`$TMP_DIR/punch_success.png\`（若出现打卡成功后的广告弹窗，可先保存截图或点击弹窗右上角关闭按钮后再截图确保打卡时间清晰可见）；
        4. 返回钉钉消息列表或通知栏，通过截图或 \`uiautomator dump\` 确认收到“打卡·成功”通知进行独立复核；
        5. 收尾清理（必须在截图保存和复核全部完成后执行，严禁在保存截图前熄屏；若打卡中途判定失败，只要打开过钉钉也必须执行此清理）：
           a. 强制退出钉钉：\`adb -s $SERIAL shell am force-stop com.alibaba.android.rimet\`
           b. 熄屏：\`adb -s $SERIAL shell input keyevent KEYCODE_SLEEP\`
           c. 用 \`adb -s $SERIAL shell dumpsys window | grep -i mDreamingLockscreen\` 确认手机已熄屏且钉钉已不在前台。

        ## 五、Matrix 私聊汇报（必须执行）
        通过挂载的 Matrix MCP 工具（写入 \`xd://mcp__matrix_*\`）向 \`@chn:chn.moe\` 发送私聊汇报：
        1. 先调用 \`xd://mcp__matrix_sync\`（参数 \`{}\`）同步状态，再调用 \`xd://mcp__matrix_create_dm\`（参数 \`{"user_id": "@chn:chn.moe"}\`）获取复用的私聊 \`room_id\`。
        2. 若打卡成功：
           - 调用 \`xd://mcp__matrix_send_file\` 将 \`$TMP_DIR/punch_success.png\` 发送到该 \`room_id\`；
           - 调用 \`xd://mcp__matrix_send_message\` 发送打卡成功说明（包含打卡时段与复核状态）。
        3. 若打卡失败（包括 ADB 未连接、定位超范围或页面异常）：
           - 若现场有异常截图，调用 \`xd://mcp__matrix_send_file\` 发送现场截图；
           - 调用 \`xd://mcp__matrix_send_message\` 详细说明失败原因与当时的屏幕状态。
        EOF
        )

        omp -p \
          --no-session \
          --cwd "$TMP_DIR" \
          --model "cliproxyapi/gemini-3.8-flash" \
          --no-pty \
          --no-lsp \
          --no-rules \
          --no-extensions \
          --no-skills \
          "$PROMPT"
      '';
    };

    systemd.timers.dingtalk-punch = {
      description = "DingTalk Auto Punch-in Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon..Sat *-*-* 07,11,13,17:00:00";
        Persistent = true;
      };
    };
  };
}
