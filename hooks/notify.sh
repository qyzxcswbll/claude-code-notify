#!/bin/bash
EVENT=${1:-stop}

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | grep -o '"transcript_path" *: *"[^"]*"' | sed 's/"transcript_path" *: *"\(.*\)"$/\1/' | sed 's/\\\\/\//g')

CONTEXT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
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
osascript -e "display notification \"$BODY_ESC\" with title \"Claude Code\""
