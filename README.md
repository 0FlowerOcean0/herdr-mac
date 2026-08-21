# Herdr Native Clients

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)
![Windows 10+](https://img.shields.io/badge/Windows-10%2B-0078D4?logo=windows11&logoColor=white)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)
![WinUI 3](https://img.shields.io/badge/WinUI-3-7C3AED)
[![Windows Preview](https://github.com/0FlowerOcean0/herdr-mac/actions/workflows/windows.yml/badge.svg)](https://github.com/0FlowerOcean0/herdr-mac/actions/workflows/windows.yml)
![Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-2563EB)

Herdr Native Clients 是一组非官方、开源的 [Herdr](https://herdr.dev/) 桌面客户端，支持 macOS 和 Windows。

客户端直接运行真正的 Herdr TUI。Tabs、Spaces、Panes、Agents、Git worktree、插件和持久会话仍由 Herdr 管理；桌面客户端只负责原生窗口、终端连接、主题和平台交互，不会在外层重复实现一套冲突的界面。

> [!IMPORTANT]
> 本项目是独立社区项目，不是 Herdr 官方产品。使用前需要单独安装 Herdr。

## 下载

| 平台 | 版本 | 系统要求 | 推荐安装 | 便携包 |
| --- | --- | --- | --- | --- |
| macOS | `v0.1.2` | macOS 14+、Apple Silicon | [下载 DMG](https://github.com/0FlowerOcean0/herdr-mac/releases/download/v0.1.2/Herdr-for-Mac-0.1.2-arm64.dmg) | [下载 ZIP](https://github.com/0FlowerOcean0/herdr-mac/releases/download/v0.1.2/Herdr-for-Mac-0.1.2-arm64.zip) |
| Windows Preview | `0.1.0-preview.2` | Windows 10 19041+ / Windows 11、x64 | [下载 Setup.exe](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe) | [下载 ZIP](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64.zip) |

[查看全部 Releases](https://github.com/0FlowerOcean0/herdr-mac/releases)

## 界面预览

### 主界面

![Herdr for Mac 主界面](assets/screenshots/herdr-main.png)

### 主题设置

![Herdr for Mac 主题设置](assets/screenshots/herdr-settings.png)

以上截图来自已完成可视验收的 macOS 版。Windows Preview 已完成构建、ConPTY 双向交互和发布包验证，真实 Windows 运行截图将在实机可视验收后补充。

## 核心能力

- 运行真正的 Herdr TUI，不重做或裁剪 Herdr 功能
- 支持键盘、鼠标、ANSI、TrueColor、复制粘贴和全屏终端界面
- 支持默认会话、命名会话和指定项目启动目录
- 顶部栏可直接选择工作目录并立即重新连接
- 内置 18 套与 Herdr 主题对应的配色
- 主题写入 Herdr 官方配置文件，同时保留其他配置项
- 自动查找 Herdr 可执行文件，也支持 `HERDR_BIN_PATH`
- 使用平台原生终端传输：macOS PTY / Windows ConPTY
- 关闭客户端窗口时不主动终止 Herdr 持久会话

## 平台支持

| 能力 | macOS | Windows Preview |
| --- | :---: | :---: |
| 本地默认会话 | ✓ | ✓ |
| 命名会话 | ✓ | ✓ |
| 指定启动目录 | ✓ | ✓ |
| Herdr Tabs / Spaces / Panes / Agents | ✓ | ✓ |
| 主题切换与配置热重载 | ✓ | ✓ |
| `--no-session` | ✓ | — |
| SSH Remote Attach | ✓ | — |
| Remote keybindings / Handoff | ✓ | — |
| 原生右键交互 | ✓ | ✓ |

`—` 表示 Herdr 官方 Windows Preview 当前尚未支持该能力，因此本客户端不会伪装实现。Windows 的完整边界说明见 [Windows 使用文档](windows/README-WINDOWS.md)。

## 安装

### macOS

1. 按照 [Herdr Quick Start](https://herdr.dev/docs/quick-start/) 安装 Herdr。
2. 在终端确认 Herdr 可以运行：

   ```bash
   herdr --version
   ```

3. 下载并打开 [Herdr-for-Mac-0.1.2-arm64.dmg](https://github.com/0FlowerOcean0/herdr-mac/releases/download/v0.1.2/Herdr-for-Mac-0.1.2-arm64.dmg)。
4. 将 `Herdr.app` 拖到 DMG 中的 `Applications`，再从“应用程序”启动。

当前 macOS Release 使用 ad-hoc 签名，尚未进行 Apple Developer ID 签名与公证。首次打开时，请在 Finder 中按住 Control 点击应用并选择“打开”，或前往“系统设置 → 隐私与安全性”确认打开。

[下载 DMG SHA-256](https://github.com/0FlowerOcean0/herdr-mac/releases/download/v0.1.2/Herdr-for-Mac-0.1.2-arm64.dmg.sha256)

### Windows Preview

1. 按照 [Herdr Windows Preview 文档](https://herdr.dev/docs/windows-beta/) 安装 Herdr：

   ```powershell
   powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
   ```

2. 下载并运行 [Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe)。
3. 按安装向导完成安装，然后从开始菜单启动 `Herdr`。

安装器会将客户端安装到当前用户的 `%LOCALAPPDATA%\Programs\Herdr Native Client`，并在 Windows“已安装的应用”中提供卸载入口。安装包已包含 .NET 和 Windows App SDK 运行文件，但系统仍需 Microsoft Edge WebView2 Runtime。

当前 Setup.exe 尚未使用商业代码签名证书，Windows SmartScreen 可能显示“未知发布者”。请只从本仓库 Release 下载，并先使用对应 SHA-256 文件校验；确认后可选择“更多信息 → 仍要运行”。

[下载 Setup.exe SHA-256](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe.sha256)

需要免安装版本时，可下载完整 ZIP；不要只复制其中一个 EXE。

## 使用与配置

### Herdr 查找顺序

macOS：

1. `HERDR_BIN_PATH`
2. Homebrew 与常见本地安装路径
3. 系统 `PATH`

Windows：

1. 客户端设置中指定的路径
2. `HERDR_BIN_PATH`
3. `%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe`
4. `%USERPROFILE%\.herdr\packages\standalone\current\herdr.exe`
5. 系统 `PATH`

### 会话

macOS 客户端支持以下启动方式：

```text
herdr
herdr --session <name>
herdr --no-session
herdr --remote <ssh-target> [--session <name>] [--remote-keybindings <local|server>] [--handoff]
```

Windows 客户端支持官方 Preview 当前提供的本地默认会话和命名会话。

### 右键菜单

- macOS：普通右键交给 Herdr TUI；`Shift` + 右键打开复制、粘贴和查找菜单
- Windows：普通右键提供复制、粘贴和重新连接；终端键盘与鼠标事件继续交给 Herdr

### 主题

- macOS 配置：`~/.config/herdr/config.toml`
- Windows 配置：`%APPDATA%\herdr\config.toml`

切换主题时只修改 Herdr 的主题字段，不覆盖配置文件中的其他设置。

## 从源码构建

### macOS

需要 Xcode 15+ 和 Swift 5.10+。

```bash
git clone https://github.com/0FlowerOcean0/herdr-mac.git
cd herdr-mac
./scripts/build-app.sh
open dist/Herdr.app
```

开发运行：

```bash
swift run HerdrMac
```

构建发布包：

```bash
./scripts/package-release.sh
./scripts/package-dmg.sh
```

### Windows

需要 Windows 10/11、.NET 8 SDK 和 Node.js 22。

```powershell
git clone https://github.com/0FlowerOcean0/herdr-mac.git
cd herdr-mac
.\windows\package-windows.ps1
```

脚本会构建离线终端资源、运行 ConPTY 双向交互 smoke、执行单元测试，并生成 self-contained x64 ZIP、Setup.exe 和对应 SHA-256 文件。

## 项目结构

```text
Sources/HerdrMac/          macOS SwiftUI / AppKit 客户端
windows/Herdr.Windows/    Windows WinUI 3 客户端
windows/terminal-web/     Windows 离线终端渲染资源
windows/*.Tests/          Windows 单元与 ConPTY 测试
scripts/                  macOS 构建与打包脚本
assets/screenshots/       README 截图
```

## 验证状态

macOS `0.1.2` 已通过 `22/22` 项测试。

Windows `0.1.0-preview.2` 已完成：

- Windows runner 编译
- ConPTY 双向输入与输出 smoke
- 单元测试 `10/10`
- WinUI 3 x64 self-contained 发布
- Inno Setup 安装器编译
- GitHub Release 附件重新下载与 SHA-256 校验

自动化结果可以证明构建、终端传输和发布包完整性，但不等同于 Windows 实机视觉验收。

## 隐私与安全

- 不保存模型、Agent 或 SSH 凭据
- 终端子进程继承客户端运行环境
- 不重新打包 Herdr 本体
- Windows 终端渲染资源随应用离线分发，不访问网页终端服务

## 项目关系与商标

本项目并非 Herdr 官方产品，也未获得 Herdr 团队背书。Herdr 名称与 Logo 归其相应权利人所有，本项目仅将其用于说明兼容关系。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## License

[Apache License 2.0](LICENSE)
