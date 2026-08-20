import AppKit
import SwiftUI

struct TerminalRootView: View {
    @ObservedObject var session: TerminalSessionModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @State private var sessionAlert: SessionAlert?

    var body: some View {
        VStack(spacing: 0) {
            productHeader
            terminalContent
        }
        .background(session.theme.palette.background.color.ignoresSafeArea())
        .preferredColorScheme(session.preferredColorScheme)
        .tint(session.theme.palette.cursor.color)
        .sheet(isPresented: $session.showingNewSession) {
            NewSessionSheet(session: session)
        }
        .sheet(isPresented: $session.showingRemoteConnection) {
            RemoteConnectionSheet(session: session)
        }
        .onChange(of: session.sessionCommandError) { _, error in
            if let error {
                sessionAlert = .error(error)
            }
        }
        .onAppear {
            session.syncThemeWithHostAppearance(colorScheme)
        }
        .onChange(of: colorScheme) { _, newValue in
            session.syncThemeWithHostAppearance(newValue)
        }
        .alert(item: $sessionAlert) { alert in
            switch alert {
            case let .error(message):
                Alert(
                    title: Text("Herdr 操作失败"),
                    message: Text(message),
                    dismissButton: .default(Text("好")) {
                        session.sessionCommandError = nil
                    }
                )
            }
        }
    }

    private var terminalContent: some View {
        ZStack {
            session.theme.palette.background.color
            HerdrTerminalView(session: session)

            if case .exited = session.processState {
                disconnectedOverlay
            }
        }
    }

