#!/bin/bash
EVENT=${1:-stop}

# 开关检测——存在 ~/.claude/.notifymute 文件就不弹窗
if [ -f "$HOME/.claude/.notifymute" ]; then exit 0; fi

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | grep -o '"transcript_path" *: *"[^"]*"' | sed 's/"transcript_path" *: *"\(.*\)"$/\1/' | sed 's/\\\\/\//g')

PROJECT_NAME=""
CONTEXT=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # 从 transcript 头部提取项目名
    PROJECT_NAME=$(python3 -c "
import json, sys
path = '$TRANSCRIPT_PATH'
with open(path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if i >= 20:
            break
        try:
            msg = json.loads(line)
            msg_content = msg.get('message', {}) if isinstance(msg, dict) else {}
            if msg_content.get('cwd'):
                cwd = msg_content['cwd']
                name = cwd.rstrip('\\\\').split('\\\\')[-1]
                print(name, end='')
                break
        except:
            pass
" 2>/dev/null)

    # 从 transcript 尾部提取最后一条用户消息
    CONTEXT=$(python3 -c "
import json, sys
path = '$TRANSCRIPT_PATH'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for line in reversed(lines[-100:]):
        try:
            msg = json.loads(line)
            if msg.get('message', {}).get('role') != 'user':
                continue
            content = msg['message'].get('content', '')
            if isinstance(content, list):
                texts = [c['text'] for c in content if c.get('type') == 'text']
                content = texts[0] if texts else ''
            content = content.replace(chr(10), ' ').replace(chr(13), '').strip()
            if len(content) > 60:
                content = content[:57] + '...'
            print(content, end='')
            break
        except:
            pass
" 2>/dev/null)
fi

TITLE="Claude Code"
if [ -n "$PROJECT_NAME" ]; then
    TITLE="Claude Code - $PROJECT_NAME"
fi

if [ "$EVENT" = "stop" ]; then
    if [ -n "$CONTEXT" ]; then
        BODY="完成: $CONTEXT"
    else
        BODY="任务完成"
    fi
else
    if [ -n "$CONTEXT" ]; then
        BODY="$CONTEXT"
    else
        BODY="需要你回应"
    fi
fi

BODY_ESC=$(echo "$BODY" | sed 's/"/\\"/g' | tr '\n' ' ')
TITLE_ESC=$(echo "$TITLE" | sed 's/"/\\"/g' | tr '\n' ' ')
osascript -e "display notification \"$BODY_ESC\" with title \"$TITLE_ESC\""
