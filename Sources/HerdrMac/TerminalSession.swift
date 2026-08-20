import Foundation
import SwiftUI

enum TerminalProcessState: Equatable {
    case launching
    case running
    case exited(Int32?)

    var label: String {
        switch self {
        case .launching: "正在连接"
        case .running: "已连接"
        case .exited: "已断开"
        }
    }
}

struct HerdrLaunchSpec: Equatable {
    let executable: String
    let arguments: [String]
    let environment: [String]
    let currentDirectory: String

    static func make(connection: HerdrConnection) throws -> HerdrLaunchSpec {
        guard let executable = resolveHerdrBinary() else {
            throw TerminalLaunchError.herdrNotFound
        }

        if connection.mode == .remote && connection.remoteTarget == nil {
            throw TerminalLaunchError.invalidRemoteTarget
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let requestedDirectory = (connection.workingDirectory as NSString?)?.expandingTildeInPath
        var isDirectory: ObjCBool = false
        let currentDirectory: String
        if let requestedDirectory,
           FileManager.default.fileExists(atPath: requestedDirectory, isDirectory: &isDirectory),
           isDirectory.boolValue {
            currentDirectory = requestedDirectory
        } else {
            currentDirectory = home
        }
        var values = ProcessInfo.processInfo.environment
        let currentPath = values["PATH"] ?? ""
        values["PATH"] = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            currentPath
        ].joined(separator: ":")
        values["TERM"] = "xterm-256color"
        values["COLORTERM"] = "truecolor"
        if values["LANG"] == nil { values["LANG"] = "en_US.UTF-8" }

        return HerdrLaunchSpec(
            executable: executable,
            arguments: connection.arguments,
            environment: values.map { "\($0.key)=\($0.value)" },
            currentDirectory: currentDirectory
        )
    }

    static func resolveHerdrBinary() -> String? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = [
            ProcessInfo.processInfo.environment["HERDR_BIN_PATH"],
            "\(home)/.local/bin/herdr",
            "/opt/homebrew/bin/herdr",
            "/usr/local/bin/herdr"
        ].compactMap { $0 }
        return candidates.first(where: fileManager.isExecutableFile(atPath:))
    }
}

enum TerminalLaunchError: LocalizedError {
    case herdrNotFound
    case invalidRemoteTarget

    var errorDescription: String? {
        switch self {
        case .herdrNotFound:
            "没有找到 herdr 命令。请先安装 Herdr，或设置 HERDR_BIN_PATH。"
        case .invalidRemoteTarget:
            "远程 SSH 目标不能为空。"
        }
    }
}

