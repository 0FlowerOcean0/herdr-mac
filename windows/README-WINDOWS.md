# Herdr for Windows Preview

这是一个非官方、开源的 Herdr Windows 原生客户端。窗口外壳使用 WinUI 3，终端输入输出通过 Windows ConPTY 连接真正的 `herdr.exe`；终端画面由随应用离线分发的 xterm.js 渲染，不会访问网页终端服务。

## 下载

当前公开版本：[`0.1.0-preview.2`](https://github.com/0FlowerOcean0/herdr-mac/releases/tag/windows-v0.1.0-preview.2)

- [下载 Setup.exe（推荐）](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe)
- [下载 Setup.exe SHA-256](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64-Setup.exe.sha256)
- [下载免安装 ZIP](https://github.com/0FlowerOcean0/herdr-mac/releases/download/windows-v0.1.0-preview.2/Herdr-for-Windows-0.1.0-preview.2-x64.zip)

Setup.exe 会安装到当前用户的 `%LOCALAPPDATA%\Programs\Herdr Native Client`，不需要管理员权限，并创建开始菜单入口和标准卸载项。

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

1. 双击下载的 Setup.exe 并完成安装。
2. 从开始菜单启动 `Herdr`。
3. 客户端会自动查找 `%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe`、`%USERPROFILE%\.herdr\packages\standalone\current\herdr.exe`、`HERDR_BIN_PATH` 与 `PATH`。
4. 右上角文件夹按钮可直接选择工作目录；设置中仍可配置命名会话、默认启动目录和 Herdr 官方主题。

当前安装器尚未使用商业代码签名证书，SmartScreen 可能显示“未知发布者”。请只从本项目 Release 下载，核对 SHA-256 后选择“更多信息 → 仍要运行”。如使用免安装 ZIP，必须完整解压，不能只复制其中一个 EXE。

普通右键会打开复制、粘贴与重新连接菜单；键盘和鼠标事件仍交给 Herdr TUI。窗口外不会复制 spaces、panes 或 agent 标签。

## 官方 Windows Preview 能力边界

本客户端保留官方 Windows Preview 当前支持的本地持久会话、PowerShell / cmd、spaces、panes、agents、plugins（preview）和 history。官方尚未支持的 Direct terminal attach、`herdr --remote`、live handoff 与 Unix fd handoff 不会出现在 Windows 客户端中。

Herdr 在 Windows 上自带的 app-local ConPTY 文件必须与官方 `herdr.exe` 保持在原安装目录中；本项目不会重新打包 Herdr 本体。

## 当前验证

- Windows runner 编译和 self-contained x64 发布通过
- 独立 ConPTY 输入/输出 smoke 通过
- 单元测试 `10/10` 通过
- Inno Setup 安装器编译通过
- Setup.exe 与 ZIP 通过 SHA-256 校验

目前尚未完成 Windows 实机可视验收，因此这里不使用模拟截图代替真实运行截图。
