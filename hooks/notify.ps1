param([string]$Event = 'stop')

# 开关检测——存在 ~/.claude/.notifymute 文件就不弹窗
if (Test-Path (Join-Path $env:USERPROFILE '.claude\.notifymute')) { exit 0 }

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
