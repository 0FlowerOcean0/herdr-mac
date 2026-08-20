import AppKit
import SwiftUI

@main
struct HerdrMacApp: App {
    @StateObject private var session = TerminalSessionModel()

    var body: some Scene {
        WindowGroup("Herdr") {
            TerminalRootView(session: session)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建命名会话…") {
                    session.showingNewSession = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("终端") {
                Button("默认会话") {
                    session.connectLocal()
                }
                Button("新建命名会话…") {
                    session.showingNewSession = true
                }
                Button("从文件夹启动…") {
                    chooseWorkingDirectory()
                }
                .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("连接远程主机…") {
                    session.showingRemoteConnection = true
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                Divider()
                Button("临时无状态模式") {
                    session.connectStandalone()
                }
                Divider()
                Button("重新连接") { session.reconnect() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("放大字体") { session.increaseFontSize() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("缩小字体") { session.decreaseFontSize() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("恢复默认字体") { session.resetFontSize() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }

        Settings {
            TerminalSettingsView(session: session)
                .frame(width: 640)
                .padding(24)
        }
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择 Herdr 工作目录"
        panel.prompt = "在此目录打开"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        session.openWorkingDirectory(directory.path)
    }
}
