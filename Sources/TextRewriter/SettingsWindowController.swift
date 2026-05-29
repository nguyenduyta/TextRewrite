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
        editMenu.addItem(NSMenuItem(title: "Cut",   action: #selector(NSText.cut(_:)),   keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",  action: #selector(NSText.copy(_:)),  keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
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
        w.setContentSize(NSSize(width: 440, height: 340))
        w.isReleasedWhenClosed = false
        return w
    }
}

class SettingsViewController: NSViewController {
    private let s = AISettings.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 340))
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

        func row(_ label: String, _ control: NSView) {
            stack.addArrangedSubview(sectionLabel(label))
            stack.addArrangedSubview(control)
            NSLayoutConstraint.activate([control.widthAnchor.constraint(equalTo: stack.widthAnchor)])
            stack.setCustomSpacing(4, after: sectionLabel(label))
        }

        // AI Provider
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

        // Default Tone
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

        // API Keys
        for (label, placeholder, tag) in [
            ("OpenAI API Key",          "sk-...",      0),
            ("Google Gemini API Key",   "AIza...",     1),
            ("Anthropic Claude API Key","sk-ant-...",  2),
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

        let note = NSTextField(labelWithString: "Keys are stored in macOS UserDefaults.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(note)
    }

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

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let p = AIProvider(rawValue: title) {
            s.provider = p
        }
    }

    @objc private func toneChanged(_ sender: NSPopUpButton) {
        let title = sender.selectedItem?.title ?? "None"
        s.defaultTone = (title == "None") ? "" : title
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

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
