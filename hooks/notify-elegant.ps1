param(
    [string]$Event = 'stop',
    [string]$ProjectName = "",
    [string]$SessionName = "",
    [string]$Context = ""
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ===== 读取配置 =====
$configPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'
$theme = "holo"
$radius = 14
$duration = 5
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.theme) { $theme = $cfg.theme }
        if ($cfg.params.radius) { $radius = [int]$cfg.params.radius }
        if ($cfg.params.duration) { $duration = [int]$cfg.params.duration }
    } catch {}
}

# ===== 主题定义 =====
$themes = @{
    holo = @{ bg = "#1A0A30"; bg2 = "#181029"; bd = "#8B5CF6"; strip1 = "#2D1060"; strip2 = "#1A0A30"; titleColor = "#DDD6FE"; metaColor = "#A78BFA"; bodyColor = "#E8E0F8"; iconBg = "#8B5CF6"; ghostColor = "#A78BFA" }
    cyber = @{ bg = "#0A0A0A"; bg2 = "#0A0A0A"; bd = "#00FF41"; strip1 = "#002200"; strip2 = "#000A00"; titleColor = "#00FF41"; metaColor = "#00CC33"; bodyColor = "#A0FFA0"; iconBg = "#00FF41"; ghostColor = "#00FF41" }
    kawaii = @{ bg = "#FFF0F6"; bg2 = "#F9E4EE"; bd = "#F472B6"; strip1 = "#FCE7F3"; strip2 = "#FFF0F6"; titleColor = "#BE185D"; metaColor = "#F472B6"; bodyColor = "#831843"; iconBg = "#EC4899"; ghostColor = "#EC4899" }
    dark = @{ bg = "#1E1E2E"; bg2 = "#171726"; bd = "#45475A"; strip1 = "#181825"; strip2 = "#11111B"; titleColor = "#CDD6F4"; metaColor = "#A6ADC8"; bodyColor = "#CDD6F4"; iconBg = "#CBA6F7"; ghostColor = "#A6ADC8" }
    wa = @{ bg = "#FAF5EB"; bg2 = "#F2ECE0"; bd = "#C4A882"; strip1 = "#E8DCCC"; strip2 = "#F5F0E8"; titleColor = "#3D2E1E"; metaColor = "#A67C52"; bodyColor = "#3D2E1E"; iconBg = "#C4A882"; ghostColor = "#A67C52" }
    furina = @{ bg = "#F4FAFF"; bg2 = "#E8F2FC"; bd = "#96C8EB"; strip1 = "#FAF8F4"; strip2 = "#C6E2FA"; titleColor = "#1E3A5F"; metaColor = "#6491C3"; bodyColor = "#3A5478"; iconBg = "#60A5FA"; ghostColor = "#82AAD2" }
}
$t = $themes[$theme]; if (-not $t) { $t = $themes["holo"] }

# 图标路径
$iconDir = Join-Path $env:USERPROFILE '.claude\themes\icons'
$charPath = Join-Path $env:USERPROFILE '.claude\themes\character.png'

# ===== WPF 弹窗 =====
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Media.Effects;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;

public static class NotifyWindow
{
    private static Color C(string hex)
    {
        return (Color)ColorConverter.ConvertFromString(hex);
    }

    private static Image MakeIcon(string path, double w, double h, Thickness m)
    {
        if (String.IsNullOrEmpty(path) || !File.Exists(path)) return null;
        Image img = new Image();
        img.Width = w; img.Height = h; img.Margin = m;
        img.Source = new BitmapImage(new Uri(path, UriKind.Absolute));
        return img;
    }

    private static string LoadArg(string s)
    {
        if (s == null) return "";
        return s;
    }

