import Foundation

struct HerdrThemeConfig: Equatable {
    let name: String?
    let autoSwitch: Bool
    let darkName: String?
    let lightName: String?

    var selectedTheme: TerminalTheme {
        TerminalTheme(rawValue: name ?? "") ?? .catppuccin
    }

    func effectiveTheme(isDark: Bool) -> TerminalTheme {
        guard autoSwitch else { return selectedTheme }
        let explicitName = isDark ? darkName : lightName
        if let explicitName, let explicitTheme = TerminalTheme(rawValue: explicitName) {
            return explicitTheme
        }
        let siblings = Self.siblingThemes(for: selectedTheme)
        return isDark ? siblings.dark : siblings.light
    }

    private static func siblingThemes(
        for theme: TerminalTheme
    ) -> (dark: TerminalTheme, light: TerminalTheme) {
        switch theme {
        case .catppuccin, .catppuccinLatte:
            (.catppuccin, .catppuccinLatte)
        case .tokyoNight, .tokyoNightDay:
            (.tokyoNight, .tokyoNightDay)
        case .gruvbox, .gruvboxLight:
            (.gruvbox, .gruvboxLight)
        case .oneDark, .oneLight:
            (.oneDark, .oneLight)
        case .solarized, .solarizedLight:
            (.solarized, .solarizedLight)
        case .kanagawa, .kanagawaLotus:
            (.kanagawa, .kanagawaLotus)
        case .rosePine, .rosePineDawn:
            (.rosePine, .rosePineDawn)
        default:
            (theme, theme)
        }
    }
}

enum HerdrConfigFile {
    static func configURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        if let explicitPath = environment["HERDR_CONFIG_PATH"], !explicitPath.isEmpty {
            return URL(fileURLWithPath: (explicitPath as NSString).expandingTildeInPath)
        }
        return homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("herdr", isDirectory: true)
            .appendingPathComponent("config.toml")
    }

    static func loadTheme(from content: String) -> HerdrThemeConfig {
        let values = sectionValues(named: "theme", in: content)
        return HerdrThemeConfig(
            name: unquoted(values["name"]),
            autoSwitch: unquoted(values["auto_switch"]) == "true",
            darkName: unquoted(values["dark_name"]),
            lightName: unquoted(values["light_name"])
        )
    }

    static func loadTheme(at url: URL = configURL()) -> HerdrThemeConfig {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return HerdrThemeConfig(
                name: nil,
                autoSwitch: false,
                darkName: nil,
                lightName: nil
            )
        }
        return loadTheme(from: content)
    }

    /// Mirrors the official settings behavior: choosing a theme writes its
    /// canonical name and disables `auto_switch`.
    static func updatingTheme(in content: String, to theme: TerminalTheme) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }

        if let range = sectionRange(named: "theme", in: lines) {
            upsert(key: "name", value: "\"\(theme.rawValue)\"", in: &lines, range: range)
            let updatedRange = sectionRange(named: "theme", in: lines) ?? range
            upsert(key: "auto_switch", value: "false", in: &lines, range: updatedRange)
        } else {
            if !lines.isEmpty && lines.last != "" { lines.append("") }
            lines += [
                "[theme]",
                "name = \"\(theme.rawValue)\"",
                "auto_switch = false"
            ]
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func saveTheme(_ theme: TerminalTheme, at url: URL = configURL()) throws {
        let fileManager = FileManager.default
        let current = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let updated = updatingTheme(in: current, to: theme)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func sectionValues(named section: String, in content: String) -> [String: String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let range = sectionRange(named: section, in: lines) else { return [:] }
        var result: [String: String] = [:]

        for line in lines[range] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            var value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if let comment = value.firstIndex(of: "#") {
                value = value[..<comment].trimmingCharacters(in: .whitespaces)
            }
            result[key] = value
        }
        return result
    }

    private static func unquoted(_ value: String?) -> String? {
        guard var value else { return nil }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\"") ||
            value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }
        return value.isEmpty ? nil : value
    }

    private static func sectionRange(named section: String, in lines: [String]) -> Range<Int>? {
        guard let start = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "[\(section)]"
        }) else { return nil }

        let firstValue = start + 1
        let end = lines[firstValue...].firstIndex(where: {
            let value = $0.trimmingCharacters(in: .whitespaces)
            return value.hasPrefix("[") && value.hasSuffix("]")
        }) ?? lines.endIndex
        return firstValue..<end
    }

    private static func upsert(
        key: String,
        value: String,
        in lines: inout [String],
        range: Range<Int>
    ) {
        if let index = range.first(where: { lineDefines(key: key, line: lines[$0]) }) {
            lines[index] = "\(key) = \(value)"
        } else {
            lines.insert("\(key) = \(value)", at: range.lowerBound)
        }
    }

    private static func lineDefines(key: String, line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { return false }
        return trimmed[..<equals].trimmingCharacters(in: .whitespaces) == key
    }
}

enum HerdrControlCommand {
    static func reloadConfigArguments(for connection: HerdrConnection) -> [String]? {
        guard connection.mode == .local else { return nil }
        var arguments: [String] = []
        if let sessionName = connection.sessionName {
            arguments += ["--session", sessionName]
        }
        arguments += ["server", "reload-config"]
        return arguments
    }

    static func run(executable: String, arguments: [String]) throws {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorText = String(data: errorOutput, encoding: .utf8) ?? ""
            let outputText = String(data: output, encoding: .utf8) ?? ""
            throw HerdrConfigError.commandFailed(
                errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? outputText
                    : errorText
            )
        }
    }
}

enum HerdrConfigError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(detail):
            let detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "Herdr 无法重载 config.toml。" : detail
        }
    }
}
