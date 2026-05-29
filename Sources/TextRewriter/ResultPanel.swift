import AppKit
import ApplicationServices

class ResultPanel: NSPanel {
    // Bottom bar buttons
    private let replaceBtn  = NSButton()
    private let adjustBtn   = NSButton()
    private let copyBtn     = NSButton()
    private let regenBtn    = NSButton()
    private var isLoading   = false

    // Text view
    private let textView = NSTextView()

    // Adjust panel rows
    private var tonePills:   [NSButton] = []
    private var formatPills: [NSButton] = []
    private var lengthPills: [NSButton] = []

    // Current selections
    private var options = RewriteOptions()
    private var adjustVisible = false
    private var streamBuffer = ""
    private var isFirstChunk = true

    // Saved context for Replace
    var savedElement: AXUIElement?
    var savedRange: CFRange = CFRange(location: kCFNotFound, length: 0)
    private var originalText: String = ""

    // Layout constants
    private static let W: CGFloat    = 510
    private static let H: CGFloat    = 252
    private static let rowH: CGFloat = 30   // each pill row height
    private static let adjustH: CGFloat = 8 + 30 + 8 + 30 + 8 + 30 + 10  // 3 rows + gaps
    private static let HExpanded: CGFloat = H + adjustH

    private static let tones   = ["Professional", "Casual", "Enthusiastic", "Informational", "Funny"]
    private static let formats = ["Paragraph", "Email", "Bullet points", "Blog post"]
    private static let lengths = ["Short", "Medium", "Long"]

