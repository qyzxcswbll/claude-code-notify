# notify-toggle.ps1 — 双击运行，一键开关 Claude Code 通知
$flagPath = Join-Path $env:USERPROFILE '.claude\.notifymute'
if (Test-Path $flagPath) {
    Remove-Item $flagPath -Force
    $body = "通知已开启 🔔"
} else {
    New-Item $flagPath -ItemType File -Force | Out-Null
    $body = "通知已关闭 🔕"
}

# XML 转义函数
function Escape-Xml([string]$text) {
    if (-not $text) { return "" }
    return [System.Security.SecurityElement]::Escape($text)
}

$bodyEscaped = Escape-Xml $body

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast><visual><binding template=""ToastText02""><text id=""1"">Claude Code 通知</text><text id=""2"">$bodyEscaped</text></binding></visual></toast>"
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
} catch {
    # 静默失败，不弹窗也不阻塞
}
