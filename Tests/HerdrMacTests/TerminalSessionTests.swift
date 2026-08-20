import AppKit
import XCTest
@testable import HerdrMac

final class TerminalSessionTests: XCTestCase {
    func testDefaultSessionUsesNoArguments() throws {
        let spec = try HerdrLaunchSpec.make(connection: .local())
        XCTAssertEqual(spec.arguments, [])
        XCTAssertTrue(spec.environment.contains("TERM=xterm-256color"))
        XCTAssertTrue(spec.environment.contains("COLORTERM=truecolor"))
    }

    func testNamedSessionUsesHerdrSessionFlag() throws {
        let spec = try HerdrLaunchSpec.make(connection: .local(sessionName: " work "))
        XCTAssertEqual(spec.arguments, ["--session", "work"])
    }

    func testRemoteConnectionUsesOfficialHerdrArguments() throws {
        let spec = try HerdrLaunchSpec.make(connection: .remote(
            target: " ssh://you@example.com:2222 ",
            sessionName: " work "
        ))
        XCTAssertEqual(spec.arguments, [
            "--remote", "ssh://you@example.com:2222",
            "--session", "work"
        ])
    }

    func testRemoteConnectionSupportsServerKeybindingsAndHandoff() throws {
        let spec = try HerdrLaunchSpec.make(connection: .remote(
            target: "workbox",
            sessionName: "review",
            keybindings: .server,
            handoff: true
        ))
        XCTAssertEqual(spec.arguments, [
            "--remote", "workbox",
            "--session", "review",
            "--remote-keybindings", "server",
            "--handoff"
        ])
    }

