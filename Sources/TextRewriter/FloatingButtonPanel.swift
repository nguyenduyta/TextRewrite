import AppKit

class FloatingButtonPanel: NSPanel {
    private var selectedText: String = ""
    private var hideTimer: Timer?
    private let resultPanel = ResultPanel()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 178, height: 34),
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

        setupButton()
    }

    private func setupButton() {
        let panelRect = NSRect(x: 0, y: 0, width: 178, height: 34)
        let container = NSView(frame: panelRect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 0.97).cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        let btn = NSButton(frame: panelRect.insetBy(dx: 1, dy: 1))
        btn.bezelStyle = .roundRect
        btn.isBordered = false
        btn.target = self
        btn.action = #selector(rewriteTapped)

        let icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        let attachment = NSTextAttachment()
        attachment.image = icon

        let str = NSMutableAttributedString(attachment: attachment)
        str.append(NSAttributedString(string: "  Help me rewrite", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]))
        btn.attributedTitle = str
        btn.autoresizingMask = [.width, .height] as NSView.AutoresizingMask

        container.addSubview(btn)
        contentView = container
    }

    func show(near point: NSPoint, with text: String) {
        guard !resultPanel.isVisible else { return }
        selectedText = text
        hideTimer?.invalidate()

        let x = point.x - frame.width / 2
        let y = point.y + 14
        setFrameOrigin(NSPoint(x: x, y: y))
        orderFront(nil)

        hideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        orderOut(nil)
    }

    @objc private func rewriteTapped() {
        // Capture element + range BEFORE anything changes focus
        let element  = SelectionMonitor.shared.focusedElement
        let range    = SelectionMonitor.shared.savedRange
        let text     = selectedText
        let tone     = AISettings.shared.defaultTone   // "" = no default
        let instruction: String? = tone.isEmpty ? nil :
            "Fix grammar, spelling, and phrasing. Rewrite in a \(tone.lowercased()) tone. Preserve the original language and meaning. Return only the corrected text with no explanation."
        hide()
        resultPanel.show(originalText: text, element: element, range: range, defaultTone: tone)

        Task {
            do {
                let result = try await AIService.shared.rewrite(text, instruction: instruction)
                await MainActor.run { resultPanel.setResult(result) }
            } catch {
                await MainActor.run { resultPanel.setError(error.localizedDescription) }
            }
        }
    }
}
