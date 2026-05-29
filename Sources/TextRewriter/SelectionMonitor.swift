import AppKit
import ApplicationServices

class SelectionMonitor {
    static let shared = SelectionMonitor()

    var onTextSelected: ((String, NSPoint) -> Void)?
    var onSelectionCleared: (() -> Void)?

    private var appObserver: AXObserver?
    private var elementObserver: AXObserver?
    private var observedElement: AXUIElement?
    private var observedAppPid: pid_t = 0

    private(set) var currentText: String = ""
    private(set) var focusedElement: AXUIElement?
    private(set) var savedRange: CFRange = CFRange(location: kCFNotFound, length: 0)

    private var suppressedUntil: Date = .distantPast

    func suppress(for duration: TimeInterval = 2.0) {
        suppressedUntil = Date().addingTimeInterval(duration)
    }

    private init() {}

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        if let app = NSWorkspace.shared.frontmostApplication {
            observeApp(pid: app.processIdentifier)
        }
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        removeAppObserver()
        removeElementObserver()
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        guard pid != observedAppPid else { return }
        observeApp(pid: pid)
    }

    private func observeApp(pid: pid_t) {
        removeAppObserver()
        observedAppPid = pid

        var observer: AXObserver?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()
            if notification as String == kAXFocusedUIElementChangedNotification as String {
                monitor.observeElement(element)
            }
        }, &observer) == .success, let observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        appObserver = observer

        // Check currently focused element in this app right away
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success {
            observeElement(focusedRef as! AXUIElement)
        }
    }

    private func removeAppObserver() {
        guard let observer = appObserver else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        appObserver = nil
        observedAppPid = 0
    }

    private func observeElement(_ element: AXUIElement) {
        removeElementObserver()

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        guard pid > 0 else { return }

        var observer: AXObserver?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.checkSelection()
        }, &observer) == .success, let observer else { return }

        guard AXObserverAddNotification(observer, element, kAXSelectedTextChangedNotification as CFString, selfPtr) == .success else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        elementObserver = observer
        observedElement = element
    }

    private func removeElementObserver() {
        guard let observer = elementObserver else { return }
        if let element = observedElement {
            AXObserverRemoveNotification(observer, element, kAXSelectedTextChangedNotification as CFString)
        }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        elementObserver = nil
        observedElement = nil
    }

    private func checkSelection() {
        guard Date() >= suppressedUntil else { return }
        guard let element = observedElement else { return }

        var textRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textRef) == .success,
              let text = textRef as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearIfNeeded(); return
        }

        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue else { clearIfNeeded(); return }

        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let axVal = rangeRef {
            var r = CFRange(location: 0, length: 0)
            AXValueGetValue(axVal as! AXValue, AXValueType(rawValue: 4)!, &r)
            savedRange = r
        }

        focusedElement = element
        currentText = text
        onTextSelected?(text, NSEvent.mouseLocation)
    }

    private func clearIfNeeded() {
        guard !currentText.isEmpty else { return }
        currentText = ""
        focusedElement = nil
        savedRange = CFRange(location: kCFNotFound, length: 0)
        onSelectionCleared?()
    }

    func pasteText(_ text: String) {
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        if let saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                pb.clearContents()
                pb.setString(saved, forType: .string)
            }
        }
    }
}
