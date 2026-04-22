import AppKit
import SwiftUI

struct ImageViewport: NSViewRepresentable {
    let decoded: DecodedImage
    @Binding var isFitMode: Bool
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize
    let onZoomChanged: () -> Void
    let onViewportChanged: (_ displayScale: CGFloat) -> Void

    @MainActor
    func makeNSView(context: Context) -> ImageViewportNSView {
        let view = ImageViewportNSView()
        configure(view)
        return view
    }

    @MainActor
    func updateNSView(_ nsView: ImageViewportNSView, context: Context) {
        configure(nsView)
    }

    @MainActor
    private func configure(_ view: ImageViewportNSView) {
        view.onStateChanged = { isFitMode, zoomScale, panOffset in
            self.isFitMode = isFitMode
            self.zoomScale = zoomScale
            self.panOffset = panOffset
        }
        view.onZoomChanged = onZoomChanged
        view.onViewportChanged = onViewportChanged
        view.configure(
            image: decoded.cgImage,
            pixelSize: decoded.pixelSize,
            isFitMode: isFitMode,
            zoomScale: zoomScale,
            panOffset: panOffset
        )
    }
}

final class ImageViewportNSView: NSView {
    var onStateChanged: ((_ isFitMode: Bool, _ zoomScale: CGFloat, _ panOffset: CGSize) -> Void)?
    var onZoomChanged: (() -> Void)?
    var onViewportChanged: ((_ displayScale: CGFloat) -> Void)?

    private var image: CGImage?
    private var pixelSize: CGSize = .zero
    private var isFitMode = true
    private var zoomScale: CGFloat = 1
    private var panOffset: CGSize = .zero
    private var dragStartLocation: CGPoint?
    private var dragStartPan: CGSize = .zero
    private let maxZoomScale: CGFloat = 12

    override var acceptsFirstResponder: Bool { true }

