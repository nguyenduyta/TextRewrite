import AppKit

class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() { super.init() }

    func showWindow() {
        if window == nil { window = buildWindow() }
        setupMainMenu()
        window?.center()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.delegate = self
    }

    private func setupMainMenu() {
        guard NSApp.mainMenu == nil || NSApp.mainMenu?.items.count == 1 else { return }
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut",        action: #selector(NSText.cut(_:)),       keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",       action: #selector(NSText.copy(_:)),      keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",      action: #selector(NSText.paste(_:)),     keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() -> NSWindow {
        let vc = SettingsViewController()
        let w = NSWindow(contentViewController: vc)
        w.title = "Text Rewriter — Settings"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 440, height: 420))
        w.isReleasedWhenClosed = false
        return w
    }
}

// MARK: - ViewController

class SettingsViewController: NSViewController {
    private let s = AISettings.shared
    private var recorderRow: NSView?
    private var recorder: HotkeyRecorderButton?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private static let tones = ["None", "Professional", "Casual", "Enthusiastic", "Informational", "Funny"]

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        // ── AI Provider ──────────────────────────────────────────────
        let providerPicker = NSPopUpButton()
        providerPicker.addItems(withTitles: AIProvider.allCases.map { $0.rawValue })
        providerPicker.selectItem(withTitle: s.provider.rawValue)
        providerPicker.target = self; providerPicker.action = #selector(providerChanged(_:))
        providerPicker.translatesAutoresizingMaskIntoConstraints = false

