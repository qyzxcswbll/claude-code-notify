#!/bin/bash
EVENT=${1:-stop}

# 开关检测——存在 ~/.claude/.notifymute 文件就不弹窗
if [ -f "$HOME/.claude/.notifymute" ]; then exit 0; fi

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | grep -o '"transcript_path" *: *"[^"]*"' | sed 's/"transcript_path" *: *"\(.*\)"$/\1/' | sed 's/\\\\/\//g')

PROJECT_NAME=""
SESSION_NAME=""
CONTEXT=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # 从 transcript 头部提取项目名和会话名（前 5 字）
    META=$(python3 -c "
import json, sys
path = '$TRANSCRIPT_PATH'
project = ''
session = ''
with open(path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if i >= 20:
            break
        try:
            msg = json.loads(line)
            msg_content = msg.get('message', {}) if isinstance(msg, dict) else {}
            if not project and msg.get('cwd'):
                cwd = msg.get('cwd')
                project = cwd.rstrip('\\\\').split('\\\\')[-1]
            if not session and msg_content.get('role') == 'user':
                content = msg_content.get('content', '')
                if isinstance(content, list):
                    texts = [c['text'] for c in content if c.get('type') == 'text']
                    content = texts[0] if texts else ''
                session = content.replace(chr(10), ' ').replace(chr(13), '').strip()[:5]
        except:
            pass
        if project and session:
            break
print(json.dumps({'project': project, 'session': session}))
" 2>/dev/null)

    PROJECT_NAME=$(echo "$META" | python3 -c "import sys,json; print(json.load(sys.stdin).get('project',''))" 2>/dev/null)
    SESSION_NAME=$(echo "$META" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session',''))" 2>/dev/null)

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

# 标题：项目名（第一行）
if [ -n "$PROJECT_NAME" ]; then
    TITLE="$PROJECT_NAME"
else
    TITLE="Claude Code"
fi

# 内容（macOS 只有两行，副标题和内容合并）
if [ "$EVENT" = "stop" ]; then
    if [ -n "$CONTEXT" ]; then
        BODY="✨ 搞定了: $CONTEXT"
    else
        BODY="✨ 搞定了~"
    fi
else
    if [ -n "$CONTEXT" ]; then
        BODY="💬 需要你瞅一眼: $CONTEXT"
    else
        BODY="💬 需要你瞅一眼"
    fi
fi

# mac 版副标题放在标题行：项目名 💎 会话名
if [ -n "$SESSION_NAME" ]; then
    TITLE="$TITLE ⚙️ $SESSION_NAME"
fi

BODY_ESC=$(echo "$BODY" | sed 's/"/\\"/g' | tr '\n' ' ')
TITLE_ESC=$(echo "$TITLE" | sed 's/"/\\"/g' | tr '\n' ' ')
osascript -e "display notification \"$BODY_ESC\" with title \"$TITLE_ESC\""
