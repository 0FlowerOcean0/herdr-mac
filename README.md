# Herdr for Mac

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)
![Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-2563EB)

一个非官方、开源的 Herdr macOS 原生客户端。它使用 SwiftUI、AppKit 与 SwiftTerm 构建，在真实 PTY 中直接运行 Herdr TUI，不是 Electron/WebView 网页壳，也不是日志预览器。

> Unofficial native macOS client for [Herdr](https://herdr.dev/). Herdr itself remains the terminal workspace manager; this project supplies the Mac-native window, settings and connection experience around it.

![Herdr for Mac 主界面](assets/screenshots/herdr-main.png)

## 设计原则

Herdr 原有功能不会被 GUI 重做或裁剪。Tabs、末尾 `+`、Spaces、Panes、Agent 状态、Git worktree、通知、插件、集成、Socket API、持久会话与远程连接仍由真正的 Herdr TUI 控制；Mac 外层只提供原生窗口、会话连接、主题预览和客户端设置。

## 功能

- 真实交互式 PTY：键盘、鼠标、ANSI、TrueColor、复制粘贴和全屏 TUI
- 左键直接操作 Herdr 内部 Tab、按钮和对话框
- 普通右键打开 Herdr 官方 Pane/Tab 菜单；`Shift` + 右键打开 macOS 复制、粘贴和查找菜单
- 默认会话、命名会话、`--no-session` 与 SSH Remote Attach
- Remote Attach 支持官方 `--remote-keybindings <local|server>` 与 `--handoff`
- 从指定项目目录启动，支持 SSH config 别名或 `ssh://` 地址
- 18 套与 Herdr 主题名对应的内置配色和即时预览
- 主题写入官方 `~/.config/herdr/config.toml`，其他配置保持不变
- 字体缩放、Option-as-Meta 和可选 Metal GPU 渲染
- 关闭窗口仅 detach，后台 Pane 与 Agent 继续运行

## 主题设置

![Herdr for Mac 主题设置](assets/screenshots/herdr-settings.png)

## 安装

### 1. 安装 Herdr

请先按 [Herdr 官方文档](https://herdr.dev/docs/quick-start/) 安装并确认终端中可以执行：

```bash
herdr --version
```

### 2. 安装 Mac 客户端

从 [GitHub Releases](../../releases/latest) 下载 `Herdr-for-Mac-0.1.0-arm64.zip`，解压后将 `Herdr.app` 拖入“应用程序”。

当前 Release 使用 ad-hoc 签名，尚未进行 Apple Developer ID 签名与公证。第一次打开时请在 Finder 中按住 Control 点击应用并选择“打开”，或前往“系统设置 → 隐私与安全性”确认打开。

要求：macOS 14+、Apple Silicon、Herdr 0.8.2+。

## 从源码构建

需要 Xcode 15+ 和 Swift 5.10+：

```bash
git clone https://github.com/0FlowerOcean0/herdr-mac.git
cd herdr-mac
./scripts/build-app.sh
open dist/Herdr.app
```

开发模式：

```bash
swift run HerdrMac
```

构建可分发压缩包：

```bash
./scripts/package-release.sh
```

产物会写入 `release/`，同时生成 SHA-256 校验文件。

## Herdr 查找顺序

客户端优先使用 `HERDR_BIN_PATH`，然后检查常见的 Homebrew、`~/.local/bin` 和系统 PATH。实际启动形式包括：

```text
herdr
herdr --session <name>
herdr --remote <ssh-target> [--session <name>] [--remote-keybindings <local|server>] [--handoff]
herdr --no-session
```

## 隐私与安全

客户端不会保存模型或 Agent 凭据。终端子进程继承应用环境，并补齐常见命令行工具路径。主题修改只更新 Herdr 官方配置中的主题字段。

## 项目关系与商标

本项目是独立社区项目，并非 Herdr 官方产品，也未获得 Herdr 团队背书。Herdr 名称与 Logo 归其相应权利人所有；使用它们仅用于说明兼容关系。详见 [第三方说明](THIRD_PARTY_NOTICES.md)。

## License

[Apache License 2.0](LICENSE)
