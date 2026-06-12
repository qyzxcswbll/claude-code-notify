param([string]$Event = 'stop')

$title = "Claude Code"

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

# 从会话文件提取最后一条用户消息
$context = ""
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $lines = Get-Content $transcriptPath -Encoding UTF8 -Tail 100
        for ($i = $lines.Length - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match '"role"\s*:\s*"user"') {
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
