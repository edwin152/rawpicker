import AppKit
import SwiftUI

struct KeyboardHandler: NSViewRepresentable {
    let onPrevious: (Bool) -> Void
    let onNext: (Bool) -> Void
    let onEndDirection: () -> Void
    let onToggleFavorite: () -> Void

    @MainActor
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onPrevious = onPrevious
        view.onNext = onNext
        view.onEndDirection = onEndDirection
        view.onToggleFavorite = onToggleFavorite
        view.startMonitoring()
        return view
    }

    @MainActor
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onPrevious = onPrevious
        nsView.onNext = onNext
        nsView.onEndDirection = onEndDirection
        nsView.onToggleFavorite = onToggleFavorite
        nsView.startMonitoring()
    }

    @MainActor
    static func dismantleNSView(_ nsView: KeyView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

final class KeyView: NSView {
    var onPrevious: ((Bool) -> Void)?
    var onNext: ((Bool) -> Void)?
    var onEndDirection: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var keyWindowObserver: Any?

    override var acceptsFirstResponder: Bool { true }

    func startMonitoring() {
        guard keyDownMonitor == nil, keyUpMonitor == nil else { return }

        startObservingKeyWindow()
        becomeFirstResponderIfNeeded()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.shouldHandle(event) else {
                return event
            }
            return self.handleKeyDown(event)
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self, self.shouldHandle(event) else {
                return event
            }
            return self.handleKeyUp(event)
        }
    }

    func stopMonitoring() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }

        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }

        if let keyWindowObserver {
            NotificationCenter.default.removeObserver(keyWindowObserver)
            self.keyWindowObserver = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        becomeFirstResponderIfNeeded()
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyDown(event) == nil {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if handleKeyUp(event) == nil {
            return
        }
        super.keyUp(with: event)
    }

    private func shouldHandle(_ event: NSEvent) -> Bool {
        guard NSApp.isActive else { return false }

        if let eventWindow = event.window,
           let keyWindow = NSApp.keyWindow,
           eventWindow !== keyWindow {
            return false
        }

        if let viewWindow = window,
           let keyWindow = NSApp.keyWindow,
           viewWindow !== keyWindow {
            return false
        }

        let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        return event.modifierFlags.intersection(disallowedModifiers).isEmpty
    }

    private func startObservingKeyWindow() {
        guard keyWindowObserver == nil else { return }
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.becomeFirstResponderIfNeeded()
            }
        }
    }

    private func becomeFirstResponderIfNeeded() {
        guard let window, window.isKeyWindow else { return }

        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 123:
            onPrevious?(event.isARepeat)
            return nil
        case 124:
            onNext?(event.isARepeat)
            return nil
        case 49:
            if !event.isARepeat {
                onToggleFavorite?()
            }
            return nil
        default:
            return event
        }
    }

    private func handleKeyUp(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 123, 124:
            onEndDirection?()
            return nil
        default:
            return event
        }
    }
}