@MainActor
final class TerminalSessionModel: ObservableObject {
    @Published private(set) var processState: TerminalProcessState = .launching
    @Published private(set) var terminalTitle = "Herdr"
    @Published private(set) var currentDirectory: String?
    @Published private(set) var availableSessions: [HerdrSessionDescriptor] = []
    @Published private(set) var recentRemoteTargets: [String]
    @Published private(set) var connection: HerdrConnection
    @Published private(set) var launchError: String?
    @Published var sessionCommandError: String?
    @Published var showingNewSession = false
    @Published var showingRemoteConnection = false
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Keys.fontSize) }
    }
    @Published private(set) var theme: TerminalTheme
    @Published private(set) var themeAutoSwitch: Bool
    @Published var optionAsMeta: Bool {
        didSet { UserDefaults.standard.set(optionAsMeta, forKey: Keys.optionAsMeta) }
    }
    @Published var useMetal: Bool {
        didSet { UserDefaults.standard.set(useMetal, forKey: Keys.useMetal) }
    }
    @Published private(set) var restartGeneration = 0

    var sessionName: String? { connection.sessionName }
    var displayConnectionName: String { connection.displayName }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.connection),
           let storedConnection = try? JSONDecoder().decode(HerdrConnection.self, from: data) {
            self.connection = storedConnection
        } else {
            let storedName = defaults.string(forKey: Keys.sessionName) ?? ""
            self.connection = .local(sessionName: storedName)
        }
        self.recentRemoteTargets = defaults.stringArray(forKey: Keys.recentRemoteTargets) ?? []
        let storedSize = defaults.double(forKey: Keys.fontSize)
        self.fontSize = storedSize == 0 ? 13.5 : storedSize
        let themeConfig = HerdrConfigFile.loadTheme()
        self.themeAutoSwitch = themeConfig.autoSwitch
        self.theme = themeConfig.effectiveTheme(
            isDark: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        )
        self.optionAsMeta = defaults.object(forKey: Keys.optionAsMeta) as? Bool ?? true
        self.useMetal = defaults.object(forKey: Keys.useMetal) as? Bool ?? true
        refreshAvailableSessions()
    }

    func switchSession(to name: String?) {
        connectLocal(sessionName: name)
    }

    func createSession(named name: String) {
        connectLocal(sessionName: name)
        showingNewSession = false
    }

    func connectLocal(sessionName: String? = nil, workingDirectory: String? = nil) {
        setConnection(.local(sessionName: sessionName, workingDirectory: workingDirectory))
    }

    func connectRemote(
        target: String,
        sessionName: String? = nil,
        keybindings: HerdrRemoteKeybindings = .local,
        handoff: Bool = false
    ) {
        let connection = HerdrConnection.remote(
            target: target,
            sessionName: sessionName,
            keybindings: keybindings,
            handoff: handoff
        )
        guard let normalizedTarget = connection.remoteTarget else { return }

        recentRemoteTargets.removeAll { $0 == normalizedTarget }
        recentRemoteTargets.insert(normalizedTarget, at: 0)
        recentRemoteTargets = Array(recentRemoteTargets.prefix(8))
        UserDefaults.standard.set(recentRemoteTargets, forKey: Keys.recentRemoteTargets)
        setConnection(connection)
        showingRemoteConnection = false
    }

    func connectStandalone(workingDirectory: String? = nil) {
        setConnection(.standalone(workingDirectory: workingDirectory))
    }

    func stopSession(_ descriptor: HerdrSessionDescriptor) {
        performSessionAction(.stop, descriptor: descriptor)
    }

    func deleteSession(_ descriptor: HerdrSessionDescriptor) {
        performSessionAction(.delete, descriptor: descriptor)
    }

    func reconnect() {
        launchError = nil
        processState = .launching
        restartGeneration += 1
    }

    func increaseFontSize() { fontSize = min(28, fontSize + 1) }
    func decreaseFontSize() { fontSize = max(9, fontSize - 1) }
    func resetFontSize() { fontSize = 13.5 }

    func selectTheme(_ theme: TerminalTheme) {
        guard theme != self.theme || themeAutoSwitch else { return }
        themeAutoSwitch = false
        self.theme = theme

        guard let executable = HerdrLaunchSpec.resolveHerdrBinary() else {
            sessionCommandError = TerminalLaunchError.herdrNotFound.localizedDescription
            return
        }

        sessionCommandError = nil
        let connection = connection
        let task = Task.detached(priority: .userInitiated) {
            try HerdrConfigFile.saveTheme(theme)
            guard let arguments = HerdrControlCommand.reloadConfigArguments(for: connection) else {
                return true
            }
            try HerdrControlCommand.run(executable: executable, arguments: arguments)
            return false
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let requiresReconnect = try await task.value
                if requiresReconnect {
                    self.reconnect()
                }
            } catch {
                self.sessionCommandError = error.localizedDescription
            }
        }
    }

    func syncThemeWithHostAppearance(_ colorScheme: ColorScheme) {
        guard themeAutoSwitch else { return }
        let config = HerdrConfigFile.loadTheme()
        theme = config.effectiveTheme(isDark: colorScheme == .dark)
    }

    var preferredColorScheme: ColorScheme? {
        themeAutoSwitch ? nil : theme.preferredColorScheme
    }

    func markRunning() {
        launchError = nil
        processState = .running
    }

    func markExited(code: Int32?) {
        processState = .exited(code)
    }

    func markLaunchFailed(_ error: Error) {
        launchError = error.localizedDescription
        processState = .exited(nil)
    }

    func updateTerminalTitle(_ title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        terminalTitle = cleaned.isEmpty ? "Herdr" : cleaned
    }

    func updateCurrentDirectory(_ directory: String?) {
        currentDirectory = directory
    }

    func refreshAvailableSessions() {
        guard let executable = HerdrLaunchSpec.resolveHerdrBinary() else {
            availableSessions = []
            return
        }

        let loader = Task.detached(priority: .utility) {
            try HerdrSessionCatalog.load(executable: executable)
        }
        Task { [weak self] in
            guard let self else { return }
            if let sessions = try? await loader.value {
                self.availableSessions = sessions
            }
        }
    }

    private func setConnection(_ connection: HerdrConnection) {
        self.connection = connection
        if let data = try? JSONEncoder().encode(connection) {
            UserDefaults.standard.set(data, forKey: Keys.connection)
        }
        reconnect()
        refreshAvailableSessions()
    }

    private func performSessionAction(
        _ action: HerdrSessionAction,
        descriptor: HerdrSessionDescriptor
    ) {
        guard let executable = HerdrLaunchSpec.resolveHerdrBinary() else {
            sessionCommandError = TerminalLaunchError.herdrNotFound.localizedDescription
            return
        }

        sessionCommandError = nil
        let task = Task.detached(priority: .userInitiated) {
            try HerdrSessionCommand.run(
                executable: executable,
                action: action,
                sessionName: descriptor.name
            )
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await task.value
                self.refreshAvailableSessions()
            } catch {
                self.sessionCommandError = error.localizedDescription
            }
        }
    }

    private enum Keys {
        static let sessionName = "terminal.sessionName"
        static let connection = "terminal.connection"
        static let recentRemoteTargets = "terminal.recentRemoteTargets"
        static let fontSize = "terminal.fontSize"
        static let optionAsMeta = "terminal.optionAsMeta"
        static let useMetal = "terminal.useMetal"
    }
}