    func testStoredConnectionFromEarlierBuildStillDecodes() throws {
        let data = Data(#"{"mode":"remote","sessionName":"work","remoteTarget":"workbox","workingDirectory":null}"#.utf8)
        let connection = try JSONDecoder().decode(HerdrConnection.self, from: data)

        XCTAssertEqual(connection.arguments, ["--remote", "workbox", "--session", "work"])
        XCTAssertFalse(connection.handoff)
        XCTAssertNil(connection.remoteKeybindings)
    }

    func testStandaloneConnectionUsesNoSessionFlag() throws {
        let spec = try HerdrLaunchSpec.make(connection: .standalone())
        XCTAssertEqual(spec.arguments, ["--no-session"])
    }

    func testConnectionUsesRequestedWorkingDirectory() throws {
        let spec = try HerdrLaunchSpec.make(connection: .local(workingDirectory: "/private/tmp"))
        XCTAssertEqual(spec.currentDirectory, "/private/tmp")
    }

    func testOpeningDirectoryPreservesNamedLocalSession() {
        let connection = HerdrConnection.local(sessionName: "work")
            .openingLocalDirectory(" /private/tmp ")

        XCTAssertEqual(connection.mode, .local)
        XCTAssertEqual(connection.sessionName, "work")
        XCTAssertEqual(connection.workingDirectory, "/private/tmp")
    }

    func testOpeningDirectoryFromRemoteReturnsToDefaultLocalSession() {
        let connection = HerdrConnection.remote(target: "workbox", sessionName: "remote")
            .openingLocalDirectory("/private/tmp")

        XCTAssertEqual(connection.mode, .local)
        XCTAssertNil(connection.sessionName)
        XCTAssertNil(connection.remoteTarget)
        XCTAssertEqual(connection.workingDirectory, "/private/tmp")
    }

    func testSessionCatalogDecodesOfficialJSONShape() throws {
        let data = Data(#"{"sessions":[{"default":false,"name":"work","running":true,"session_dir":"/tmp/work","socket_path":"/tmp/work.sock"},{"default":true,"name":"default","running":false,"session_dir":"/tmp/default","socket_path":"/tmp/default.sock"}]}"#.utf8)
        let sessions = try HerdrSessionCatalog.decode(data)

        XCTAssertEqual(sessions.map(\.displayName), ["默认会话", "work"])
        XCTAssertNil(sessions[0].launchSessionName)
        XCTAssertEqual(sessions[1].launchSessionName, "work")
        XCTAssertTrue(sessions[1].running)
    }

    func testSessionManagementUsesOfficialCommands() {
        XCTAssertEqual(
            HerdrSessionCommand.arguments(action: .stop, sessionName: "work"),
            ["session", "stop", "work", "--json"]
        )
        XCTAssertEqual(
            HerdrSessionCommand.arguments(action: .delete, sessionName: "work"),
            ["session", "delete", "work", "--json"]
        )
    }

    func testBuiltInThemesHaveCompleteUniquePalettes() {
        XCTAssertEqual(TerminalTheme.allCases.count, 18)
        XCTAssertEqual(Set(TerminalTheme.allCases.map(\.title)).count, 18)
        XCTAssertEqual(TerminalTheme.allCases.map(\.rawValue), [
            "catppuccin", "catppuccin-latte", "terminal", "tokyo-night",
            "tokyo-night-day", "dracula", "nord", "gruvbox", "gruvbox-light",
            "one-dark", "one-light", "solarized", "solarized-light", "kanagawa",
            "kanagawa-lotus", "rose-pine", "rose-pine-dawn", "vesper"
        ])

        for theme in TerminalTheme.allCases {
            XCTAssertEqual(theme.palette.ansi.count, 16, "\(theme.title) needs 16 ANSI colors")
            XCTAssertEqual(theme.previewColors.count, 5)
        }
    }

    func testDefaultThemeMatchesOfficialCatppuccinTokens() {
        let catppuccin = TerminalTheme.catppuccin.palette

        XCTAssertEqual(catppuccin.background, ThemeRGB(0x181825))
        XCTAssertEqual(catppuccin.foreground, ThemeRGB(0xCDD6F4))
        XCTAssertEqual(catppuccin.cursor, ThemeRGB(0x89B4FA))
        XCTAssertEqual(catppuccin.selection, ThemeRGB(0x313244))
    }

    func testThemeConfigReadsOfficialThemeSection() {
        let config = HerdrConfigFile.loadTheme(from: """
        onboarding = false

        [theme]
        name = "tokyo-night"
        auto_switch = true
        dark_name = "tokyo-night"
        light_name = "tokyo-night-day"

        [ui]
        sidebar_width = 26
        """)

        XCTAssertEqual(config.name, "tokyo-night")
        XCTAssertTrue(config.autoSwitch)
        XCTAssertEqual(config.darkName, "tokyo-night")
        XCTAssertEqual(config.lightName, "tokyo-night-day")
        XCTAssertEqual(config.selectedTheme, .tokyoNight)
        XCTAssertEqual(config.effectiveTheme(isDark: true), .tokyoNight)
        XCTAssertEqual(config.effectiveTheme(isDark: false), .tokyoNightDay)
    }

    func testThemeAutoSwitchUsesOfficialSiblingFallbacks() {
        let config = HerdrThemeConfig(
            name: "rose-pine-dawn",
            autoSwitch: true,
            darkName: nil,
            lightName: nil
        )

        XCTAssertEqual(config.effectiveTheme(isDark: true), .rosePine)
        XCTAssertEqual(config.effectiveTheme(isDark: false), .rosePineDawn)

        let singleTheme = HerdrThemeConfig(
            name: "vesper",
            autoSwitch: true,
            darkName: nil,
            lightName: nil
        )
        XCTAssertEqual(singleTheme.effectiveTheme(isDark: true), .vesper)
        XCTAssertEqual(singleTheme.effectiveTheme(isDark: false), .vesper)
    }

    func testThemeConfigUpdatePreservesOtherSectionsAndDisablesAutoSwitch() {
        let original = """
        onboarding = false

        [theme]
        name = "catppuccin"
        auto_switch = true
        dark_name = "catppuccin"
        light_name = "catppuccin-latte"

        [theme.custom]
        accent = "#123456"

        [ui]
        sidebar_width = 26
        """

        let updated = HerdrConfigFile.updatingTheme(in: original, to: .rosePine)

        XCTAssertTrue(updated.contains("name = \"rose-pine\""))
        XCTAssertTrue(updated.contains("auto_switch = false"))
        XCTAssertTrue(updated.contains("[theme.custom]\naccent = \"#123456\""))
        XCTAssertTrue(updated.contains("[ui]\nsidebar_width = 26"))
    }

    func testThemeConfigCreatesMissingThemeSection() {
        let updated = HerdrConfigFile.updatingTheme(
            in: "onboarding = false\n",
            to: .catppuccinLatte
        )

        XCTAssertTrue(updated.contains("[theme]\nname = \"catppuccin-latte\"\nauto_switch = false"))
    }

    func testReloadConfigUsesCurrentNamedSession() {
        XCTAssertEqual(
            HerdrControlCommand.reloadConfigArguments(for: .local(sessionName: "work")),
            ["--session", "work", "server", "reload-config"]
        )
        XCTAssertEqual(
            HerdrControlCommand.reloadConfigArguments(for: .local()),
            ["server", "reload-config"]
        )
        XCTAssertNil(HerdrControlCommand.reloadConfigArguments(for: .remote(target: "workbox")))
        XCTAssertNil(HerdrControlCommand.reloadConfigArguments(for: .standalone()))
    }

    func testThemeRGBDecodesHexColor() {
        let color = ThemeRGB(0x12ABEF)
        XCTAssertEqual(color.red, 0x12)
        XCTAssertEqual(color.green, 0xAB)
        XCTAssertEqual(color.blue, 0xEF)
    }

    @MainActor
    func testTerminalContextMenuKeepsExpectedNativeActions() throws {
        let terminal = HerdrProcessTerminalView(frame: .zero)
        let menu = terminal.makeTerminalContextMenu()
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)

        XCTAssertEqual(titles, [
            "复制", "粘贴", "全选",
            "查找…", "查找下一个", "查找上一个",
            "清除回滚记录"
        ])

        let copyItem = try XCTUnwrap(menu.item(withTitle: "复制"))
        XCTAssertFalse(terminal.validateUserInterfaceItem(copyItem))
    }

    func testRightClickRoutesToHerdrUnlessShiftUsesNativeMenu() {
        XCTAssertFalse(HerdrProcessTerminalView.usesNativeMenu(
            modifiers: [],
            mouseReportingActive: true
        ))
        XCTAssertTrue(HerdrProcessTerminalView.usesNativeMenu(
            modifiers: [.shift],
            mouseReportingActive: true
        ))
        XCTAssertTrue(HerdrProcessTerminalView.usesNativeMenu(
            modifiers: [],
            mouseReportingActive: false
        ))
        XCTAssertTrue(HerdrProcessTerminalView.usesNativeMenu(
            modifiers: [.shift],
            mouseReportingActive: true
        ))
    }
}