    public static void ShowBlocking(
        string projectName, string sessionName, string context, bool isStop,
        string charPath, string iconDir,
        string bg, string bg2, string strip1, string strip2,
        string titleColor, string metaColor, string bodyColor, string iconBg, string ghostColor, string bdColor,
        int radius, int durationMs)
    {
        projectName = LoadArg(projectName);
        sessionName = LoadArg(sessionName);
        context = LoadArg(context);

        Window win = new Window();
        win.AllowsTransparency = true;
        win.Background = Brushes.Transparent;
        win.WindowStyle = WindowStyle.None;
        win.Topmost = true;
        win.ShowInTaskbar = false;
        win.ResizeMode = ResizeMode.NoResize;
        win.Width = 448;
        win.Height = 268;
        win.Opacity = 0;

        Rect wa = SystemParameters.WorkArea;
        win.Left = wa.Right - win.Width - 8;
        win.Top = wa.Bottom - win.Height - 8;

        // 主体卡片（含阴影留白）
        Border body = new Border();
        body.CornerRadius = new CornerRadius(radius);
        body.Margin = new Thickness(24);
        body.Background = new LinearGradientBrush(C(bg), C(bg2), 90);
        body.BorderBrush = new SolidColorBrush(Color.FromArgb(150, C(bdColor).R, C(bdColor).G, C(bdColor).B));
        body.BorderThickness = new Thickness(1);
        body.Effect = new DropShadowEffect();
        ((DropShadowEffect)body.Effect).BlurRadius = 20;
        ((DropShadowEffect)body.Effect).ShadowDepth = 3;
        ((DropShadowEffect)body.Effect).Direction = 270;
        ((DropShadowEffect)body.Effect).Opacity = 0.45;
        ((DropShadowEffect)body.Effect).Color = Color.FromArgb(90, 15, 35, 85);

        Grid grid = new Grid();
        ColumnDefinition colL = new ColumnDefinition();
        colL.Width = new GridLength(100);
        ColumnDefinition colR = new ColumnDefinition();
        colR.Width = new GridLength(1, GridUnitType.Star);
        grid.ColumnDefinitions.Add(colL);
        grid.ColumnDefinitions.Add(colR);
        body.Child = grid;

        // 左栏：渐变底 + 立绘（ImageBrush 随 Border 圆角裁剪）
        Grid left = new Grid();
        Grid.SetColumn(left, 0);
        Border gradBorder = new Border();
        gradBorder.CornerRadius = new CornerRadius(radius, 0, 0, radius);
        gradBorder.Background = new LinearGradientBrush(C(strip1), C(strip2), 90);
        left.Children.Add(gradBorder);
        if (!String.IsNullOrEmpty(charPath) && File.Exists(charPath))
        {
            Border imgBorder = new Border();
            imgBorder.CornerRadius = new CornerRadius(radius, 0, 0, radius);
            ImageBrush ib = new ImageBrush();
            ib.ImageSource = new BitmapImage(new Uri(charPath, UriKind.Absolute));
            ib.Stretch = Stretch.Fill;
            imgBorder.Background = ib;
            left.Children.Add(imgBorder);
        }
        grid.Children.Add(left);

        // 右栏内容
        StackPanel right = new StackPanel();
        right.Margin = new Thickness(14, 20, 14, 14);
        Grid.SetColumn(right, 1);
        grid.Children.Add(right);

        // 标题行：图标 + 项目名
        StackPanel titleRow = new StackPanel();
        titleRow.Orientation = Orientation.Horizontal;
        Border gearBg = new Border();
        gearBg.Width = 22; gearBg.Height = 22;
        gearBg.CornerRadius = new CornerRadius(4);
        gearBg.Background = new SolidColorBrush(C(iconBg));
        gearBg.VerticalAlignment = VerticalAlignment.Center;
        Image gearImg = MakeIcon(System.IO.Path.Combine(iconDir, "gear.png"), 18, 18, new Thickness(2));
        if (gearImg != null) gearBg.Child = gearImg;
        titleRow.Children.Add(gearBg);
        TextBlock title = new TextBlock();
        title.Text = String.IsNullOrEmpty(projectName) ? "Claude Code" : projectName;
        title.FontSize = 16;
        title.FontWeight = FontWeights.Bold;
        title.Foreground = new SolidColorBrush(C(titleColor));
        title.Margin = new Thickness(8, 0, 0, 0);
        title.VerticalAlignment = VerticalAlignment.Center;
        title.TextTrimming = TextTrimming.CharacterEllipsis;
        titleRow.Children.Add(title);
        right.Children.Add(titleRow);

        // 会话行
        if (!String.IsNullOrEmpty(sessionName))
        {
            StackPanel sessRow = new StackPanel();
            sessRow.Orientation = Orientation.Horizontal;
            sessRow.Margin = new Thickness(0, 12, 0, 0);
            Image chatImg = MakeIcon(System.IO.Path.Combine(iconDir, "chat.png"), 16, 16, new Thickness(1, 2, 5, 0));
            if (chatImg != null) sessRow.Children.Add(chatImg);
            TextBlock sess = new TextBlock();
            sess.Text = sessionName;
            sess.FontSize = 10;
            sess.Foreground = new SolidColorBrush(C(metaColor));
            sess.VerticalAlignment = VerticalAlignment.Center;
            sess.TextTrimming = TextTrimming.CharacterEllipsis;
            sessRow.Children.Add(sess);
            right.Children.Add(sessRow);
        }

        // 分隔线
        Rectangle sep = new Rectangle();
        sep.Height = 1;
        sep.Margin = new Thickness(0, 10, 0, 0);
        Color bdC = C(bdColor);
        sep.Fill = new SolidColorBrush(Color.FromArgb(120, bdC.R, bdC.G, bdC.B));
        right.Children.Add(sep);

        // 正文行：图标 + 内容
        StackPanel bodyRow = new StackPanel();
        bodyRow.Orientation = Orientation.Horizontal;
        bodyRow.Margin = new Thickness(0, 10, 0, 0);
        Image bodyIcon = MakeIcon(System.IO.Path.Combine(iconDir, isStop ? "check.png" : "bell.png"), 16, 16, new Thickness(1, 2, 6, 0));
        if (bodyIcon != null) bodyRow.Children.Add(bodyIcon);
        TextBlock bodyText = new TextBlock();
        if (isStop)
            bodyText.Text = String.IsNullOrEmpty(context) ? "搞定了~" : "搞定了：" + context;
        else
            bodyText.Text = String.IsNullOrEmpty(context) ? "需要你瞅一眼" : context;
        bodyText.FontSize = 11;
        bodyText.Foreground = new SolidColorBrush(C(bodyColor));
        bodyText.TextWrapping = TextWrapping.Wrap;
        bodyText.MaxWidth = 248;
        bodyText.MaxHeight = 100;
        bodyRow.Children.Add(bodyText);
        right.Children.Add(bodyRow);

        // 忽略按钮（右下角）
        Border btn = new Border();
        Grid.SetColumn(btn, 1);
        btn.HorizontalAlignment = HorizontalAlignment.Right;
        btn.VerticalAlignment = VerticalAlignment.Bottom;
        btn.Margin = new Thickness(0, 0, 16, 14);
        btn.CornerRadius = new CornerRadius(8);
        Color gc = C(ghostColor);
        btn.BorderBrush = new SolidColorBrush(Color.FromArgb(100, gc.R, gc.G, gc.B));
        btn.BorderThickness = new Thickness(1);
        btn.Padding = new Thickness(16, 4, 16, 4);
        TextBlock btnText = new TextBlock();
        btnText.Text = "忽略";
        btnText.FontSize = 10;
        btnText.Foreground = new SolidColorBrush(Color.FromArgb(255, gc.R, gc.G, gc.B));
        btn.Child = btnText;
        grid.Children.Add(btn);

        win.Content = body;

        // 渐入
        DoubleAnimation animIn = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(200));
        animIn.DecelerationRatio = 0.4;
        win.BeginAnimation(Window.OpacityProperty, animIn);

        // 自动关闭
        DispatcherTimer timer = new DispatcherTimer();
        timer.Interval = TimeSpan.FromMilliseconds(durationMs);
        timer.Tick += delegate
        {
            timer.Stop();
            DoubleAnimation animOut = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(450));
            animOut.Completed += delegate { win.Close(); };
            win.BeginAnimation(Window.OpacityProperty, animOut);
        };
        timer.Start();

        // 点击关闭
        win.MouseLeftButtonDown += delegate { win.Close(); };

        win.Closed += delegate
        {
            Dispatcher.CurrentDispatcher.BeginInvokeShutdown(DispatcherPriority.Normal);
        };

        win.Show();
        Dispatcher.Run();
    }
}
"@ -ReferencedAssemblies PresentationFramework,PresentationCore,WindowsBase,System.Xaml

$isStop = ($Event -eq 'stop')
[NotifyWindow]::ShowBlocking(
    $ProjectName, $SessionName, $Context, $isStop,
    $charPath, $iconDir,
    $t.bg, $t.bg2, $t.strip1, $t.strip2,
    $t.titleColor, $t.metaColor, $t.bodyColor, $t.iconBg, $t.ghostColor, $t.bd,
    $radius, ($duration * 1000))
