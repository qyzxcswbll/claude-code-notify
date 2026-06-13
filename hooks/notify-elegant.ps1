param([string]$Event = 'stop')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== 读取配置 =====
$configPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'
$theme = "holo"
$radius = 14
$iconProj = "⚙"
$iconDone = "✨"
$iconWait = "⚙"
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.theme) { $theme = $cfg.theme }
        if ($cfg.params.radius) { $radius = [int]$cfg.params.radius }
        if ($cfg.icons.project) { $iconProj = $cfg.icons.project }
        if ($cfg.icons.done) { $iconDone = $cfg.icons.done }
        if ($cfg.icons.wait) { $iconWait = $cfg.icons.wait }
    } catch {}
}

# ===== 主题定义 =====
$themes = @{
    holo = @{ bg = [System.Drawing.Color]::FromArgb(255,26,10,48); bd = [System.Drawing.Color]::FromArgb(200,139,92,246); iconBg = [System.Drawing.Color]::FromArgb(255,139,92,246); titleColor = [System.Drawing.Color]::FromArgb(255,221,214,254); metaColor = [System.Drawing.Color]::FromArgb(255,167,139,250); bodyColor = [System.Drawing.Color]::FromArgb(255,232,224,248); btnColor = [System.Drawing.Color]::FromArgb(255,139,92,246); ghostColor = [System.Drawing.Color]::FromArgb(255,167,139,250); strip1 = [System.Drawing.Color]::FromArgb(255,45,16,96); strip2 = [System.Drawing.Color]::FromArgb(255,26,10,48) }
    cyber = @{ bg = [System.Drawing.Color]::FromArgb(255,10,10,10); bd = [System.Drawing.Color]::FromArgb(255,0,255,65); iconBg = [System.Drawing.Color]::FromArgb(255,0,255,65); titleColor = [System.Drawing.Color]::FromArgb(255,0,255,65); metaColor = [System.Drawing.Color]::FromArgb(255,0,204,51); bodyColor = [System.Drawing.Color]::FromArgb(255,160,255,160); btnColor = [System.Drawing.Color]::FromArgb(255,0,255,65); ghostColor = [System.Drawing.Color]::FromArgb(255,0,255,65); strip1 = [System.Drawing.Color]::FromArgb(255,0,34,0); strip2 = [System.Drawing.Color]::FromArgb(255,0,10,0) }
    kawaii = @{ bg = [System.Drawing.Color]::FromArgb(255,255,240,246); bd = [System.Drawing.Color]::FromArgb(255,244,114,182); iconBg = [System.Drawing.Color]::FromArgb(255,236,72,153); titleColor = [System.Drawing.Color]::FromArgb(255,190,24,93); metaColor = [System.Drawing.Color]::FromArgb(255,244,114,182); bodyColor = [System.Drawing.Color]::FromArgb(255,131,24,67); btnColor = [System.Drawing.Color]::FromArgb(255,236,72,153); ghostColor = [System.Drawing.Color]::FromArgb(255,236,72,153); strip1 = [System.Drawing.Color]::FromArgb(255,252,231,243); strip2 = [System.Drawing.Color]::FromArgb(255,255,240,246) }
    dark = @{ bg = [System.Drawing.Color]::FromArgb(255,30,30,46); bd = [System.Drawing.Color]::FromArgb(255,69,71,90); iconBg = [System.Drawing.Color]::FromArgb(255,203,166,247); titleColor = [System.Drawing.Color]::FromArgb(255,205,214,244); metaColor = [System.Drawing.Color]::FromArgb(255,166,173,200); bodyColor = [System.Drawing.Color]::FromArgb(255,205,214,244); btnColor = [System.Drawing.Color]::FromArgb(255,88,91,112); ghostColor = [System.Drawing.Color]::FromArgb(255,166,173,200); strip1 = [System.Drawing.Color]::FromArgb(255,24,24,37); strip2 = [System.Drawing.Color]::FromArgb(255,17,17,27) }
    wa = @{ bg = [System.Drawing.Color]::FromArgb(255,250,245,235); bd = [System.Drawing.Color]::FromArgb(255,196,168,130); iconBg = [System.Drawing.Color]::FromArgb(255,196,168,130); titleColor = [System.Drawing.Color]::FromArgb(255,61,46,30); metaColor = [System.Drawing.Color]::FromArgb(255,166,124,82); bodyColor = [System.Drawing.Color]::FromArgb(255,61,46,30); btnColor = [System.Drawing.Color]::FromArgb(255,166,124,82); ghostColor = [System.Drawing.Color]::FromArgb(255,166,124,82); strip1 = [System.Drawing.Color]::FromArgb(255,232,220,204); strip2 = [System.Drawing.Color]::FromArgb(255,245,240,232) }
}
$t = $themes[$theme]; if (-not $t) { $t = $themes["holo"] }

# ===== 窗口创建 =====
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code"
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.FormBorderStyle = 'None'
$form.BackColor = $t.bg
$form.Opacity = 0

$fw = 380; $fh = 200

$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$form.Location = New-Object System.Drawing.Point(($screen.WorkingArea.Right - $fw - 16), ($screen.WorkingArea.Bottom - $fh - 16))
$form.Size = New-Object System.Drawing.Size($fw, $fh)

# 圆角
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc(0,0,$radius*2,$radius*2,180,90)
$path.AddArc($fw-$radius*2-1,0,$radius*2,$radius*2,270,90)
$path.AddArc($fw-$radius*2-1,$fh-$radius*2-1,$radius*2,$radius*2,0,90)
$path.AddArc(0,$fh-$radius*2-1,$radius*2,$radius*2,90,90)
$path.CloseFigure()
$form.Region = [System.Drawing.Region]::new($path)

