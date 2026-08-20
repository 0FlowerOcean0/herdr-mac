import Foundation

enum HerdrConnectionMode: String, Codable {
    case local
    case remote
    case standalone
}

enum HerdrRemoteKeybindings: String, Codable, CaseIterable, Identifiable {
    case local
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "使用本机按键绑定"
        case .server: "使用远程按键绑定"
        }
    }
}

struct HerdrConnection: Codable, Equatable {
    let mode: HerdrConnectionMode
    let sessionName: String?
    let remoteTarget: String?
    let workingDirectory: String?
    let remoteKeybindings: HerdrRemoteKeybindings?
    let handoff: Bool

    static func local(sessionName: String? = nil, workingDirectory: String? = nil) -> HerdrConnection {
        HerdrConnection(
            mode: .local,
            sessionName: normalized(sessionName),
            remoteTarget: nil,
            workingDirectory: normalized(workingDirectory),
            remoteKeybindings: nil,
            handoff: false
        )
    }

    static func remote(
        target: String,
        sessionName: String? = nil,
        workingDirectory: String? = nil,
        keybindings: HerdrRemoteKeybindings = .local,
        handoff: Bool = false
    ) -> HerdrConnection {
        HerdrConnection(
            mode: .remote,
            sessionName: normalized(sessionName),
            remoteTarget: normalized(target),
            workingDirectory: normalized(workingDirectory),
            remoteKeybindings: keybindings,
            handoff: handoff
        )
    }

    static func standalone(workingDirectory: String? = nil) -> HerdrConnection {
        HerdrConnection(
            mode: .standalone,
            sessionName: nil,
            remoteTarget: nil,
            workingDirectory: normalized(workingDirectory),
            remoteKeybindings: nil,
            handoff: false
        )
    }

    var arguments: [String] {
        switch mode {
        case .local:
            guard let sessionName else { return [] }
            return ["--session", sessionName]
        case .remote:
            guard let remoteTarget else { return [] }
            var arguments = ["--remote", remoteTarget]
            if let sessionName {
                arguments += ["--session", sessionName]
            }
            if remoteKeybindings == .server {
                arguments += ["--remote-keybindings", "server"]
            }
            if handoff {
                arguments.append("--handoff")
            }
            return arguments
        case .standalone:
            return ["--no-session"]
        }
    }

    var displayName: String {
        switch mode {
        case .local:
            sessionName ?? "默认会话"
        case .remote:
            if let sessionName {
                "\(remoteTarget ?? "远程") · \(sessionName)"
            } else {
                remoteTarget ?? "远程会话"
            }
        case .standalone:
            "临时无状态"
        }
    }

    var systemImage: String {
        switch mode {
        case .local: "rectangle.connected.to.line.below"
        case .remote: "network"
        case .standalone: "terminal"
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private init(
        mode: HerdrConnectionMode,
        sessionName: String?,
        remoteTarget: String?,
        workingDirectory: String?,
        remoteKeybindings: HerdrRemoteKeybindings?,
        handoff: Bool
    ) {
        self.mode = mode
        self.sessionName = sessionName
        self.remoteTarget = remoteTarget
        self.workingDirectory = workingDirectory
        self.remoteKeybindings = remoteKeybindings
        self.handoff = handoff
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case sessionName
        case remoteTarget
        case workingDirectory
        case remoteKeybindings
        case handoff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(HerdrConnectionMode.self, forKey: .mode)
        sessionName = try container.decodeIfPresent(String.self, forKey: .sessionName)
        remoteTarget = try container.decodeIfPresent(String.self, forKey: .remoteTarget)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        remoteKeybindings = try container.decodeIfPresent(
            HerdrRemoteKeybindings.self,
            forKey: .remoteKeybindings
        )
        handoff = try container.decodeIfPresent(Bool.self, forKey: .handoff) ?? false
    }
}

struct HerdrSessionDescriptor: Codable, Equatable, Identifiable {
    let name: String
    let isDefault: Bool
    let running: Bool
    let sessionDirectory: String
    let socketPath: String

    var id: String { name }
    var launchSessionName: String? { isDefault ? nil : name }
    var displayName: String { isDefault ? "默认会话" : name }

    private enum CodingKeys: String, CodingKey {
        case name
        case isDefault = "default"
        case running
        case sessionDirectory = "session_dir"
        case socketPath = "socket_path"
    }
}

struct HerdrSessionList: Codable, Equatable {
    let sessions: [HerdrSessionDescriptor]
}

enum HerdrSessionCatalog {
    static func decode(_ data: Data) throws -> [HerdrSessionDescriptor] {
        try JSONDecoder().decode(HerdrSessionList.self, from: data).sessions.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func load(executable: String) throws -> [HerdrSessionDescriptor] {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["session", "list", "--json"]
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errorOutput, encoding: .utf8) ?? ""
            throw HerdrSessionCatalogError.commandFailed(detail)
        }
        return try decode(output)
    }
}

enum HerdrSessionCatalogError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "无法读取 Herdr 会话列表。" : trimmed
        }
    }
}

enum HerdrSessionAction: String {
    case stop
    case delete
}

enum HerdrSessionCommand {
    static func arguments(
        action: HerdrSessionAction,
        sessionName: String
    ) -> [String] {
        ["session", action.rawValue, sessionName, "--json"]
    }

    static func run(
        executable: String,
        action: HerdrSessionAction,
        sessionName: String
    ) throws {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments(action: action, sessionName: sessionName)
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorText = String(data: errorOutput, encoding: .utf8) ?? ""
            let outputText = String(data: output, encoding: .utf8) ?? ""
            throw HerdrSessionCatalogError.commandFailed(
                errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? outputText
                    : errorText
            )
        }
    }
}