    // Dynamic height constraint for adjustView
    private var adjustHeightCon: NSLayoutConstraint!

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: ResultPanel.W, height: ResultPanel.H),
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

    // MARK: - UI Setup

    private func setupUI() {
        let bg = NSView()
        bg.wantsLayer = true
        bg.autoresizingMask = [.width, .height]
        bg.frame = NSRect(x: 0, y: 0, width: ResultPanel.W, height: ResultPanel.H)
        bg.layer?.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 0.97).cgColor
        bg.layer?.cornerRadius = 14
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        contentView = bg

        // ── Header ─────────────────────────────────────────────────
        let headerLabel = NSTextField(labelWithString: "Here is another way of writing this")
        headerLabel.font = .systemFont(ofSize: 12, weight: .regular)
        headerLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let aiBadge = NSTextField(labelWithString: "AI generated")
        aiBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        aiBadge.textColor = .white
        aiBadge.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = makeCloseBtn()
        closeBtn.target = self; closeBtn.action = #selector(closeTapped)

        bg.addSubview(headerLabel)
        bg.addSubview(aiBadge)
        bg.addSubview(closeBtn)

        // ── Text area ───────────────────────────────────────────────
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 13.5)
        textView.textColor = .white
        textView.backgroundColor = NSColor(red: 0.15, green: 0.16, blue: 0.21, alpha: 1)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 10
        scrollView.documentView = textView
        bg.addSubview(scrollView)

        // ── Adjust panel ────────────────────────────────────────────
        let adjustView = NSView()
        adjustView.translatesAutoresizingMaskIntoConstraints = false
        adjustView.wantsLayer = true
        adjustView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        adjustView.layer?.cornerRadius = 10
        bg.addSubview(adjustView)

        adjustHeightCon = adjustView.heightAnchor.constraint(equalToConstant: 0)
        adjustHeightCon.isActive = true

        // Build 3 rows inside adjustView
        let toneRow   = makeAdjustRow(label: "Tone",   options: ResultPanel.tones,   pills: &tonePills,   action: #selector(tonePillTapped(_:)))
        let formatRow = makeAdjustRow(label: "Format", options: ResultPanel.formats, pills: &formatPills, action: #selector(formatPillTapped(_:)))
        let lengthRow = makeAdjustRow(label: "Length", options: ResultPanel.lengths, pills: &lengthPills, action: #selector(lengthPillTapped(_:)))

        adjustView.addSubview(toneRow)
        adjustView.addSubview(formatRow)
        adjustView.addSubview(lengthRow)

        NSLayoutConstraint.activate([
            toneRow.topAnchor.constraint(equalTo: adjustView.topAnchor, constant: 8),
            toneRow.leadingAnchor.constraint(equalTo: adjustView.leadingAnchor, constant: 10),
            toneRow.trailingAnchor.constraint(equalTo: adjustView.trailingAnchor, constant: -10),
            toneRow.heightAnchor.constraint(equalToConstant: ResultPanel.rowH),

            formatRow.topAnchor.constraint(equalTo: toneRow.bottomAnchor, constant: 8),
            formatRow.leadingAnchor.constraint(equalTo: adjustView.leadingAnchor, constant: 10),
            formatRow.trailingAnchor.constraint(equalTo: adjustView.trailingAnchor, constant: -10),
            formatRow.heightAnchor.constraint(equalToConstant: ResultPanel.rowH),

            lengthRow.topAnchor.constraint(equalTo: formatRow.bottomAnchor, constant: 8),
            lengthRow.leadingAnchor.constraint(equalTo: adjustView.leadingAnchor, constant: 10),
            lengthRow.trailingAnchor.constraint(equalTo: adjustView.trailingAnchor, constant: -10),
            lengthRow.heightAnchor.constraint(equalToConstant: ResultPanel.rowH),
        ])

        // ── Bottom bar ──────────────────────────────────────────────
        configureBtn(replaceBtn, icon: "arrow.up.left", title: "Replace", style: .primary)
        replaceBtn.target = self; replaceBtn.action = #selector(replaceTapped)

        configureBtn(adjustBtn, icon: "slider.horizontal.3", title: "Adjust", style: .secondary)
        adjustBtn.target = self; adjustBtn.action = #selector(adjustTapped)

        configureIconBtn(copyBtn, symbol: "doc.on.doc")
        copyBtn.toolTip = "Copy"
        copyBtn.target = self; copyBtn.action = #selector(copyTapped)

        configureIconBtn(regenBtn, symbol: "arrow.clockwise")
        regenBtn.toolTip = "Regenerate"
        regenBtn.target = self; regenBtn.action = #selector(regenerateTapped)

        let bottomStack = NSStackView(views: [replaceBtn, adjustBtn, flexSpacer(), copyBtn, regenBtn])
        bottomStack.orientation = .horizontal
        bottomStack.spacing = 8
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(bottomStack)

        // Equal-width Replace and Adjust
        adjustBtn.widthAnchor.constraint(equalTo: replaceBtn.widthAnchor).isActive = true

        // ── Constraints ─────────────────────────────────────────────
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: bg.topAnchor, constant: 14),
            headerLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 16),

            aiBadge.leadingAnchor.constraint(equalTo: headerLabel.trailingAnchor, constant: 6),
            aiBadge.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),

            closeBtn.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            closeBtn.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 26),
            closeBtn.heightAnchor.constraint(equalToConstant: 26),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: adjustView.topAnchor, constant: -8),

            adjustView.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            adjustView.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            adjustView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -10),

            bottomStack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            bottomStack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            bottomStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -14),
            bottomStack.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    // MARK: - Adjust row builder

    private func makeAdjustRow(label: String, options: [String], pills: inout [NSButton], action: Selector) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = NSColor.white.withAlphaComponent(0.4)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        row.addSubview(lbl)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        for opt in options {
            let btn = makePill(opt, action: action)
            pills.append(btn)
            stack.addArrangedSubview(btn)
        }

        row.addSubview(stack)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 50),

            stack.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    // MARK: - View helpers

    private func makeCloseBtn() -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        btn.layer?.cornerRadius = 7
        btn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .bold))
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private enum BtnStyle { case primary, secondary }

    private func configureBtn(_ btn: NSButton, icon: String, title: String, style: BtnStyle) {
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))

        let color: NSColor = style == .primary ? .black : NSColor.white.withAlphaComponent(0.85)
        let bgColor: NSColor = style == .primary ? .white : NSColor.white.withAlphaComponent(0.1)
        btn.layer?.backgroundColor = bgColor.cgColor

        let attach = NSTextAttachment()
        attach.image = img?.tinted(color)
        let str = NSMutableAttributedString(attachment: attach)
        str.append(NSAttributedString(string: "  \(title)", attributes: [
            .font: NSFont.systemFont(ofSize: 12.5, weight: style == .primary ? .semibold : .medium),
            .foregroundColor: color,
        ]))
        btn.attributedTitle = str
    }

    private func configureIconBtn(_ btn: NSButton, symbol: String) {
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 8
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
    }

    private func makePill(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 12
        btn.layer?.borderWidth = 1
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0).cgColor
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        btn.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.65),
        ])
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        btn.target = self; btn.action = action
        return btn
    }

    private func setPillSelected(_ btn: NSButton, selected: Bool) {
        btn.layer?.borderColor = selected
            ? NSColor.white.withAlphaComponent(0.65).cgColor
            : NSColor.white.withAlphaComponent(0).cgColor
        btn.layer?.backgroundColor = selected
            ? NSColor.white.withAlphaComponent(0.15).cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor
        btn.attributedTitle = NSAttributedString(string: btn.title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: selected ? .semibold : .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(selected ? 1 : 0.65),
        ])
    }

    private func flexSpacer() -> NSView {
        let v = NSView()
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return v
    }

    // MARK: - Adjust panel expand/collapse

    private func setAdjustVisible(_ visible: Bool) {
        adjustVisible = visible
        let targetH = visible ? ResultPanel.HExpanded : ResultPanel.H

        adjustHeightCon.constant = visible ? ResultPanel.adjustH : 0

        adjustBtn.layer?.backgroundColor = visible
            ? NSColor.white.withAlphaComponent(0.18).cgColor
            : NSColor.white.withAlphaComponent(0.1).cgColor

        var f = frame
        f.origin.y -= (targetH - f.height)
        f.size.height = targetH
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(f, display: true)
        }
        contentView?.setFrameSize(NSSize(width: ResultPanel.W, height: targetH))
    }

    // MARK: - Public API

    func show(originalText: String, element: AXUIElement?, range: CFRange, defaultTone: String = "") {
        self.originalText = originalText
        self.savedElement = element
        self.savedRange   = range
        options = RewriteOptions(tone: defaultTone.isEmpty ? nil : defaultTone)

        tonePills.forEach   { setPillSelected($0, selected: $0.title == options.tone) }
        formatPills.forEach { setPillSelected($0, selected: false) }
        lengthPills.forEach { setPillSelected($0, selected: false) }

        if adjustVisible { setAdjustVisible(false) }
        setLoading(true)
        centerOnScreen()
        orderFront(nil)
    }

    func setResult(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13.5)]
        textView.typingAttributes = attrs
        textView.string = isAIQuestion(text) ? originalText : text
        setLoading(false)
    }

    func appendChunk(_ chunk: String) {
        if isFirstChunk {
            isFirstChunk = false
            streamBuffer = ""
            textView.typingAttributes = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13.5)]
            textView.string = ""
        }
        streamBuffer += chunk
        textView.textStorage?.append(NSAttributedString(string: chunk, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 13.5),
        ]))
        let end = (textView.string as NSString).length
        textView.scrollRangeToVisible(NSRange(location: end, length: 0))
    }

    func finishStreaming() {
        if isAIQuestion(streamBuffer) {
            textView.typingAttributes = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13.5)]
            textView.string = originalText
        }
        isFirstChunk = true
        setLoading(false)
    }

    func setError(_ message: String) {
        textView.typingAttributes = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13.5)]
        textView.string = originalText
        isFirstChunk = true
        setLoading(false)
    }

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        let dimColor  = NSColor.white.withAlphaComponent(0.3)
        let bodyFont  = NSFont.systemFont(ofSize: 13.5)
        if loading {
            textView.typingAttributes = [.foregroundColor: dimColor, .font: bodyFont]
            textView.string = "Generating..."
        } else {
            textView.typingAttributes = [.foregroundColor: NSColor.white, .font: bodyFont]
        }
        let alpha: CGFloat = loading ? 0.38 : 1
        [replaceBtn, adjustBtn, regenBtn, copyBtn].forEach { $0.alphaValue = alpha }
    }

    // MARK: - Helpers

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.midY - frame.height / 2 + 40
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func triggerRewrite() {
        setLoading(true)
        isFirstChunk = true
        let text = originalText
        let instruction = options.buildInstruction()
        Task {
            do {
                try await AIService.shared.rewriteStreaming(text, instruction: instruction) { [weak self] chunk in
                    await MainActor.run { self?.appendChunk(chunk) }
                }
                await MainActor.run { [weak self] in self?.finishStreaming() }
            } catch {
                await MainActor.run { [weak self] in self?.setError(error.localizedDescription) }
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        SelectionMonitor.shared.suppress(for: 1.5)
        if adjustVisible { setAdjustVisible(false) }
        orderOut(nil)
    }

    @objc private func adjustTapped() {
        guard !isLoading else { return }
        setAdjustVisible(!adjustVisible)
    }

    @objc private func copyTapped() {
        guard !isLoading else { return }
        let text = textView.string
        guard !text.isEmpty else { return }
        SelectionMonitor.shared.suppress(for: 1.5)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.orderOut(nil)
        }
    }

    @objc private func regenerateTapped() {
        guard !isLoading else { return }
        triggerRewrite()
    }

    @objc private func tonePillTapped(_ sender: NSButton) {
        let title = sender.title
        options.tone = (options.tone == title) ? nil : title
        tonePills.forEach { setPillSelected($0, selected: $0.title == options.tone) }
    }

    @objc private func formatPillTapped(_ sender: NSButton) {
        let title = sender.title
        options.format = (options.format == title) ? nil : title
        formatPills.forEach { setPillSelected($0, selected: $0.title == options.format) }
    }

    @objc private func lengthPillTapped(_ sender: NSButton) {
        let title = sender.title
        options.length = (options.length == title) ? nil : title
        lengthPills.forEach { setPillSelected($0, selected: $0.title == options.length) }
    }

    @objc private func replaceTapped() {
        guard !isLoading else { return }
        let newText = textView.string
        guard !newText.isEmpty else { return }

        let element = savedElement
        let range   = savedRange
        var targetPid: pid_t = 0
        if let el = element { AXUIElementGetPid(el, &targetPid) }

        if let el = element, range.location != kCFNotFound, range.length > 0 {
            var r = range
            if let rangeVal = AXValueCreate(AXValueType(rawValue: 4)!, &r) {
                AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, rangeVal)
            }
            if AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, newText as CFString) == .success {
                var verifyRef: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &verifyRef)
                var afterRange = CFRange(location: 0, length: -1)
                if let v = verifyRef { AXValueGetValue(v as! AXValue, AXValueType(rawValue: 4)!, &afterRange) }
                if afterRange.length == 0 {
                    SelectionMonitor.shared.suppress(for: 2.0)
                    orderOut(nil); return
                }
            }
        }

        SelectionMonitor.shared.suppress(for: 2.0)
        orderOut(nil)
        if targetPid > 0, let app = NSRunningApplication(processIdentifier: targetPid) {
            app.activate(options: .activateIgnoringOtherApps)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let el = element else { SelectionMonitor.shared.pasteText(newText); return }
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
}

// MARK: - NSImage tint
private extension NSImage {
    func tinted(_ color: NSColor) -> NSImage {
        let img = self.copy() as! NSImage
        img.lockFocus()
        color.set()
        NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop)
        img.unlockFocus()
        return img
    }
}
