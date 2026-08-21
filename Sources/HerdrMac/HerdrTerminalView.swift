import AppKit
import SwiftTerm
import SwiftUI

struct HerdrTerminalView: NSViewRepresentable {
    @ObservedObject var session: TerminalSessionModel

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = HerdrProcessTerminalView(frame: .zero)
        terminal.processDelegate = context.coordinator
        terminal.allowMouseReporting = true
        terminal.customBlockGlyphs = true
        terminal.antiAliasCustomBlockGlyphs = true
        terminal.useBrightColors = true
        terminal.linkReporting = .implicit
        terminal.metalBufferingMode = .perFrameAggregated
        terminal.onFirstOutput = { [weak coordinator = context.coordinator, weak terminal] in
            coordinator?.markReady(terminal: terminal)
        }
        context.coordinator.applyAppearance(to: terminal, session: session)

        DispatchQueue.main.async {
            context.coordinator.startIfNeeded(terminal: terminal, session: session)
            terminal.requestKeyboardFocus()
        }
        return terminal
    }

    func updateNSView(_ terminal: LocalProcessTerminalView, context: Context) {
        context.coordinator.applyAppearance(to: terminal, session: session)
        context.coordinator.startIfNeeded(terminal: terminal, session: session)
    }

    static func dismantleNSView(_ terminal: LocalProcessTerminalView, coordinator: Coordinator) {
        terminal.terminate()
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        private nonisolated(unsafe) weak var session: TerminalSessionModel?
        private var startedGeneration: Int?
        private var activeTerminalID: ObjectIdentifier?
        private var appearanceTerminalID: ObjectIdentifier?
        private var appliedTheme: TerminalTheme?

        init(session: TerminalSessionModel) {
            self.session = session
        }

        @MainActor
        func startIfNeeded(terminal: LocalProcessTerminalView, session: TerminalSessionModel) {
            let terminalID = ObjectIdentifier(terminal)
            guard startedGeneration != session.restartGeneration || activeTerminalID != terminalID else { return }

            if terminal.process.running {
                terminal.terminate()
            }
            startedGeneration = session.restartGeneration
            activeTerminalID = terminalID
            do {
                let spec = try HerdrLaunchSpec.make(connection: session.connection)
                if let terminal = terminal as? HerdrProcessTerminalView {
                    terminal.resetOutputReadiness()
                }
                terminal.getTerminal().resetToInitialState()
                terminal.startProcess(
                    executable: spec.executable,
                    args: spec.arguments,
                    environment: spec.environment,
                    execName: "herdr",
                    currentDirectory: spec.currentDirectory
                )
                DispatchQueue.main.async {
                    if session.useMetal && !terminal.isUsingMetalRenderer {
                        try? terminal.setUseMetal(true)
                    } else if !session.useMetal && terminal.isUsingMetalRenderer {
                        try? terminal.setUseMetal(false)
                    }
                    if let terminal = terminal as? HerdrProcessTerminalView {
                        terminal.requestKeyboardFocus()
                    } else {
                        terminal.window?.makeFirstResponder(terminal)
                    }
                }
            } catch {
                session.markLaunchFailed(error)
            }
        }

        @MainActor
        func markReady(terminal: HerdrProcessTerminalView?) {
            session?.markRunning()
            terminal?.requestKeyboardFocus()
        }

        @MainActor
        func applyAppearance(to terminal: LocalProcessTerminalView, session: TerminalSessionModel) {
            let font = NSFont(name: "SFMono-Regular", size: session.fontSize)
                ?? NSFont.monospacedSystemFont(ofSize: session.fontSize, weight: .regular)
            if terminal.font != font { terminal.font = font }
            terminal.optionAsMetaKey = session.optionAsMeta

            let palette = session.theme.palette
            let terminalID = ObjectIdentifier(terminal)
            if appliedTheme != session.theme || appearanceTerminalID != terminalID {
                terminal.installColors(palette.ansi.map(\.terminalColor))
                appliedTheme = session.theme
                appearanceTerminalID = terminalID
            }

            let background = palette.background.nsColor
            let foreground = palette.foreground.nsColor
            terminal.nativeBackgroundColor = background
            terminal.nativeForegroundColor = foreground
            terminal.caretColor = palette.cursor.nsColor
            terminal.layer?.backgroundColor = background.cgColor
            terminal.selectedTextBackgroundColor = palette.selection.nsColor

            DispatchQueue.main.async {
                if session.useMetal != terminal.isUsingMetalRenderer {
                    try? terminal.setUseMetal(session.useMetal)
                }
                terminal.needsDisplay = true
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            Task { @MainActor [weak session] in
                session?.updateTerminalTitle(title)
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            Task { @MainActor [weak session] in
                session?.updateCurrentDirectory(directory)
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            Task { @MainActor [weak session] in
                session?.markExited(code: exitCode)
            }
        }
    }
}

private extension ThemeRGB {
    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    var terminalColor: SwiftTerm.Color {
        SwiftTerm.Color(red8: UInt16(red), green8: UInt16(green), blue8: UInt16(blue))
    }
}
