using System.Text.Json;
using Herdr.Windows.Models;
using Herdr.Windows.Services;
using Herdr.Windows.Terminal;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using Microsoft.Web.WebView2.Core;
using Windows.ApplicationModel.DataTransfer;
using Windows.Foundation;
using Windows.Graphics;
using Windows.Storage.Pickers;
using Windows.System;

namespace Herdr.Windows;

public sealed partial class MainWindow : Window
{
    private readonly AppSettingsService _settingsService = new();
    private readonly HerdrConfigService _configService = new();
    private AppSettings _settings;
    private ConPtySession? _session;
    private bool _terminalReady;
    private short _columns = 120;
    private short _rows = 36;

    public MainWindow()
    {
        InitializeComponent();
        _settings = _settingsService.Load();
        var configuredTheme = _configService.LoadThemeName();
        if (!string.IsNullOrWhiteSpace(configuredTheme)) _settings.ThemeName = configuredTheme;

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        AppWindow.Resize(new SizeInt32(1280, 800));
        Closed += MainWindow_Closed;
        TerminalWebView.Loaded += TerminalWebView_Loaded;
        ApplyTheme(TerminalThemeCatalog.Find(_settings.ThemeName));
    }

    private async void TerminalWebView_Loaded(object sender, RoutedEventArgs e)
    {
        TerminalWebView.Loaded -= TerminalWebView_Loaded;
        try
        {
            await TerminalWebView.EnsureCoreWebView2Async();
            var core = TerminalWebView.CoreWebView2;
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.IsZoomControlEnabled = false;
            core.WebMessageReceived += CoreWebView2_WebMessageReceived;

            var terminalDirectory = Path.Combine(AppContext.BaseDirectory, "Assets", "Terminal");
            core.SetVirtualHostNameToFolderMapping(
                "terminal.herdr",
                terminalDirectory,
                CoreWebView2HostResourceAccessKind.DenyCors);
            TerminalWebView.Source = new Uri("https://terminal.herdr/index.html");
        }
        catch (Exception exception)
        {
            ShowEmptyState("终端组件无法启动", $"WebView2 初始化失败：{exception.Message}");
        }
    }

    private async void CoreWebView2_WebMessageReceived(CoreWebView2 sender, CoreWebView2WebMessageReceivedEventArgs args)
    {
        try
        {
            using var document = JsonDocument.Parse(args.WebMessageAsJson);
            var root = document.RootElement;
            if (!root.TryGetProperty("type", out var typeElement)) return;
            var type = typeElement.GetString();
            switch (type)
            {
                case "ready":
                    _terminalReady = true;
                    ReadTerminalSize(root);
                    ApplyTheme(TerminalThemeCatalog.Find(_settings.ThemeName));
                    await ConnectAsync();
                    break;
                case "input":
                    if (_session is not null && root.TryGetProperty("data", out var dataElement))
                    {
                        await _session.WriteAsync(dataElement.GetString() ?? string.Empty);
                    }
                    break;
                case "resize":
                    ReadTerminalSize(root);
                    _session?.Resize(_columns, _rows);
                    break;
                case "rightClick":
                    var x = root.TryGetProperty("x", out var xElement) ? xElement.GetDouble() : 0;
                    var y = root.TryGetProperty("y", out var yElement) ? yElement.GetDouble() : 0;
                    ShowTerminalContextMenu(x, y);
                    break;
            }
        }
        catch (Exception exception) when (exception is JsonException or IOException or ObjectDisposedException)
        {
            SetStatus("输入连接已断开", false);
        }
    }

    private async Task ConnectAsync()
    {
        await DisposeSessionAsync();
        PostToTerminal(new { type = "reset" });
        var herdrPath = HerdrLocator.Find(_settings.HerdrPath);
        if (herdrPath is null)
        {
            ShowEmptyState(
                "没有找到 Herdr",
                "请先安装 Herdr Windows Preview，或在设置中选择 herdr.exe。官方安装命令：\nirm https://herdr.dev/install.ps1 | iex");
            SetStatus("未安装 Herdr", false);
            return;
        }

        try
        {
            var arguments = new List<string>();
            if (!string.IsNullOrWhiteSpace(_settings.SessionName))
            {
                arguments.Add("--session");
                arguments.Add(_settings.SessionName.Trim());
            }
            _session = ConPtySession.Start(
                herdrPath,
                arguments,
                _settings.WorkingDirectory,
                _columns,
                _rows);
            _session.OutputReceived += Session_OutputReceived;
            _session.Exited += Session_Exited;
            EmptyState.Visibility = Visibility.Collapsed;
            TerminalWebView.Visibility = Visibility.Visible;
            SetStatus(string.IsNullOrWhiteSpace(_settings.SessionName) ? "默认会话" : _settings.SessionName.Trim(), true);
            PostToTerminal(new { type = "focus" });
        }
        catch (Exception exception)
        {
            ShowEmptyState("无法启动 Herdr", exception.Message);
            SetStatus("连接失败", false);
        }
    }

