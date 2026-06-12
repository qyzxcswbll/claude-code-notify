#!/bin/bash
# notify-toggle.sh — 双击运行，一键开关 Claude Code 通知

FLAG="$HOME/.claude/.notifymute"

if [ -f "$FLAG" ]; then
    rm "$FLAG"
    TITLE="Claude Code 通知"
    BODY="通知已开启 🔔"
else
    touch "$FLAG"
    TITLE="Claude Code 通知"
    BODY="通知已关闭 🔕"
fi

osascript -e "display notification \"$BODY\" with title \"$TITLE\""
