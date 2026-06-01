import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = SelectionMonitor.shared
    private let buttonPanel = FloatingButtonPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        setupMenuBar()
        setupMonitor()
        setupHotkey()
    }

    private func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            if let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Text Rewriter") {
                btn.image = img
            } else {
                btn.title = "✦"
            }
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Text Rewriter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func setupMonitor() {
        monitor.onTextSelected = { [weak self] text, point in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let current = SelectionMonitor.shared.currentText
                guard !current.isEmpty, !AISettings.shared.hotkeyEnabled else { return }
                self?.buttonPanel.show(near: point, with: current)
            }
        }
        monitor.onSelectionCleared = { [weak self] in
            DispatchQueue.main.async {
                self?.buttonPanel.hide()
            }
        }
        monitor.start()
    }

    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.buttonPanel.triggerWithCurrentSelection()
        }
        refreshHotkey()
    }

    func refreshHotkey() {
        let s = AISettings.shared
        if s.hotkeyEnabled, s.hotkeyKeyCode > 0 {
            let mods = NSEvent.ModifierFlags(rawValue: s.hotkeyModifiers)
            HotkeyManager.shared.register(
                keyCode: UInt32(s.hotkeyKeyCode),
                carbonModifiers: HotkeyManager.carbonModifiers(from: mods)
            )
        } else {
            HotkeyManager.shared.unregister()
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}