    private var productHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                HerdrLogoMarkView(color: session.theme.palette.cursor.color, size: 14)
                Text("herdr")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(session.theme.palette.foreground.color)
            }
            .padding(.leading, 14)

            Spacer(minLength: 12)

            Menu {
                ForEach(TerminalTheme.allCases) { theme in
                    Button {
                        session.selectTheme(theme)
                    } label: {
                        if session.theme == theme {
                            Label(theme.title, systemImage: "checkmark")
                        } else {
                            Text(theme.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(session.theme.palette.foreground.color.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("主题：\(session.theme.title)")
            .accessibilityLabel("选择 Herdr 主题")
            .accessibilityValue(session.theme.title)

            Button {
                chooseWorkingDirectory()
            } label: {
                Image(systemName: session.connection.workingDirectory == nil ? "folder" : "folder.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(workingDirectoryButtonColor)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(workingDirectoryHelp)
            .accessibilityLabel("选择 Herdr 工作目录")
            .accessibilityValue(session.connection.workingDirectory ?? "未指定")

            Button {
                openSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(session.theme.palette.foreground.color.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Herdr 设置")
            .accessibilityLabel("打开 Herdr 设置")
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(session.theme.palette.background.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(session.theme.palette.foreground.color.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var workingDirectoryButtonColor: Color {
        if session.connection.workingDirectory == nil {
            session.theme.palette.foreground.color.opacity(0.72)
        } else {
            session.theme.palette.cursor.color
        }
    }

    private var workingDirectoryHelp: String {
        if let directory = session.connection.workingDirectory {
            "工作目录：\(directory)"
        } else {
            "选择工作目录"
        }
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择 Herdr 工作目录"
        panel.prompt = "在此目录打开"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if let currentDirectory = session.connection.workingDirectory ?? session.currentDirectory {
            panel.directoryURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
        }
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        session.openWorkingDirectory(directory.path)
    }

    private var disconnectedOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SESSION DETACHED")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(session.theme.palette.cursor.color)
            Text("终端已断开")
                .font(.title2.weight(.semibold))
                .foregroundStyle(session.theme.palette.foreground.color)
            if let error = session.launchError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 420)
            } else {
                Text("Herdr server 会继续保存 Pane；重新连接不会丢失会话。")
                    .font(.subheadline)
                    .foregroundStyle(session.theme.palette.foreground.color.opacity(0.64))
            }
            Button("重新连接") { session.reconnect() }
                .buttonStyle(.borderedProminent)
                .tint(session.theme.palette.cursor.color)
        }
        .padding(24)
        .frame(maxWidth: 470, alignment: .leading)
        .background(session.theme.palette.background.color)
        .overlay {
            Rectangle()
                .stroke(session.theme.palette.foreground.color.opacity(0.18), lineWidth: 1)
        }
    }
}

private enum SessionAlert: Identifiable {
    case error(String)

    var id: String {
        switch self {
        case let .error(message): "error-\(message)"
        }
    }
}

private struct NewSessionSheet: View {
    @ObservedObject var session: TerminalSessionModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ConnectionSheetHeader(
                eyebrow: "NAMED SESSION",
                title: "新建命名会话",
                detail: "命名会话拥有独立的 Herdr server、Socket 和持久状态。",
                accent: session.theme.palette.cursor.color
            )

            TextField("例如：work", text: $name)
                .textFieldStyle(.roundedBorder)

            CommandPreview(command: newSessionCommand, palette: session.theme.palette)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("创建并连接") {
                    session.createSession(named: name)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 480)
        .tint(session.theme.palette.cursor.color)
        .preferredColorScheme(session.preferredColorScheme)
    }

    private var newSessionCommand: String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedName.isEmpty ? "$ herdr --session <name>" : "$ herdr --session \(normalizedName)"
    }
}

private struct RemoteConnectionSheet: View {
    @ObservedObject var session: TerminalSessionModel
    @Environment(\.dismiss) private var dismiss
    @State private var target = ""
    @State private var sessionName = ""
    @State private var keybindings: HerdrRemoteKeybindings = .local
    @State private var handoff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ConnectionSheetHeader(
                eyebrow: "REMOTE ATTACH",
                title: "连接远程 Herdr",
                detail: "SSH、远程启动和剪贴板桥接仍由 Herdr 官方客户端处理。",
                accent: session.theme.palette.cursor.color
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("SSH 目标")
                    .font(.headline)
                TextField("例如 workbox 或 ssh://you@server:2222", text: $target)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("命名会话（可选）")
                    .font(.headline)
                TextField("例如 work", text: $sessionName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("远程按键绑定")
                    .font(.headline)
                Picker("远程按键绑定", selection: $keybindings) {
                    ForEach(HerdrRemoteKeybindings.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Toggle("启用 Live Handoff（--handoff）", isOn: $handoff)

            CommandPreview(command: remoteCommand, palette: session.theme.palette)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("连接") {
                    session.connectRemote(
                        target: target,
                        sessionName: sessionName,
                        keybindings: keybindings,
                        handoff: handoff
                    )
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 520)
        .tint(session.theme.palette.cursor.color)
        .preferredColorScheme(session.preferredColorScheme)
    }

    private var remoteCommand: String {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSession = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        var command = "$ herdr --remote \(normalizedTarget.isEmpty ? "<ssh-target>" : normalizedTarget)"
        if !normalizedSession.isEmpty {
            command += " --session \(normalizedSession)"
        }
        if keybindings == .server {
            command += " --remote-keybindings server"
        }
        if handoff {
            command += " --handoff"
        }
        return command
    }
}

private struct ConnectionSheetHeader: View {
    let eyebrow: String
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CommandPreview: View {
    let command: String
    let palette: TerminalThemePalette

    var body: some View {
        Text(command)
            .font(.system(size: 11.5, weight: .regular, design: .monospaced))
            .foregroundStyle(palette.foreground.color)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(palette.background.color)
            .overlay {
                Rectangle()
                    .stroke(palette.foreground.color.opacity(0.16), lineWidth: 1)
            }
            .accessibilityLabel("将运行命令 \(command)")
    }
}

struct TerminalSettingsView: View {
    @ObservedObject var session: TerminalSessionModel

    var body: some View {
        Form {
            Section("Herdr 官方主题") {
                HStack {
                    Label("当前主题", systemImage: "circle.lefthalf.filled")
                    Spacer()
                    Text(session.theme.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(session.theme.palette.cursor.color)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(TerminalTheme.allCases) { theme in
                        Button {
                            session.selectTheme(theme)
                        } label: {
                            ThemePresetCard(theme: theme, isSelected: session.theme == theme)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(theme.title)，\(theme.subtitle)")
                        .accessibilityValue(session.theme == theme ? "已选择" : "")
                        .accessibilityAddTraits(session.theme == theme ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)

                Text("选择后写入 ~/.config/herdr/config.toml，并通过官方 reload-config 立即应用；和 Herdr 内置设置一致，手动选择会关闭 auto_switch。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Mac 客户端显示") {
                HStack {
                    Text("字体大小")
                    Slider(value: $session.fontSize, in: 9...28, step: 1)
                    Text("\(Int(session.fontSize))")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }

                Toggle("使用 Metal 渲染", isOn: $session.useMetal)
            }

            Section("Mac 客户端键盘") {
                Toggle("将 Option 用作 Meta 键", isOn: $session.optionAsMeta)
            }

            Section {
                Text("窗口中的内容是 Herdr 自己的真实终端客户端，不是日志预览。关闭窗口只会 detach，后台 server 和 Pane 会继续运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(session.theme.palette.cursor.color)
        .preferredColorScheme(session.preferredColorScheme)
    }
}

private struct ThemePresetCard: View {
    let theme: TerminalTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(theme.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.palette.cursor.color)
                        .accessibilityHidden(true)
                }
            }

            Text(theme.rawValue)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.palette.cursor.color)

            HStack(spacing: 8) {
                Text("❯ herdr")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.palette.foreground.color)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(theme.previewColors.indices, id: \.self) { index in
                        Circle()
                            .fill(theme.previewColors[index].color)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(theme.palette.background.color)
            .overlay {
                Rectangle()
                    .stroke(theme.palette.foreground.color.opacity(0.18), lineWidth: 1)
            }

            Text(theme.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            Rectangle()
                .stroke(
                    isSelected ? theme.palette.cursor.color : Color.secondary.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
    }
}
