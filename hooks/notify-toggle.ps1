# notify-toggle.ps1 — 双击运行，一键开关 Claude Code 通知
# 第一次运行 → 关通知；再运行一次 → 开通知，以此类推

$flagPath = Join-Path $env:USERPROFILE '.claude\.notifymute'

if (Test-Path $flagPath) {
    Remove-Item $flagPath -Force
    $title = "Claude Code 通知"
    $body = "通知已开启 🔔"
    $state = "on"
} else {
    New-Item $flagPath -ItemType File -Force | Out-Null
    $title = "Claude Code 通知"
    $body = "通知已关闭 🔕"
    $state = "off"
}

# 弹窗反馈
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $toastXml = "<?xml version=""1.0"" encoding=""utf-8""?><toast><visual><binding template=""ToastText02""><text id=""1"">$title</text><text id=""2"">$body</text></binding></visual></toast>"
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
} catch {
    msg * "$title $body"
}
