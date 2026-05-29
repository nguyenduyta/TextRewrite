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
        w.styleMask = [.titled, .closable, .resizable]
        w.setContentSize(NSSize(width: 480, height: 500))
        w.minSize = NSSize(width: 440, height: 400)
        w.isReleasedWhenClosed = false
        return w
    }
}

class SettingsViewController: NSViewController {
    private let s = AISettings.shared

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        // Outer scroll view so content is reachable on small screens
        let outerScroll = NSScrollView()
        outerScroll.hasVerticalScroller = true
        outerScroll.autohidesScrollers = true
        outerScroll.borderType = .noBorder
        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outerScroll)
        NSLayoutConstraint.activate([
            outerScroll.topAnchor.constraint(equalTo: view.topAnchor),
            outerScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        outerScroll.documentView = container

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(equalTo: outerScroll.widthAnchor),
        ])

        // Provider picker
        stack.addArrangedSubview(sectionLabel("AI Provider"))
        let picker = NSPopUpButton()
        picker.addItems(withTitles: AIProvider.allCases.map { $0.rawValue })
        picker.selectItem(withTitle: s.provider.rawValue)
        picker.target = self
        picker.action = #selector(providerChanged(_:))
        picker.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(picker)
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([picker.widthAnchor.constraint(equalTo: stack.widthAnchor)])

        stack.addArrangedSubview(sectionLabel("OpenAI API Key"))
        stack.addArrangedSubview(keyField(placeholder: "sk-...", value: s.openAIKey, tag: 0))

        stack.addArrangedSubview(sectionLabel("Google Gemini API Key"))
        stack.addArrangedSubview(keyField(placeholder: "AIza...", value: s.geminiKey, tag: 1))

        stack.addArrangedSubview(sectionLabel("Anthropic Claude API Key"))
        stack.addArrangedSubview(keyField(placeholder: "sk-ant-...", value: s.claudeKey, tag: 2))

        let note = NSTextField(wrappingLabelWithString: "Keys are stored in macOS UserDefaults (not Keychain). For better security, consider using environment variables.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(note)
        NSLayoutConstraint.activate([note.widthAnchor.constraint(equalTo: stack.widthAnchor)])
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 12, weight: .medium)
        return l
    }

    private func keyField(placeholder: String, value: String, tag: Int) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = TaggedTextView()
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 390, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        if value.isEmpty {
            textView.string = ""
            textView.setPlaceholder(placeholder)
        } else {
            textView.string = value
        }

        textView.fieldTag = tag
        textView.delegate = self

        scrollView.documentView = textView
        scrollView.heightAnchor.constraint(equalToConstant: 62).isActive = true
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return scrollView
    }

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let p = AIProvider(rawValue: title) {
            s.provider = p
        }
    }
}

class TaggedTextView: NSTextView {
    var fieldTag: Int = 0
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? TaggedTextView else { return }
        let value = tv.string
        switch tv.fieldTag {
        case 0: s.openAIKey = value
        case 1: s.geminiKey = value
        case 2: s.claudeKey = value
        default: break
        }
    }
}

extension NSTextView {
    func setPlaceholder(_ text: String) {
        let ph = NSTextField(labelWithString: text)
        ph.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        ph.textColor = .placeholderTextColor
        ph.tag = -999
        ph.isEditable = false
        ph.isSelectable = false
        ph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ph)
        NSLayoutConstraint.activate([
            ph.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            ph.topAnchor.constraint(equalTo: topAnchor, constant: 4),
        ])
    }

    func removePlaceholderIfNeeded() {
        subviews.first(where: { ($0 as? NSTextField)?.tag == -999 })?.removeFromSuperview()
    }
}