# ===== 自绘 =====
$form.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $fw2 = 380; $fh2 = 200

    # 角色区（左栏 100px）
    $stripBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0,0,100,$fh2)),
        $t.strip1, $t.strip2, 90)
    $g.FillRectangle($stripBrush, 0, 0, 100, $fh2)

    # 角色图
    $charPath = Join-Path $env:USERPROFILE '.claude\themes\character.png'
    if (Test-Path $charPath) {
        $img = [System.Drawing.Image]::FromFile($charPath)
        $g.DrawImage($img, 0, 0, 100, $fh2)
    }

    $x0 = 114; $y0 = 16

    # 项目名图标 + 标题
    $iconFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $g.DrawString($iconProj, $iconFont, [System.Drawing.Brushes]::White, $x0, $y0)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $g.DrawString("claude-code-notify", $titleFont, [System.Drawing.Brushes]::White, ($x0+26), ($y0+2))

    # 会话名
    $metaFont = New-Object System.Drawing.Font("Segoe UI", 9)
    $metaBrush = New-Object System.Drawing.SolidBrush($t.metaColor)
    $g.DrawString("💬 重构代码", $metaFont, $metaBrush, $x0, ($y0+24))

    # 分割线
    $divPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60,$t.bd.R,$t.bd.G,$t.bd.B))
    $g.DrawLine($divPen, $x0, ($y0+40), ($fw2-16), ($y0+40))

    # 主内容
    $bodyFont = New-Object System.Drawing.Font("Segoe UI", 11)
    $bodyBrush = New-Object System.Drawing.SolidBrush($t.bodyColor)
    $g.DrawString("$iconDone 搞定了：你好", $bodyFont, $bodyBrush, $x0, ($y0+50))

    # 副内容
    $subFont = New-Object System.Drawing.Font("Segoe UI", 9)
    $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180,$t.bodyColor.R,$t.bodyColor.G,$t.bodyColor.B))
    $g.DrawString("$iconWait 后续待办清单", $subFont, $subBrush, $x0, ($y0+72))

    # 进度条
    $barBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,$t.bodyColor.R,$t.bodyColor.G,$t.bodyColor.B))
    $g.FillRectangle($barBg, $x0, ($y0+94), 140, 4)
    $barFill = New-Object System.Drawing.SolidBrush($t.btnColor)
    $g.FillRectangle($barFill, $x0, ($y0+94), 100, 4)
    $g.DrawString("78%", $subFont, $subBrush, ($x0+146), ($y0+90))

    # 按钮
    $btnY = $y0 + 110
    $btnH = 28
    $btnW1 = (($fw2 - 16 - $x0) / 2) - 4
    $btnW2 = (($fw2 - 16 - $x0) / 2) - 4

    $btn1Rect = New-Object System.Drawing.Rectangle($x0, $btnY, $btnW1, $btnH)
    $btn2Rect = New-Object System.Drawing.Rectangle(($x0 + $btnW1 + 8), $btnY, $btnW2, $btnH)

    # 忽略按钮（幽灵）
    $ghostPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100,$t.ghostColor.R,$t.ghostColor.G,$t.ghostColor.B))
    $g.DrawRectangle($ghostPen, $btn1Rect.X, $btn1Rect.Y, $btn1Rect.Width, $btn1Rect.Height)
    $gf = New-Object System.Drawing.StringFormat
    $gf.Alignment = 'Center'
    $gf.LineAlignment = 'Center'
    $btn1RectF = New-Object System.Drawing.RectangleF($btn1Rect.X, $btn1Rect.Y, $btn1Rect.Width, $btn1Rect.Height)
    $g.DrawString("忽略", $subFont, $metaBrush, $btn1RectF, $gf)

    # 查看详情按钮（实心）
    $btnBrush = New-Object System.Drawing.SolidBrush($t.btnColor)
    $g.FillRectangle($btnBrush, $btn2Rect)
    $btnTextColor = if ($theme -eq "cyber") { [System.Drawing.Brushes]::Black } else { [System.Drawing.Brushes]::White }
    $btn2RectF = New-Object System.Drawing.RectangleF($btn2Rect.X, $btn2Rect.Y, $btn2Rect.Width, $btn2Rect.Height)
    $g.DrawString("查看详情", $subFont, $btnTextColor, $btn2RectF, $gf)
})

# ===== 渐入动画 =====
$fadeInTimer = New-Object System.Windows.Forms.Timer
$fadeInTimer.Interval = 16
$fadeInTimer.Add_Tick({
    if ($form.Opacity -lt 1) { $form.Opacity = [Math]::Min($form.Opacity + 0.06, 1) }
    else { $fadeInTimer.Stop() }
})
$fadeInTimer.Start()

# ===== 点击关闭 =====
$form.Add_Click({ $form.Close() })

# ===== 自动关闭 =====
$duration = 5000; $elapsed = 0
$lifeTimer = New-Object System.Windows.Forms.Timer
$lifeTimer.Interval = 50
$lifeTimer.Add_Tick({
    $script:elapsed += 50
    if ($script:elapsed -ge $duration -and $form.Opacity -gt 0) {
        $form.Opacity = [Math]::Max($form.Opacity - 0.05, 0)
        if ($form.Opacity -le 0) { $lifeTimer.Stop(); $form.Close() }
    }
})
$lifeTimer.Start()

[System.Windows.Forms.Application]::Run($form)
