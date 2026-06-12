---
name: notify-setup
description: 一键配置 Claude Code 桌面通知（Windows 弹窗 / macOS 通知中心）
metadata:
  agents:
    - claude-code
---

# Claude Code Notify Setup

## 概述

安装后执行 `/notify-setup`，自动完成以下配置：

- 任务完成时弹出通知，显示你最后一条输入
- 需要你回应时弹出通知

支持 Windows 10/11 Toast 通知和 macOS 通知中心。零额外依赖。

## 执行步骤

### 1. 检测操作系统

判断当前操作系统。仅支持 Windows 和 macOS，Linux 不支持则提示退出。

### 2. 创建通知脚本

#### Windows

写入 `~/.claude/notify.ps1`（必须 `.ps1` 扩展名，PowerShell 需要）。

**编码要求**：先写 UTF-8 内容，然后执行 `[System.IO.File]::WriteAllText(path, content, [System.Text.Encoding]::UTF8)` 方法写入文件以保证 UTF-8 BOM。不使用 `Out-File` 或 `Set-Content`（它们默认用 UTF-16 或无 BOM）。

```powershell
param([string]$Event = 'stop')

$titleBase = "Claude Code"

# 从 stdin 原始文本中提取 transcript_path
$transcriptPath = ""
try {
    if ([Console]::IsInputRedirected) {
        $raw = [Console]::In.ReadToEnd()
        if ($raw -match '"transcript_path"\s*:\s*"([^"]+)"') {
            $transcriptPath = $matches[1] -replace '\\\\', '\'
        }
    }
} catch {}

# 从会话文件提取项目名和最后一条用户消息
$projectName = ""
$context = ""
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        # 从 transcript 头部提取项目名（cwd 字段在第一条 user 消息中）
        $headLines = Get-Content $transcriptPath -Encoding UTF8 -TotalCount 20
        foreach ($line in $headLines) {
            if ($line -match '"cwd"\s*:\s*"([^"]+)"') {
                $cwd = $matches[1] -replace '\\\\', '\'
                $projectName = Split-Path $cwd -Leaf
                break
            }
        }
    } catch {}

    try {
        # 从 transcript 尾部提取最后一条用户消息
        $tailLines = Get-Content $transcriptPath -Encoding UTF8 -Tail 100
        for ($i = $tailLines.Length - 1; $i -ge 0; $i--) {
            if ($tailLines[$i] -match '"role"\s*:\s*"user"') {
                try {
                    $msg = $lines[$i] | ConvertFrom-Json
                    $content = $msg.message.content
                    if ($content -is [array]) {
                        $content = ($content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
                    }
                    if ($content) {
                        $context = ($content -replace "`n", " ").Trim()
                        if ($context.Length -gt 60) { $context = $context.Substring(0, 57) + "..." }
                    }
                } catch {}
                break
            }
        }
    } catch {}
}

# 标题附加项目名
$title = if ($projectName) { "$titleBase - $projectName" } else { $titleBase }

$body = if ($Event -eq 'stop') {
    if ($context) { "完成: $context" } else { "任务完成" }
} else {
    if ($context) { $context } else { "需要你回应" }
}

# Windows Toast（优先）
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast duration=""short""><visual><binding template=""ToastText02""><text id=""1"">$title</text><text id=""2"">$body</text></binding></visual></toast>"
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
    exit 0
} catch {}

# msg 弹窗（兜底）
try { msg * "Claude Code: $body" 2>$null } catch {}
```

#### macOS

写入 `~/.claude/notify`（无扩展名）。

```bash
#!/bin/bash
EVENT=${1:-stop}

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
```

写完后执行 `chmod +x ~/.claude/notify`。

### 3. 配置 hooks

读取 `~/.claude/settings.json`。

- 如果文件不存在则创建设置文件
- 如果已存在 `hooks` 字段，合并 `Stop` 和 `Notification` 事件（保留已有配置）
- 如果没有 `hooks` 字段则添加

Windows hooks 配置（使用 `%USERPROFILE%` 环境变量避免路径硬编码）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\notify.ps1\" -Event stop",
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\notify.ps1\" -Event notification",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

macOS hooks 配置：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/notify stop",
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/notify notification",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### 4. 验证

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\notify.ps1" -Event stop
```

macOS：

```bash
echo '{}' | bash ~/.claude/notify stop
```

无报错即成功。告知用户配置完成，之后每次 Claude 完成任务或需要回应时都会弹出通知。

## 注意事项（给 AI 自己看）

- 通知脚本文件创建后不要删，hooks 事件会一直调用它
- Windows 脚本必须 UTF-8 BOM 编码，否则 PowerShell 5.1 解析带中文的脚本会报 `MissingEndCurlyBrace` 错误
- macOS 脚本无需 BOM，普通 UTF-8 即可
- `[Console]::In.ReadToEnd()` 只能消费 stdin 一次，重复调用返回空
- Stop 事件的 stdin 中不含 `transcript_messages` 字段，需通过 `transcript_path` 读 JSONL 文件提取用户消息
- macOS 通知内容需要转义双引号，否则 osascript 解析失败