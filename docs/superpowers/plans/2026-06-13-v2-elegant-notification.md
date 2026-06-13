# V2 优雅弹窗 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 V1 系统 Toast 基础上增加第二种通知模式——优雅弹窗（自定义 WinForms UI），用户可通过「定制弹窗」命令在两种模式间切换，支持主题、图标自定义、立绘上传。

**架构：**
- `notify.ps1` 入口读取 `~/.claude/notify-mode` 文件决定模式（raw/elegant）
- raw 模式走原有系统 Toast
- elegant 模式调用 `notify-elegant.ps1` 显示自绘窗口
- 配置页 HTML + Python 本地服务写入 `~/.claude/notify-config.json`
- 主题数据内嵌在脚本中，图标和立绘路径从配置读取

**技术栈：** PowerShell 5.1+ · System.Drawing (GDI+) · System.Windows.Forms · Python 3 (配置保存服务)

---

## 文件结构

| 文件 | 职责 | 状态 |
|------|------|------|
| `hooks/notify.ps1` | 入口脚本，读取 mode 文件分流 | 修改 |
| `hooks/notify-elegant.ps1` | 优雅弹窗 WinForms 实现 | 新建 |
| `docs/design-v2-preview.html` | 配置预览页（已有） | 保留 |
| `hooks/notify-config-server.py` | Python 配置保存本地服务 | 新建 |
| `SKILL.md` | 更新文档和新命令 | 修改 |
| `docs\design-v2.md` | 设计文档（已有） | 保留 |

## 配置文件格式

`~/.claude/notify-config.json`:
```json
{
  "mode": "elegant",
  "theme": "holo",
  "icons": { "project": "⚙", "done": "✨", "wait": "⚙" },
  "params": { "radius": 14, "duration": 5 },
  "hasImage": false
}
```

`~/.claude/notify-mode`:
```
elegant
```
或
```
raw
```

---

### 任务 1：更新 notify.ps1 入口脚本

**文件：**
- 修改：`hooks/notify.ps1` 头部

在 `param` 和开关检测之后，添加模式检测逻辑：

- [ ] **步骤 1：添加模式检测**

在开关检测之后、数据提取之前，读取 `~/.claude/notify-mode` 文件：

```powershell
# 模式检测——读取配置文件
$notifyConfigPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'
$notifyModePath = Join-Path $env:USERPROFILE '.claude\notify-mode'

$mode = "raw"
if (Test-Path $notifyModePath) {
    $mode = (Get-Content $notifyModePath -Encoding UTF8).Trim().ToLower()
}

# 优雅弹窗模式
if ($mode -eq "elegant") {
    $elegantScript = Join-Path $env:USERPROFILE '.claude\notify-elegant.ps1'
    if (Test-Path $elegantScript) {
        & $elegantScript -Event $Event -TranscriptPath $transcriptPath
        exit 0
    }
}
```

- [ ] **步骤 2：提取 data 部分变为函数共享**

由于优雅弹窗也需要项目名、会话名、上下文等数据，将数据提取逻辑提取到一个可重复调用的位置，或者优雅弹窗脚本自己解析。

实际方案：优雅弹窗脚本独立解析 transcript（保持简单，避免耦合）。

- [ ] **步骤 3：本地安装测试**

```bash
cp hooks/notify.ps1 ~/.claude/notify.ps1
powershell -ExecutionPolicy Bypass -File ~/.claude/notify.ps1 -Event stop
```

- [ ] **步骤 4：Commit**

```bash
git add hooks/notify.ps1
git commit -m "feat: 入口添加优雅弹窗模式分流"
```

---

### 任务 2：创建 notify-elegant.ps1 优雅弹窗

**文件：**
- 创建：`hooks/notify-elegant.ps1`

这是核心文件。实现一个无边框 WinForms 窗口，右下角弹出，自绘内容。

- [ ] **步骤 1：编写基本窗口框架**