    override var wantsUpdateLayer: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installGestureRecognizers()
    }

    func configure(
        image: CGImage,
        pixelSize: CGSize,
        isFitMode: Bool,
        zoomScale: CGFloat,
        panOffset: CGSize
    ) {
        let requestedIsFitMode = isFitMode
        let requestedZoomScale = zoomScale
        let requestedPanOffset = panOffset

        self.image = image
        self.pixelSize = pixelSize
        self.isFitMode = isFitMode
        self.zoomScale = zoomScale
        self.panOffset = panOffset
        normalizeViewport(notify: false)

        if self.isFitMode != requestedIsFitMode ||
            abs(self.zoomScale - requestedZoomScale) > 0.0001 ||
            self.panOffset != requestedPanOffset {
            publishStateDeferred(zoomChanged: !requestedIsFitMode && self.isFitMode)
        }

        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        normalizeViewport(notify: true)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.2).setFill()
        dirtyRect.fill()

        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }

        let scale = displayScale
        context.interpolationQuality = scale > fitScale * 1.01 ? .none : .high
        context.setShouldAntialias(false)
        context.draw(image, in: imageRect(for: scale))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)

        guard event.clickCount < 2 else {
            toggleZoom(centeredAt: location)
            return
        }

        dragStartLocation = location
        dragStartPan = panOffset
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isFitMode, let dragStartLocation else { return }

        let location = convert(event.locationInWindow, from: nil)
        panOffset = clampedPan(
            CGSize(
                width: dragStartPan.width + location.x - dragStartLocation.x,
                height: dragStartPan.height + location.y - dragStartLocation.y
            ),
            at: displayScale
        )
        publishState()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        dragStartPan = panOffset
    }

    override func scrollWheel(with event: NSEvent) {
        guard !isFitMode else { return }

        panOffset = clampedPan(
            CGSize(
                width: panOffset.width + event.scrollingDeltaX,
                height: panOffset.height - event.scrollingDeltaY
            ),
            at: displayScale
        )
        publishState()
        needsDisplay = true
    }

    override func smartMagnify(with event: NSEvent) {
        toggleZoom(centeredAt: convert(event.locationInWindow, from: nil))
    }

    private var displayScale: CGFloat {
        isFitMode ? fitScale : min(max(zoomScale, minimumZoomScale), maxZoomScale)
    }

    private var fitScale: CGFloat {
        guard pixelSize.width > 0, pixelSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return 1
        }

        return min(bounds.width / pixelSize.width, bounds.height / pixelSize.height)
    }

    private var minimumZoomScale: CGFloat {
        min(fitScale, 1)
    }

    private func imageRect(for scale: CGFloat) -> CGRect {
        let scaledSize = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        return CGRect(
            x: (bounds.width - scaledSize.width) / 2 + panOffset.width,
            y: (bounds.height - scaledSize.height) / 2 + panOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private func zoom(by rawFactor: CGFloat, centeredAt location: CGPoint) {
        let oldScale = displayScale
        let factor = min(max(rawFactor, 0.2), 5)
        let newScale = min(max(oldScale * factor, minimumZoomScale), maxZoomScale)

        guard oldScale > 0, abs(newScale - oldScale) > 0.0001 else { return }

        applyZoom(newScale, oldScale: oldScale, oldPan: isFitMode ? .zero : panOffset, centeredAt: location)
    }

    private func toggleZoom(centeredAt location: CGPoint) {
        if isFitMode {
            applyZoom(1, oldScale: fitScale, oldPan: .zero, centeredAt: location)
        } else {
            isFitMode = true
            panOffset = .zero
            publishState()
            onZoomChanged?()
            needsDisplay = true
        }
    }

    private func applyZoom(_ newScale: CGFloat, oldScale: CGFloat, oldPan: CGSize, centeredAt location: CGPoint) {
        guard oldScale > 0, abs(newScale - oldScale) > 0.0001 else { return }

        if fitScale <= 1, newScale <= fitScale * 1.0001 {
            isFitMode = true
            panOffset = .zero
            publishState()
            onZoomChanged?()
            needsDisplay = true
            return
        }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let cursorOffset = CGSize(width: location.x - center.x, height: location.y - center.y)
        let ratio = newScale / oldScale

        isFitMode = false
        zoomScale = newScale
        panOffset = clampedPan(
            CGSize(
                width: oldPan.width * ratio + cursorOffset.width * (1 - ratio),
                height: oldPan.height * ratio + cursorOffset.height * (1 - ratio)
            ),
            at: newScale
        )
        publishState()
        onViewportChanged?(newScale)
        needsDisplay = true
    }

    private func normalizeViewport(notify: Bool) {
        if isFitMode {
            panOffset = .zero
        } else {
            zoomScale = min(max(zoomScale, minimumZoomScale), maxZoomScale)
            if fitScale <= 1, zoomScale <= fitScale * 1.0001 {
                isFitMode = true
                panOffset = .zero
            } else {
                panOffset = clampedPan(panOffset, at: zoomScale)
            }
        }

        if notify {
            publishState()
        }
    }

    private func clampedPan(_ pan: CGSize, at scale: CGFloat) -> CGSize {
        let scaledWidth = pixelSize.width * scale
        let scaledHeight = pixelSize.height * scale
        let maxX = max(0, (scaledWidth - bounds.width) / 2)
        let maxY = max(0, (scaledHeight - bounds.height) / 2)

        return CGSize(
            width: min(max(pan.width, -maxX), maxX),
            height: min(max(pan.height, -maxY), maxY)
        )
    }

    private func publishState() {
        onStateChanged?(isFitMode, zoomScale, panOffset)
    }

    private func publishStateDeferred(zoomChanged: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publishState()
            if zoomChanged {
                self.onZoomChanged?()
            }
        }
    }

    private func installGestureRecognizers() {
        let magnificationRecognizer = NSMagnificationGestureRecognizer(
            target: self,
            action: #selector(handleMagnification(_:))
        )
        addGestureRecognizer(magnificationRecognizer)
    }

    @objc private func handleMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }

        let magnification = recognizer.magnification
        guard abs(magnification) > 0.0001 else { return }

        zoom(by: 1 + magnification, centeredAt: recognizer.location(in: self))
        recognizer.magnification = 0
    }
}