    private void Session_OutputReceived(string output)
    {
        DispatcherQueue.TryEnqueue(() => PostToTerminal(new { type = "output", data = output }));
    }

    private void Session_Exited()
    {
        DispatcherQueue.TryEnqueue(() => SetStatus("已断开", false));
    }

    private async void ReconnectButton_Click(object sender, RoutedEventArgs e)
    {
        SetStatus("正在重新连接…", false);
        await ConnectAsync();
    }

    private async void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        var herdrPathBox = new TextBox
        {
            Header = "herdr.exe",
            PlaceholderText = @"默认自动查找 %LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe",
            Text = _settings.HerdrPath ?? string.Empty
        };
        var chooseHerdrButton = new Button { Content = "选择 herdr.exe", HorizontalAlignment = HorizontalAlignment.Left };
        chooseHerdrButton.Click += async (_, _) =>
        {
            var picker = new FileOpenPicker { SuggestedStartLocation = PickerLocationId.Downloads };
            picker.FileTypeFilter.Add(".exe");
            WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
            var file = await picker.PickSingleFileAsync();
            if (file is not null) herdrPathBox.Text = file.Path;
        };

        var sessionNameBox = new TextBox
        {
            Header = "会话名称（留空为默认会话）",
            PlaceholderText = "例如 work",
            Text = _settings.SessionName ?? string.Empty
        };
        var workingDirectoryBox = new TextBox
        {
            Header = "启动目录",
            PlaceholderText = "留空时使用用户主目录",
            Text = _settings.WorkingDirectory ?? string.Empty
        };
        var chooseDirectoryButton = new Button { Content = "选择文件夹", HorizontalAlignment = HorizontalAlignment.Left };
        chooseDirectoryButton.Click += async (_, _) =>
        {
            var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.ComputerFolder };
            picker.FileTypeFilter.Add("*");
            WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
            var folder = await picker.PickSingleFolderAsync();
            if (folder is not null) workingDirectoryBox.Text = folder.Path;
        };

        var themePicker = new ComboBox
        {
            Header = "Herdr 官方主题",
            ItemsSource = TerminalThemeCatalog.All,
            DisplayMemberPath = nameof(TerminalTheme.Title),
            SelectedItem = TerminalThemeCatalog.Find(_settings.ThemeName),
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        var note = new TextBlock
        {
            Text = "Windows Preview 按官方能力提供本地持久会话、spaces、panes、agents、plugins 与 history。Remote / Handoff 尚未在官方 Windows 版支持。",
            TextWrapping = TextWrapping.Wrap,
            Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 166, 173, 200)),
            FontSize = 12
        };
        var content = new StackPanel { Spacing = 10, MinWidth = 500 };
        content.Children.Add(herdrPathBox);
        content.Children.Add(chooseHerdrButton);
        content.Children.Add(sessionNameBox);
        content.Children.Add(workingDirectoryBox);
        content.Children.Add(chooseDirectoryButton);
        content.Children.Add(themePicker);
        content.Children.Add(note);

        var dialog = new ContentDialog
        {
            XamlRoot = RootGrid.XamlRoot,
            Title = "Herdr 设置",
            Content = content,
            PrimaryButtonText = "保存并应用",
            SecondaryButtonText = "安装说明",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary
        };
        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.Secondary)
        {
            await Launcher.LaunchUriAsync(new Uri("https://herdr.dev/docs/windows-beta/"));
            return;
        }
        if (result != ContentDialogResult.Primary) return;

        var oldPath = _settings.HerdrPath;
        var oldWorkingDirectory = _settings.WorkingDirectory;
        var oldSessionName = _settings.SessionName;
        _settings.HerdrPath = Normalize(herdrPathBox.Text);
        _settings.WorkingDirectory = Normalize(workingDirectoryBox.Text);
        _settings.SessionName = Normalize(sessionNameBox.Text);
        var selectedTheme = themePicker.SelectedItem as TerminalTheme ?? TerminalThemeCatalog.All[0];
        _settings.ThemeName = selectedTheme.Name;
        _settingsService.Save(_settings);
        ApplyTheme(selectedTheme);

        var resolvedHerdr = HerdrLocator.Find(_settings.HerdrPath);
        try
        {
            _configService.SaveTheme(selectedTheme.Name);
            if (resolvedHerdr is not null)
            {
                await HerdrConfigService.ReloadAsync(resolvedHerdr, _settings.SessionName);
            }
        }
        catch (Exception exception)
        {
            SetStatus($"主题已切换；配置重载失败：{exception.Message}", false);
        }

        var launchChanged = !string.Equals(oldPath, _settings.HerdrPath, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(oldWorkingDirectory, _settings.WorkingDirectory, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(oldSessionName, _settings.SessionName, StringComparison.Ordinal);
        if (launchChanged || _session is null) await ConnectAsync();
    }

    private void ApplyTheme(TerminalTheme theme)
    {
        _settings.ThemeName = theme.Name;
        var background = ParseColor(theme.Palette.Background);
        var titleBackground = ParseColor("#20202e");
        RootGrid.Background = new SolidColorBrush(background);
        AppTitleBar.Background = new SolidColorBrush(titleBackground);
        TerminalWebView.DefaultBackgroundColor = background;
        if (_terminalReady)
        {
            PostToTerminal(new { type = "theme", theme = theme.Palette.ToWebTheme() });
        }
    }

    private void ShowTerminalContextMenu(double x, double y)
    {
        var flyout = new MenuFlyout();
        var copy = new MenuFlyoutItem { Text = "复制", Icon = new FontIcon { Glyph = "\uE8C8" } };
        copy.Click += async (_, _) => await CopySelectionAsync();
        var paste = new MenuFlyoutItem { Text = "粘贴", Icon = new FontIcon { Glyph = "\uE77F" } };
        paste.Click += async (_, _) => await PasteAsync();
        flyout.Items.Add(copy);
        flyout.Items.Add(paste);
        flyout.Items.Add(new MenuFlyoutSeparator());
        var reconnect = new MenuFlyoutItem { Text = "重新连接", Icon = new FontIcon { Glyph = "\uE72C" } };
        reconnect.Click += async (_, _) => await ConnectAsync();
        flyout.Items.Add(reconnect);
        flyout.ShowAt(TerminalWebView, new FlyoutShowOptions
        {
            Position = new Point(x, y),
            ShowMode = FlyoutShowMode.Transient
        });
    }

    private async Task CopySelectionAsync()
    {
        if (TerminalWebView.CoreWebView2 is null) return;
        var json = await TerminalWebView.CoreWebView2.ExecuteScriptAsync("window.herdrTerminal?.getSelection() ?? ''");
        var text = JsonSerializer.Deserialize<string>(json);
        if (string.IsNullOrEmpty(text)) return;
        var package = new DataPackage();
        package.SetText(text);
        Clipboard.SetContent(package);
        Clipboard.Flush();
    }

    private async Task PasteAsync()
    {
        if (_session is null) return;
        var content = Clipboard.GetContent();
        if (!content.Contains(StandardDataFormats.Text)) return;
        var text = await content.GetTextAsync();
        await _session.WriteAsync(text);
        PostToTerminal(new { type = "focus" });
    }

    private void ReadTerminalSize(JsonElement root)
    {
        if (root.TryGetProperty("cols", out var columnsElement))
        {
            _columns = (short)Math.Clamp(columnsElement.GetInt32(), 1, short.MaxValue);
        }
        if (root.TryGetProperty("rows", out var rowsElement))
        {
            _rows = (short)Math.Clamp(rowsElement.GetInt32(), 1, short.MaxValue);
        }
    }

    private void PostToTerminal(object message)
    {
        if (!_terminalReady || TerminalWebView.CoreWebView2 is null) return;
        TerminalWebView.CoreWebView2.PostWebMessageAsJson(JsonSerializer.Serialize(message));
    }

    private void ShowEmptyState(string title, string message)
    {
        EmptyTitle.Text = title;
        EmptyMessage.Text = message;
        EmptyState.Visibility = Visibility.Visible;
        TerminalWebView.Visibility = Visibility.Collapsed;
    }

    private void SetStatus(string text, bool connected)
    {
        StatusText.Text = connected ? $"●  {text}" : text;
        StatusText.Foreground = new SolidColorBrush(connected
            ? ColorHelper.FromArgb(255, 166, 227, 161)
            : ColorHelper.FromArgb(255, 166, 173, 200));
    }

    private async Task DisposeSessionAsync()
    {
        var session = _session;
        _session = null;
        if (session is null) return;
        session.OutputReceived -= Session_OutputReceived;
        session.Exited -= Session_Exited;
        await session.DisposeAsync();
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        _ = DisposeSessionAsync();
    }

    private static string? Normalize(string value)
    {
        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }

    private static Windows.UI.Color ParseColor(string value)
    {
        var hex = value.TrimStart('#');
        return ColorHelper.FromArgb(
            255,
            Convert.ToByte(hex[..2], 16),
            Convert.ToByte(hex.Substring(2, 2), 16),
            Convert.ToByte(hex.Substring(4, 2), 16));
    }
}
