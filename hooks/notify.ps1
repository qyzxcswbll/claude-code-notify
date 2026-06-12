param([string]$Event = 'stop')

# 开关检测——存在 ~/.claude/.notifymute 文件就不弹窗
if (Test-Path (Join-Path $env:USERPROFILE '.claude\.notifymute')) { exit 0 }

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

$projectName = ""
$sessionName = ""
$context = ""

if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $headLines = Get-Content $transcriptPath -Encoding UTF8 -TotalCount 20
        foreach ($line in $headLines) {
            # 提取项目名
            if (-not $projectName -and ($line -match '"cwd"\s*:\s*"([^"]+)"')) {
                $cwd = $matches[1] -replace '\\\\', '\'
                $projectName = Split-Path $cwd -Leaf
            }
            # 提取会话名（第一条用户消息的前 20 字）
            if (-not $sessionName -and ($line -match '"role"\s*:\s*"user"')) {
                try {
                    $msg = $line | ConvertFrom-Json
                    $content = $msg.message.content
                    if ($content -is [array]) {
                        $content = ($content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
                    }
                    if ($content) {
                        $sessionName = ($content -replace "`n", " ").Trim()
                        if ($sessionName.Length -gt 20) { $sessionName = $sessionName.Substring(0, 17) + "..." }
                    }
                } catch {}
            }
            if ($projectName -and $sessionName) { break }
        }
    } catch {}

    try {
        # 从 transcript 尾部提取最后一条用户消息
        $tailLines = Get-Content $transcriptPath -Encoding UTF8 -Tail 100
        for ($i = $tailLines.Length - 1; $i -ge 0; $i--) {
            if ($tailLines[$i] -match '"role"\s*:\s*"user"') {
                try {
                    $msg = $tailLines[$i] | ConvertFrom-Json
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

# 标题：项目名 - 会话描述（去掉重复的 "Claude Code"）
if ($projectName -and $sessionName) {
    $title = "$projectName - $sessionName"
} elseif ($projectName) {
    $title = $projectName
} else {
    $title = "Claude Code"
}

# 事件类型与显示文案
$isStop = ($Event -eq 'stop')
if ($isStop) {
    $body = if ($context) { "✨ 搞定了: $context" } else { "✨ 搞定了~" }
} else {
    $body = if ($context) { "💬 需要你瞅一眼: $context" } else { "💬 需要你瞅一眼" }
}

# Windows Toast（优先）
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast><visual><binding template=""ToastText02""><text id=""1"">$title</text><text id=""2"">$body</text></binding></visual></toast>"
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
    exit 0
} catch {}

# msg 弹窗（兜底）
try { msg * "Claude Code: $body" 2>$null } catch {}
