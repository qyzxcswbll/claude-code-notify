param([string]$Event = 'stop')

# 开关检测——存在 ~/.claude/.notifymute 文件就不弹窗
if (Test-Path (Join-Path $env:USERPROFILE '.claude\.notifymute')) { exit 0 }

# 模式检测——优雅弹窗分流
$notifyModePath = Join-Path $env:USERPROFILE '.claude\notify-mode'
if (Test-Path $notifyModePath) {
    $mode = (Get-Content $notifyModePath -Encoding UTF8).Trim().ToLower()
    if ($mode -eq "elegant") {
        $elegantScript = Join-Path $env:USERPROFILE '.claude\notify-elegant.ps1'
        if (Test-Path $elegantScript) {
            & $elegantScript -Event $Event
            exit 0
        }
    }
}

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
            if (-not $projectName -and ($line -match '"cwd"\s*:\s*"([^"]+)"')) {
                $cwd = $matches[1] -replace '\\\\', '\'
                $projectName = Split-Path $cwd -Leaf
            }
            if (-not $sessionName -and ($line -match '"role"\s*:\s*"user"')) {
                try {
                    $msg = $line | ConvertFrom-Json
                    $content = $msg.message.content
                    if ($content -is [array]) { $content = ($content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text }
                    if ($content) {
                        $sessionName = ($content -replace "`n", " ").Trim()
                        if ($sessionName.Length -gt 5) { $sessionName = $sessionName.Substring(0, 5) }
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

# 标题：项目名（第一行）
$title = if ($projectName) { $projectName } else { "Claude Code" }

# 副标题：会话名（第二行，层级感）
$subtitle = if ($sessionName) { "⚙️ $sessionName" } else { "" }

# 内容：第三行
$isStop = ($Event -eq 'stop')
if ($isStop) {
    $body = if ($context) { "✨ 搞定了: $context" } else { "✨ 搞定了~" }
} else {
    $body = if ($context) { "💬 需要你瞅一眼: $context" } else { "💬 需要你瞅一眼" }
}

# Windows Toast（三行层级）
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    if ($subtitle) {
        $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast><visual><binding template=""ToastText04""><text id=""1"">$title</text><text id=""2"">$subtitle</text><text id=""3"">$body</text></binding></visual></toast>"
    } else {
        $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast><visual><binding template=""ToastText02""><text id=""1"">$title</text><text id=""2"">$body</text></binding></visual></toast>"
    }
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
    exit 0
} catch {}

# msg 弹窗（兜底）
try { msg * "Claude Code: $body" 2>$null } catch {}
