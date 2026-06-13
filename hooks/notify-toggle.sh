#!/bin/bash
FLAG="$HOME/.claude/.notifymute"
if [ -f "$FLAG" ]; then
    rm "$FLAG"
    BODY="通知已开启 🔔"
else
    touch "$FLAG"
    BODY="通知已关闭 🔕"
fi

# 使用环境变量传递，杜绝转义问题
export CLAUDE_TOGGLE_BODY="$BODY"
osascript -e 'display notification (system attribute "CLAUDE_TOGGLE_BODY") with title "Claude Code 通知"'