```powershell
param([string]$Event = 'stop', [string]$TranscriptPath = "")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 读取配置
$configPath = Join-Path $env:USERPROFILE '.claude\notify-config.json'
$config = @{}
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
}

$theme = if ($config.theme) { $config.theme } else { "holo" }
$radius = if ($config.params.radius) { [int]$config.params.radius } else { 14 }
$duration = if ($config.params.duration) { [int]$config.params.duration * 1000 } else { 5000 }
$iconProj = if ($config.icons.project) { $config.icons.project } else { "⚙" }
$iconDone = if ($config.icons.done) { $config.icons.done } else { "✨" }
$iconWait = if ($config.icons.wait) { $config.icons.wait } else { "⚙" }

# 字符图路径
$charImagePath = Join-Path $env:USERPROFILE '.claude\themes\character.png'

# 创建窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code"
$form.WindowState = 'Minimized'
$form.ShowInTaskbar = $false
$form.Load.Add({
    $form.WindowState = 'Normal'
})
```

- [ ] **步骤 2：实现主题定义**

```powershell
$themes = @{
    holo = @{
        bg = "#1a0a30"; bd = "#8b5cf6"; iconBg = "#8b5cf6"
        title = "#ddd6fe"; meta = "#a78bfa"; body = "#e8e0f8"
        btnBg = "#8b5cf6"; btnText = "#FFFFFF"; ghost = "#a78bfa"
        stripBg = @(45,16,96)
    }
    cyber = @{
        bg = "#0a0a0a"; bd = "#00ff41"; iconBg = "#00ff41"
        title = "#00ff41"; meta = "#00cc33"; body = "#a0ffa0"
        btnBg = "#00ff41"; btnText = "#000000"; ghost = "#00ff41"
        stripBg = @(0,34,0)
    }
    kawaii = @{
        bg = "#fff0f6"; bd = "#f472b6"; iconBg = "#ec4899"
        title = "#be185d"; meta = "#f472b6"; body = "#831843"
        btnBg = "#ec4899"; btnText = "#FFFFFF"; ghost = "#ec4899"
        stripBg = @(252,231,243)
    }
    dark = @{
        bg = "#1e1e2e"; bd = "#45475a"; iconBg = "#cba6f7"
        title = "#cdd6f4"; meta = "#a6adc8"; body = "#cdd6f4"
        btnBg = "#585b70"; btnText = "#FFFFFF"; ghost = "#a6adc8"
        stripBg = @(24,24,37)
    }
    wa = @{
        bg = "#faf5eb"; bd = "#c4a882"; iconBg = "#c4a882"
        title = "#3d2e1e"; meta = "#a67c52"; body = "#3d2e1e"
        btnBg = "#a67c52"; btnText = "#FFFFFF"; ghost = "#a67c52"
        stripBg = @(232,220,204)
    }
}
$t = $themes[$theme]
if (-not $t) { $t = $themes["holo"] }
```

- [ ] **步骤 3：创建窗口布局**

```powershell
# 窗口尺寸
$formWidth = 380
$formHeight = 200
$form.FormBorderStyle = 'None'
$form.StartPosition = 'Manual'
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 26, 10, 48)

# 右下角定位
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$x = $screen.WorkingArea.Right - $formWidth - 16
$y = $screen.WorkingArea.Bottom - $formHeight - 16
$form.Location = New-Object System.Drawing.Point($x, $y)
$form.Size = New-Object System.Drawing.Size($formWidth, $formHeight)

# 圆角裁剪
$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$path.AddArc(0, 0, $radius*2, $radius*2, 180, 90)
$path.AddArc($formWidth - $radius*2 - 1, 0, $radius*2, $radius*2, 270, 90)
$path.AddArc($formWidth - $radius*2 - 1, $formHeight - $radius*2 - 1, $radius*2, $radius*2, 0, 90)
$path.AddArc(0, $formHeight - $radius*2 - 1, $radius*2, $radius*2, 90, 90)
$path.CloseFigure()
$form.Region = [System.Drawing.Region]::new($path)
```

- [ ] **步骤 4：实现自绘逻辑（OnPaint）**

