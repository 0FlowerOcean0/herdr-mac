# Herdr for Windows Preview

这是一个非官方、开源的 Herdr Windows 原生客户端。窗口外壳使用 WinUI 3，终端输入输出通过 Windows ConPTY 连接真正的 `herdr.exe`；终端画面由随应用离线分发的 xterm.js 渲染，不会访问网页终端服务。

## 要求

- Windows 10 19041+ 或 Windows 11
- x64 系统
- 已安装 [Herdr Windows Preview](https://herdr.dev/docs/windows-beta/)
- Microsoft Edge WebView2 Runtime（Windows 11 已内置；大多数受支持的 Windows 10 设备也已安装）

官方 PowerShell 安装命令：

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
```

## 使用

1. 解压完整 ZIP，不能只复制其中一个 EXE。
2. 双击 `Herdr.Windows.exe`。
3. 客户端会自动查找 `%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe`、`%USERPROFILE%\.herdr\packages\standalone\current\herdr.exe`、`HERDR_BIN_PATH` 与 `PATH`。
4. 在右上角设置中可选择命名会话、启动目录和 Herdr 官方主题。

普通右键会打开复制、粘贴与重新连接菜单；键盘和鼠标事件仍交给 Herdr TUI。窗口外不会复制 spaces、panes 或 agent 标签。

## 官方 Windows Preview 能力边界

本客户端保留官方 Windows Preview 当前支持的本地持久会话、PowerShell / cmd、spaces、panes、agents、plugins（preview）和 history。官方尚未支持的 Direct terminal attach、`herdr --remote`、live handoff 与 Unix fd handoff 不会出现在 Windows 客户端中。

Herdr 在 Windows 上自带的 app-local ConPTY 文件必须与官方 `herdr.exe` 保持在原安装目录中；本项目不会重新打包 Herdr 本体。
