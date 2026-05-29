import AppKit
import ApplicationServices


class ResultPanel: NSPanel {
    private let textView      = NSTextView()
    private let statusLabel   = NSTextField(labelWithString: "")
    private let rewriteBtn    = NSButton()
    private let replaceBtn    = NSButton()
    private let regenBtn      = NSButton()
    private let copyBtn       = NSButton()
    private var toneButtons:  [NSButton] = []
    private var selectedTone: String? = nil

    var savedElement: AXUIElement?
    var savedRange: CFRange = CFRange(location: kCFNotFound, length: 0)
    private var originalText: String = ""

    private static let tones = ["Professional", "Casual", "Enthusiastic", "Informational", "Funny"]

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setupUI()
    }

    // MARK: - UI

    private func setupUI() {
        let bg = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 360))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 0.97).cgColor
        bg.layer?.cornerRadius = 14
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        contentView = bg

        // Header
        let headerLabel = NSTextField(labelWithString: "Here is another way of writing this")
        headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        headerLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let badge = makeBadge("AI generated")
        badge.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = makeIconButton("xmark", size: 11, tint: NSColor.white.withAlphaComponent(0.5))
        closeBtn.target = self; closeBtn.action = #selector(closeTapped)

        bg.addSubview(headerLabel)
        bg.addSubview(badge)
        bg.addSubview(closeBtn)

        // Text area
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .white
        textView.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 8
        scrollView.documentView = textView
        bg.addSubview(scrollView)

        // Tone pills row
        let toneScroll = NSScrollView()
        toneScroll.hasHorizontalScroller = false
        toneScroll.hasVerticalScroller = false
        toneScroll.drawsBackground = false
        toneScroll.borderType = .noBorder
        toneScroll.translatesAutoresizingMaskIntoConstraints = false

        let toneStack = NSStackView()
        toneStack.orientation = .horizontal
        toneStack.spacing = 6
        toneStack.translatesAutoresizingMaskIntoConstraints = false

        for tone in ResultPanel.tones {
            let btn = makeTonePill(tone)
            toneButtons.append(btn)
            toneStack.addArrangedSubview(btn)
        }
        toneScroll.documentView = toneStack
        bg.addSubview(toneScroll)

        // Status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        bg.addSubview(statusLabel)

        // Bottom bar
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(divider)

        let closeBtnBottom = makeIconButton("xmark", size: 12, tint: NSColor.white.withAlphaComponent(0.6))
        closeBtnBottom.target = self; closeBtnBottom.action = #selector(closeTapped)

        configureBarBtn(regenBtn, icon: "arrow.clockwise", title: "", primary: false)
        regenBtn.toolTip = "Regenerate"
        regenBtn.target = self; regenBtn.action = #selector(regenerateTapped)

        configureBarBtn(copyBtn, icon: "doc.on.doc", title: "", primary: false)
        copyBtn.toolTip = "Copy"
        copyBtn.target = self; copyBtn.action = #selector(copyTapped)

        configureBarBtn(replaceBtn, icon: nil, title: "Replace", primary: true)
        replaceBtn.target = self; replaceBtn.action = #selector(replaceTapped)

        configureBarBtn(rewriteBtn, icon: nil, title: "Rewrite", primary: false)
        rewriteBtn.target = self; rewriteBtn.action = #selector(rewriteWithToneTapped)

        let bottomStack = NSStackView(views: [closeBtnBottom, flexSpacer(), statusLabel, regenBtn, copyBtn, replaceBtn, rewriteBtn])
        bottomStack.orientation = .horizontal
        bottomStack.spacing = 8
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(bottomStack)

        // Constraints
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: bg.topAnchor, constant: 14),
            headerLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),

            badge.leadingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),

            closeBtn.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            closeBtn.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 22),
            closeBtn.heightAnchor.constraint(equalToConstant: 22),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),

            toneScroll.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            toneScroll.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            toneScroll.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            toneScroll.heightAnchor.constraint(equalToConstant: 30),

            toneStack.topAnchor.constraint(equalTo: toneScroll.topAnchor),
            toneStack.leadingAnchor.constraint(equalTo: toneScroll.leadingAnchor),

            divider.topAnchor.constraint(equalTo: toneScroll.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            bottomStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            bottomStack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            bottomStack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            bottomStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -12),
            bottomStack.heightAnchor.constraint(equalToConstant: 30),

            scrollView.bottomAnchor.constraint(equalTo: toneScroll.topAnchor, constant: -8),
        ])
    }

    private func makeBadge(_ text: String) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 0.3).cgColor
        v.layer?.cornerRadius = 4
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textColor = NSColor(red: 0.7, green: 0.6, blue: 1.0, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 5),
            l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -5),
            l.topAnchor.constraint(equalTo: v.topAnchor, constant: 2),
            l.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -2),
            v.heightAnchor.constraint(equalToConstant: 18),
        ])
        return v
    }

    private func makeTonePill(_ title: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 14
        btn.layer?.borderWidth = 1.5
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.0).cgColor
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        btn.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
        ])
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        btn.target = self; btn.action = #selector(tonePillTapped(_:))
        return btn
    }

    private func makeIconButton(_ symbol: String, size: CGFloat, tint: NSColor) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .medium))
        btn.contentTintColor = tint
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        return btn
    }

    private func configureBarBtn(_ btn: NSButton, icon: String?, title: String, primary: Bool) {
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 7
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 28).isActive = true

        if primary {
            btn.layer?.backgroundColor = NSColor.white.cgColor
            btn.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.black,
            ])
        } else if title.isEmpty, let icon {
            btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
            btn.contentTintColor = NSColor.white.withAlphaComponent(0.7)
            btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        } else {
            btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
            btn.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.85),
            ])
        }
    }

    private func flexSpacer() -> NSView {
        let v = NSView()
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return v
    }

    // MARK: - Public API

    func show(originalText: String, element: AXUIElement?, range: CFRange) {
        self.originalText = originalText
        self.savedElement = element
        self.savedRange   = range
        self.selectedTone = nil
        toneButtons.forEach { updateTonePill($0, selected: false) }
        textView.string = ""
        statusLabel.stringValue = "Generating..."
        [replaceBtn, rewriteBtn, regenBtn, copyBtn].forEach { $0.isEnabled = false }
        centerOnScreen()
        orderFront(nil)
        // Do NOT activate — panel is nonactivating so original app keeps focus + selection
    }

    func setResult(_ text: String) {
        if isAIQuestion(text) {
            textView.string = originalText
            statusLabel.stringValue = "Showing original"
        } else {
            textView.string = text
            statusLabel.stringValue = ""
        }
        [replaceBtn, rewriteBtn, regenBtn, copyBtn].forEach { $0.isEnabled = true }
    }

    func setError(_ message: String) {
        textView.string = originalText
        statusLabel.stringValue = "Error — showing original"
        [replaceBtn, rewriteBtn, regenBtn, copyBtn].forEach { $0.isEnabled = true }
    }

    // MARK: - Helpers

    private func isAIQuestion(_ text: String) -> Bool {
        let lower = text.lowercased()
        let clues = [
            "could you please", "could you share", "could you provide", "could you clarify",
            "please provide", "please clarify", "please share",
            "i need more", "i'd be happy to help", "i'd need",
            "it looks like", "it seems like", "it appears",
            "got cut off", "seems incomplete", "seems like a fragment",
            "missing context", "what do you mean", "can you provide",
            "what would you like", "what text", "could you send",
            "once you", "share the complete", "share the full",
        ]
        if clues.contains(where: { lower.contains($0) }) { return true }
        let questionCount = text.components(separatedBy: "?").count - 1
        return questionCount >= 2
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.midY - frame.height / 2 + 40
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateTonePill(_ btn: NSButton, selected: Bool) {
        btn.layer?.borderColor = selected
            ? NSColor.white.withAlphaComponent(0.8).cgColor
            : NSColor.white.withAlphaComponent(0.0).cgColor
        btn.layer?.backgroundColor = selected
            ? NSColor.white.withAlphaComponent(0.12).cgColor
            : NSColor.white.withAlphaComponent(0.06).cgColor
        let title = btn.title
        btn.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(selected ? 1.0 : 0.75),
        ])
    }

    private func runWithOriginalApp(_ block: @escaping () -> Void) {
        orderOut(nil)
        guard let element = savedElement else { block(); return }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: .activateIgnoringOtherApps)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: block)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        SelectionMonitor.shared.suppress(for: 1.5)
        orderOut(nil)
    }

    @objc private func copyTapped() {
        let text = textView.string
        guard !text.isEmpty else { return }
        SelectionMonitor.shared.suppress(for: 1.5)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        // Brief visual feedback
        copyBtn.contentTintColor = NSColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyBtn.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        }
    }

    @objc private func tonePillTapped(_ sender: NSButton) {
        let title = sender.title
        if selectedTone == title {
            selectedTone = nil
            updateTonePill(sender, selected: false)
        } else {
            selectedTone = title
            toneButtons.forEach { updateTonePill($0, selected: $0.title == title) }
        }
    }

    @objc private func replaceTapped() {
        let newText = textView.string
        guard !newText.isEmpty else { return }

        let element = savedElement
        let range   = savedRange

        var targetPid: pid_t = 0
        if let el = element { AXUIElementGetPid(el, &targetPid) }

        // Strategy: restore the saved selection range, then replace via AX.
        // Verify the replacement actually happened — some apps return success falsely
        // (kAXSelectedTextAttribute set returns .success but selection range doesn't collapse).
        // If AX fails verification, fall back to paste with selection restored.
        if let el = element, range.location != kCFNotFound, range.length > 0 {
            var r = range
            if let rangeVal = AXValueCreate(AXValueType(rawValue: 4)!, &r) {
                AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, rangeVal)
            }

            if AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, newText as CFString) == .success {
                // Verify: after a real replacement the selection collapses to a cursor (length == 0).
                var verifyRef: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &verifyRef)
                var afterRange = CFRange(location: 0, length: -1)
                if let v = verifyRef { AXValueGetValue(v as! AXValue, AXValueType(rawValue: 4)!, &afterRange) }

                if afterRange.length == 0 {
                    SelectionMonitor.shared.suppress(for: 2.0)
                    orderOut(nil)
                    return
                }
                // Selection didn't collapse → false positive, fall through to paste
            }
        }

        // Fallback: activate original app, restore selection, paste
        SelectionMonitor.shared.suppress(for: 2.0)
        orderOut(nil)
        if targetPid > 0, let app = NSRunningApplication(processIdentifier: targetPid) {
            app.activate(options: .activateIgnoringOtherApps)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let el = element else {
                SelectionMonitor.shared.pasteText(newText)
                return
            }

            AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, kCFBooleanTrue)

            if range.location != kCFNotFound && range.length > 0 {
                var r = range
                if let rangeVal = AXValueCreate(AXValueType(rawValue: 4)!, &r) {
                    AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, rangeVal)
                }
            }

            SelectionMonitor.shared.pasteText(newText)
        }
    }

    @objc private func rewriteWithToneTapped() {
        [replaceBtn, rewriteBtn, regenBtn].forEach { $0.isEnabled = false }
        statusLabel.stringValue = selectedTone.map { "Rewriting as \($0)..." } ?? "Rewriting..."
        let text = originalText
        let instruction = selectedTone.map {
            "Fix grammar, spelling, and phrasing. Rewrite in a \($0.lowercased()) tone. Preserve the original language and meaning. Return only the corrected text with no explanation."
        }
        Task {
            do {
                let result = try await AIService.shared.rewrite(text, instruction: instruction)
                await MainActor.run { setResult(result) }
            } catch {
                await MainActor.run { setError(error.localizedDescription) }
            }
        }
    }

    @objc private func regenerateTapped() {
        [replaceBtn, rewriteBtn, regenBtn].forEach { $0.isEnabled = false }
        statusLabel.stringValue = "Regenerating..."
        let text = originalText
        Task {
            do {
                let result = try await AIService.shared.rewrite(text, instruction: nil)
                await MainActor.run { setResult(result) }
            } catch {
                await MainActor.run { setError(error.localizedDescription) }
            }
        }
    }
}
