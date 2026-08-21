import AppKit
import SwiftTerm

final class HerdrProcessTerminalView: LocalProcessTerminalView {
    private var reportingRightClick = false
    private var hasReportedFirstOutput = false
    private weak var observedWindow: NSWindow?
    var onFirstOutput: (() -> Void)?

    deinit {
        stopObservingWindow()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard observedWindow !== window else { return }
        stopObservingWindow()
        observedWindow = window
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            requestKeyboardFocus()
        }
    }

    func requestKeyboardFocus() {
        window?.makeFirstResponder(self)
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    func resetOutputReadiness() {
        hasReportedFirstOutput = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, bounds.contains(point) else { return nil }
        let hit = super.hitTest(point)
        if hit is NSScroller || hit is NSTextView {
            return hit
        }
        return self
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        guard !hasReportedFirstOutput, !slice.isEmpty else { return }

        hasReportedFirstOutput = true
        DispatchQueue.main.async { [weak self] in
            self?.onFirstOutput?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        requestKeyboardFocus()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        requestKeyboardFocus()
        let terminal = getTerminal()
        let mouseReportingActive = allowMouseReporting && terminal.mouseMode != .off

        if Self.usesNativeMenu(
            modifiers: event.modifierFlags,
            mouseReportingActive: mouseReportingActive
        ) {
            reportingRightClick = false
            NSMenu.popUpContextMenu(makeTerminalContextMenu(), with: event, for: self)
            return
        }

        reportingRightClick = true
        sendRightMouseEvent(event, release: false)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard reportingRightClick else { return }
        defer { reportingRightClick = false }

        if getTerminal().mouseMode != .x10 {
            sendRightMouseEvent(event, release: true)
        }
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard reportingRightClick else { return }

        let terminal = getTerminal()
        guard terminal.mouseMode == .buttonEventTracking || terminal.mouseMode == .anyEvent else {
            return
        }

        sendMouseMotion(event, button: 2)
    }

    static func usesNativeMenu(
        modifiers: NSEvent.ModifierFlags,
        mouseReportingActive: Bool
    ) -> Bool {
        modifiers.contains(.shift) || !mouseReportingActive
    }

    func makeTerminalContextMenu() -> NSMenu {
        let menu = NSMenu(title: "终端")
        menu.autoenablesItems = true

        menu.addItem(
            title: "复制",
            action: #selector(copy(_:)),
            keyEquivalent: "c",
            target: self
        )
        menu.addItem(
            title: "粘贴",
            action: #selector(paste(_:)),
            keyEquivalent: "v",
            target: self
        )
        menu.addItem(
            title: "全选",
            action: #selector(selectAll(_:)),
            keyEquivalent: "a",
            target: self
        )

        menu.addItem(.separator())

        let find = menu.addItem(
            title: "查找…",
            action: #selector(performFindPanelAction(_:)),
            keyEquivalent: "f",
            target: self
        )
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)

        let findNext = menu.addItem(
            title: "查找下一个",
            action: #selector(performFindPanelAction(_:)),
            keyEquivalent: "g",
            target: self
        )
        findNext.tag = Int(NSFindPanelAction.next.rawValue)

        let findPrevious = menu.addItem(
            title: "查找上一个",
            action: #selector(performFindPanelAction(_:)),
            keyEquivalent: "g",
            target: self
        )
        findPrevious.keyEquivalentModifierMask = [.command, .shift]
        findPrevious.tag = Int(NSFindPanelAction.previous.rawValue)

        menu.addItem(.separator())

        menu.addItem(
            title: "清除回滚记录",
            action: #selector(clearScrollbackFromMenu(_:)),
            keyEquivalent: "",
            target: self
        )

        return menu
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        requestKeyboardFocus()
    }

    private func stopObservingWindow() {
        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didBecomeKeyNotification,
                object: observedWindow
            )
        }
        observedWindow = nil
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(clearScrollbackFromMenu(_:)) {
            return true
        }
        if item.action == #selector(paste(_:)) {
            return NSPasteboard.general.canReadItem(withDataConformingToTypes: ["public.utf8-plain-text"])
        }
        return super.validateUserInterfaceItem(item)
    }

    @objc private func clearScrollbackFromMenu(_ sender: Any?) {
        clearScrollback()
        needsDisplay = true
    }

    private func sendRightMouseEvent(_ event: NSEvent, release: Bool) {
        sendMouseEvent(event, button: 2, release: release)
    }

    private func sendMouseEvent(_ event: NSEvent, button: Int, release: Bool) {
        let hit = mouseHit(for: event)
        getTerminal().sendEvent(
            buttonFlags: encodedButton(for: event, button: button, release: release),
            x: hit.column,
            y: hit.row,
            pixelX: hit.pixelX,
            pixelY: hit.pixelY
        )
    }

    private func sendMouseMotion(_ event: NSEvent, button: Int) {
        let hit = mouseHit(for: event)
        getTerminal().sendMotion(
            buttonFlags: encodedButton(for: event, button: button, release: false),
            x: hit.column,
            y: hit.row,
            pixelX: hit.pixelX,
            pixelY: hit.pixelY
        )
    }

    private func encodedButton(for event: NSEvent, button: Int, release: Bool) -> Int {
        let modifiers = event.modifierFlags
        return getTerminal().encodeButton(
            button: button,
            release: release,
            shift: modifiers.contains(.shift),
            meta: modifiers.contains(.option),
            control: modifiers.contains(.control)
        )
    }

    private func mouseHit(for event: NSEvent) -> MouseHit {
        let terminal = getTerminal()
        let columns = max(1, terminal.cols)
        let rows = max(1, terminal.rows)
        let point = convert(event.locationInWindow, from: nil)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let windowSize = getWindowSize()
        let cellWidth = max(1, CGFloat(windowSize.ws_xpixel) / CGFloat(columns) / scale)
        let cellHeight = max(1, CGFloat(windowSize.ws_ypixel) / CGFloat(rows) / scale)
        let column = min(max(0, Int(point.x / cellWidth)), columns - 1)
        let row = min(max(0, Int((bounds.height - point.y) / cellHeight)), rows - 1)
        let pixelX = Int(min(max(0, point.x), bounds.width))
        let pixelY = Int(min(max(0, bounds.height - point.y), bounds.height))

        return MouseHit(column: column, row: row, pixelX: pixelX, pixelY: pixelY)
    }

    private struct MouseHit {
        let column: Int
        let row: Int
        let pixelX: Int
        let pixelY: Int
    }
}

private extension NSMenu {
    @discardableResult
    func addItem(
        title: String,
        action: Selector,
        keyEquivalent: String,
        target: AnyObject
    ) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}