```powershell
$form.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    # 背景
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 26, 10, 48))
    $g.FillRectangle($bgBrush, 0, 0, $formWidth, $formHeight)

    # 角色区（左栏 100px 宽）
    $stripRect = New-Object System.Drawing.Rectangle(0, 0, 100, $formHeight)
    $stripBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $stripRect, [System.Drawing.Color]::FromArgb(255, 45, 16, 96),
        [System.Drawing.Color]::FromArgb(255, 26, 10, 48), 90)
    $g.FillRectangle($stripBrush, $stripRect)

    # 角色图
    $charPath = Join-Path $env:USERPROFILE '.claude\themes\character.png'
    if (Test-Path $charPath) {
        $img = [System.Drawing.Image]::FromFile($charPath)
        $g.DrawImage($img, 0, 0, 100, $formHeight)
    }

    # 内容区
    $x0 = 114
    $y0 = 16

    # 项目名图标
    $g.DrawString($iconProj, New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold),
        [System.Drawing.Brushes]::White, $x0, $y0)

    # 项目名文字
    $nameFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $g.DrawString("claude-code-notify", $nameFont,
        [System.Drawing.Brushes]::White, ($x0 + 28), $y0)

    # 会话名
    $metaFont = New-Object System.Drawing.Font("Segoe UI", 9)
    $g.DrawString("💬 重构代码", $metaFont,
        [System.Drawing.Brushes]::LightGray, $x0, ($y0 + 22))

    # 分割线
    $g.DrawLine([System.Drawing.Pens]::DimGray, $x0, ($y0 + 38), ($formWidth - 16), ($y0 + 38))

    # 主内容
    $bodyFont = New-Object System.Drawing.Font("Segoe UI", 10)
    $g.DrawString("$iconDone 搞定了：所有 .ts 重构为 .js", $bodyFont,
        [System.Drawing.Brushes]::White, $x0, ($y0 + 50))

    # 副内容
    $subFont = New-Object System.Drawing.Font("Segoe UI", 9)
    $g.DrawString("$iconWait 后续待办清单", $subFont,
        [System.Drawing.Brushes]::Gray, $x0, ($y0 + 72))

    # 进度条
    $barRect = New-Object System.Drawing.Rectangle($x0, ($y0 + 94), 140, 4)
    $g.FillRectangle([System.Drawing.Brushes]::DarkGray, $barRect)
    $fillRect = New-Object System.Drawing.Rectangle($x0, ($y0 + 94), 110, 4)
    $g.FillRectangle([System.Drawing.Brushes]::MediumPurple, $fillRect)
    $g.DrawString("78%", $subFont, [System.Drawing.Brushes]::Gray, ($x0 + 146), ($y0 + 90))
})
```

- [ ] **步骤 5：实现渐入动画和自动关闭**

```powershell
# 渐入动画（透明度渐变）
$form.Opacity = 0
$fadeInTimer = New-Object System.Windows.Forms.Timer
$fadeInTimer.Interval = 20
$fadeInTimer.Add_Tick({
    if ($form.Opacity -lt 1) {
        $form.Opacity = [Math]::Min($form.Opacity + 0.08, 1)
    } else {
        $fadeInTimer.Stop()
    }
})
$fadeInTimer.Start()

# 自动关闭
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $duration
$timer.Add_Tick({
    $timer.Stop()
    $fadeOutTimer = New-Object System.Windows.Forms.Timer
    $fadeOutTimer.Interval = 20
    $fadeOutTimer.Add_Tick({
        if ($form.Opacity -gt 0) {
            $form.Opacity = [Math]::Max($form.Opacity - 0.1, 0)
        } else {
            $fadeOutTimer.Stop()
            $form.Close()
        }
    })
    $fadeOutTimer.Start()
})
$timer.Start()

[System.Windows.Forms.Application]::Run($form)
```

- [ ] **步骤 6：测试基本弹窗**

```powershell
powershell -ExecutionPolicy Bypass -File hooks/notify-elegant.ps1 -Event stop
```
预期：右下角弹出全息紫风格的窗口，包含角色区、文字、进度条，5 秒后自动消失。

- [ ] **步骤 7：Commit**

```bash
git add hooks/notify-elegant.ps1
git commit -m "feat: 优雅弹窗 WinForms 实现"
```

---

### 任务 3：创建配置保存服务

**文件：**
- 创建：`hooks/notify-config-server.py`

一个极简 Python HTTP 服务，接收 HTML 配置页 POST 的 JSON，写入 `~/.claude/notify-config.json`。

- [ ] **步骤 1：编写 Python 服务**

