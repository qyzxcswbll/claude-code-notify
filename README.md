# Claude Code Notify

[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-lightgrey)]()
[![Skill](https://img.shields.io/badge/skills.sh-claude--code-orange)]()

> 离开 Claude Code 去做其他事，任务完成时自动弹窗通知你，不用一直盯着终端。

## Feature

- 🔔 **桌面通知** — 任务完成或需要你回应时，系统原生弹窗，不打断操作
- 📝 **带上下文** — 通知内容显示你最后一条输入，一眼知道是哪个任务
- ⚡️ **零依赖** — 无需安装任何第三方包，调用 Windows/macOS 原生通知 API
- 🪄 **一次配置永久生效** — skill 一键安装，一条命令完成配置，以后自动通知
- 🖥️ **跨平台** — Windows 10/11 Toast 通知 & macOS 通知中心

## 安装

```bash
npx skills add qyzxcswbll/claude-code-notify -g
```

安装后在 Claude Code 中执行以下任一方式完成配置：

- **CLI 版**（终端）：输入 `/notify-setup`
- **VSCode 版**（聊天框）：直接说 **「配置桌面通知」**，AI 会自动执行

按提示确认权限即可。

<details>
<summary><b>从零手动配置（不使用 skill）</b></summary>

如果你不想安装 skill，可以手动创建脚本文件和修改 `~/.claude/settings.json`，步骤见 [SKILL.md](SKILL.md)。
</details>

## 使用示例

### 🎯 场景一：后台跑长任务

```
帮我把这个项目里的所有 .ts 文件重构为 .js
```
→ 切到浏览器刷网页，Claude 完成后右下角弹窗通知你。

### 🎯 场景二：等待 Claude 提问

```
帮我设计用户表结构
```
→ Claude 需要确认几个字段，弹窗提醒你回来回复。

### 🎯 场景三：批量处理文件

```
把这 20 个图片都压缩到 200KB 以下
```
→ 每个文件处理完 Claude 都会等你确认结果，通知让你不用守在电脑前。

## 效果预览

| 事件 | 通知内容 |
|------|---------|
| `Stop` — 任务完成 | 完成: 帮我把这个项目里的所有 .ts 文件重构为 .js |
| `Notification` — 需要你回应 | 需要你回应: 确认是否要删除这个文件 |

## 功能对比

| 特性 | claude-code-notify | claude-ping-me | claude-code-toast |
|------|-------------------|----------------|-------------------|
| 桌面通知 | ✅ Windows Toast + macOS 通知中心 | ❌ 只有声音提示 | ✅ 需安装 npm 包 |
| 任务上下文 | ✅ 显示你的输入 | ❌ | ❌ |
| 零依赖安装 | ✅ 无需额外依赖 | ✅ 需配置 hooks | ❌ 需安装全局 npm |
| 自动配置 | ✅ skill 一键完成 | ❌ 需手动改 settings | ✅ 自动配置 |
| 跨平台 | ✅ Windows + macOS | ❌ 仅 macOS | ✅ 跨平台 |

## FAQ

- **为什么用 skill 而不是直接安装？**

  skill 只需要一次 `/notify-setup` 调用，AI 自动完成脚本创建和配置注入。不需要你手动新建文件、复制粘贴代码、编辑 JSON。

- **安装后通知没有弹出来？**

  先手动测试：Windows 执行 `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\notify.ps1" -Event stop`，macOS 执行 `echo '{}' | bash ~/.claude/notify stop`。有报错说明文件写入或编码有问题，检查 `~/.claude/notify` 文件内容是否完整、编码是否为 UTF-8 BOM（Windows）。

- **会影响 Claude Code 的响应速度吗？**

  不会。hooks 以子进程运行，`timeout: 10` 秒封顶。通知脚本只读 JSONL 文件末尾 100 行，通常几毫秒完成，即使失败也不影响主流程。

- **支持 Linux 吗？**

  目前不支持。Linux 桌面通知方案各有差异（notify-send、D-Bus），后续视需求添加。

---

## 许可证

MIT