        let lProvider = sectionLabel("AI Provider")
        stack.addArrangedSubview(lProvider)
        stack.addArrangedSubview(providerPicker)
        NSLayoutConstraint.activate([providerPicker.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        stack.setCustomSpacing(4, after: lProvider)
        stack.setCustomSpacing(14, after: providerPicker)

        // ── Default Tone ─────────────────────────────────────────────
        let tonePicker = NSPopUpButton()
        tonePicker.addItems(withTitles: SettingsViewController.tones)
        let savedTone = s.defaultTone.isEmpty ? "None" : s.defaultTone
        tonePicker.selectItem(withTitle: savedTone)
        tonePicker.target = self; tonePicker.action = #selector(toneChanged(_:))
        tonePicker.translatesAutoresizingMaskIntoConstraints = false

        let lTone = sectionLabel("Default Tone")
        stack.addArrangedSubview(lTone)
        stack.addArrangedSubview(tonePicker)
        NSLayoutConstraint.activate([tonePicker.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        stack.setCustomSpacing(4, after: lTone)
        stack.setCustomSpacing(14, after: tonePicker)

        // ── Hotkey ───────────────────────────────────────────────────
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(divider)
        NSLayoutConstraint.activate([divider.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        stack.setCustomSpacing(10, after: divider)

        let hotkeyToggle = NSButton(checkboxWithTitle: "  Enable hotkey to trigger button", target: self, action: #selector(hotkeyToggleChanged(_:)))
        hotkeyToggle.state = s.hotkeyEnabled ? .on : .off
        hotkeyToggle.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(hotkeyToggle)
        stack.setCustomSpacing(8, after: hotkeyToggle)

        // Hotkey recorder row
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let lHotkey = sectionLabel("Shortcut")
        lHotkey.setContentHuggingPriority(.required, for: .horizontal)

        let rec = HotkeyRecorderButton()
        if s.hotkeyKeyCode > 0 {
            let mods = NSEvent.ModifierFlags(rawValue: s.hotkeyModifiers)
            rec.display(keyCode: s.hotkeyKeyCode, modifiers: mods)
        }
        rec.onRecorded = { [weak self] keyCode, modifiers in
            guard let self else { return }
            self.s.hotkeyKeyCode = keyCode
            self.s.hotkeyModifiers = modifiers.rawValue
            self.recorder?.display(keyCode: keyCode, modifiers: modifiers)
            (NSApp.delegate as? AppDelegate)?.refreshHotkey()
        }
        rec.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([rec.widthAnchor.constraint(greaterThanOrEqualToConstant: 130)])

        row.addArrangedSubview(lHotkey)
        row.addArrangedSubview(rec)

        stack.addArrangedSubview(row)
        NSLayoutConstraint.activate([row.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        stack.setCustomSpacing(14, after: row)

        row.isHidden = !s.hotkeyEnabled
        self.recorderRow = row
        self.recorder = rec

        // ── API Keys ─────────────────────────────────────────────────
        for (label, placeholder, tag) in [
            ("OpenAI API Key",           "sk-...",     0),
            ("Google Gemini API Key",    "AIza...",    1),
            ("Anthropic Claude API Key", "sk-ant-...", 2),
        ] {
            let value = [s.openAIKey, s.geminiKey, s.claudeKey][tag]
            let l = sectionLabel(label)
            let f = keyField(placeholder: placeholder, value: value, tag: tag)
            stack.addArrangedSubview(l)
            stack.addArrangedSubview(f)
            NSLayoutConstraint.activate([f.widthAnchor.constraint(equalTo: stack.widthAnchor)])
            stack.setCustomSpacing(4, after: l)
            stack.setCustomSpacing(10, after: f)
        }

        let note = NSTextField(labelWithString: "API keys are stored securely in macOS Keychain.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(note)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 12, weight: .medium)
        return l
    }

    private func keyField(placeholder: String, value: String, tag: Int) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.placeholderString = placeholder
        field.stringValue = value
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.tag = tag
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    // MARK: - Actions

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let p = AIProvider(rawValue: title) {
            s.provider = p
        }
    }

    @objc private func toneChanged(_ sender: NSPopUpButton) {
        let title = sender.selectedItem?.title ?? "None"
        s.defaultTone = (title == "None") ? "" : title
    }

    @objc private func hotkeyToggleChanged(_ sender: NSButton) {
        s.hotkeyEnabled = sender.state == .on
        recorderRow?.isHidden = !s.hotkeyEnabled
        (NSApp.delegate as? AppDelegate)?.refreshHotkey()
    }
}

// MARK: - NSWindowDelegate

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NSTextFieldDelegate

extension SettingsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let value = field.stringValue
        switch field.tag {
        case 0: s.openAIKey = value
        case 1: s.geminiKey = value
        case 2: s.claudeKey = value
        default: break
        }
    }
}

// MARK: - HotkeyRecorderButton

class HotkeyRecorderButton: NSButton {
    var onRecorded: ((Int, NSEvent.ModifierFlags) -> Void)?
    private var keyMonitor: Any?
    private(set) var isRecording = false

    init() {
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        bezelStyle = .roundRect
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 26).isActive = true
        target = self
        action = #selector(clicked)
        displayPlaceholder()
        updateBorder()
    }

    @objc private func clicked() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        updateBorder()
        setAttr("Press shortcut…", color: .secondaryLabelColor, size: 12)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        updateBorder()
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func handleKey(_ event: NSEvent) {
        if event.keyCode == 53 { stopRecording(); displayPlaceholder(); return }  // Escape
        let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !mods.isEmpty else { return }
        onRecorded?(Int(event.keyCode), mods)
        stopRecording()
    }

    func display(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        setAttr(HotkeyManager.display(keyCode: keyCode, modifiers: modifiers),
                color: .labelColor, size: 13, mono: true)
    }

    func displayPlaceholder() {
        setAttr("Click to record…", color: .tertiaryLabelColor, size: 12)
    }

    private func setAttr(_ text: String, color: NSColor, size: CGFloat, mono: Bool = false) {
        let font: NSFont = mono
            ? .monospacedSystemFont(ofSize: size, weight: .medium)
            : .systemFont(ofSize: size)
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
        ])
    }

    private func updateBorder() {
        layer?.borderColor = isRecording
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
    }
}