```python
import json, os, sys
from http.server import HTTPServer, BaseHTTPRequestHandler

CONFIG_PATH = os.path.expanduser("~/.claude/notify-config.json")
PORT = 18765

class Handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        length = int(self.headers["Content-Length"])
        body = self.rfile.read(length).decode("utf-8")
        data = json.loads(body)
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok"}).encode())

print(f"Config server on http://localhost:{PORT}")
HTTPServer(("", PORT), Handler).serve_forever()
```

- [ ] **步骤 2：更新 HTML 配置页的保存逻辑**

修改 `docs/design-v2-preview.html` 的 `saveConfig()` 函数，POST 到 `http://localhost:18765`：

```javascript
function saveConfig() {
  const config = { mode, theme, icons: ..., params: ..., hasImage: !!uploaded };
  fetch('http://localhost:18765', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(config)
  }).then(r => { ... });
  // 立绘图片另存
  if (uploaded) {
    // base64 太大，改用二进制
    const byteString = atob(uploaded.data.split(',')[1]);
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    for (let i = 0; i < byteString.length; i++) ia[i] = byteString.charCodeAt(i);
    const blob = new Blob([ab], {type: 'image/png'});
    const fd = new FormData();
    fd.append('image', blob, 'character.png');
    fetch('http://localhost:18765/upload', { method: 'POST', body: fd });
  }
}
```

- [ ] **步骤 3：Commit**

```bash
git add hooks/notify-config-server.py docs/design-v2-preview.html
git commit -m "feat: 配置保存服务和 HTML 保存逻辑"
```

---

### 任务 4：更新 SKILL.md 和 README

**文件：**
- 修改：`SKILL.md`
- 修改：`README.md`

- [ ] **步骤 1：SKILL.md 添加定制弹窗命令**

在现有步骤后添加：
```markdown
### 6. 定制弹窗（V2）

用户说「定制弹窗」时：

1. 确保 `~/.claude/notify-elegant.ps1` 存在（从 `hooks/notify-elegant.ps1` 读取写入）
2. 确保 `~/.claude/notify-config-server.py` 存在（从 `hooks/notify-config-server.py` 读取写入）
3. 启动配置服务：`python3 ~/.claude/notify-config-server.py &`
4. 在浏览器打开 `file:///.../docs/design-v2-preview.html`
5. 告知用户：选好配置后点「保存」即可生效

切换模式：
- 用户说「切回系统通知」→ 写入 `raw` 到 `~/.claude/notify-mode`
- 用户说「切换到优雅弹窗」→ 写入 `elegant` 到 `~/.claude/notify-mode`
```

- [ ] **步骤 2：README 添加 V2 特性**

在 Feature 列表添加：
```
- 🎨 **优雅弹窗** — 自定义 UI，多种主题，二次元立绘
- 🎛️ **定制配置** — 可视化配置页面，自由调整主题/图标/立绘
```

- [ ] **步骤 3：Commit**

```bash
git add SKILL.md README.md
git commit -m "docs: 更新 V2 优雅弹窗文档"
```

---

### 任务 5：完整集成测试

- [ ] **步骤 1：安装所有文件到 ~/.claude/**

```bash
cp hooks/notify.ps1 ~/.claude/
cp hooks/notify-elegant.ps1 ~/.claude/
cp hooks/notify-config-server.py ~/.claude/
mkdir -p ~/.claude/themes
```

- [ ] **步骤 2：测试系统弹窗模式**

```bash
echo "raw" > ~/.claude/notify-mode
powershell -ExecutionPolicy Bypass -File ~/.claude/notify.ps1 -Event stop
```
预期：显示系统 Toast

- [ ] **步骤 3：测试优雅弹窗模式**

```bash
echo "elegant" > ~/.claude/notify-mode
powershell -ExecutionPolicy Bypass -File ~/.claude/notify.ps1 -Event stop
```
预期：右下角弹出优雅弹窗

- [ ] **步骤 4：测试配置保存**

```bash
python3 ~/.claude/notify-config-server.py &
# 浏览器打开配置页，点保存
curl -X POST http://localhost:18765 -H "Content-Type: application/json" -d '{"mode":"elegant","theme":"cyber","icons":{}}'
cat ~/.claude/notify-config.json
```
预期：配置写入成功

- [ ] **步骤 5：推送并更新 skills**

```bash
git push
npx skills add qyzxcswbll/claude-code-notify -g --yes
```
