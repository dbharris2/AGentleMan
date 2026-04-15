import AppKit
import SwiftUI

struct ResizableDivider: View {
    @Binding var size: Double
    let minSize: Double
    var maxSize: Double?
    let axis: Axis
    /// When true, dragging toward the end of the axis *grows* the bound size.
    /// Use for dividers whose resized panel is on the leading/top side
    /// (e.g. a left sidebar's right-hand divider).
    var reverse: Bool = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        DragHandleRepresentable(
            size: $size,
            minSize: minSize,
            maxSize: maxSize,
            axis: axis,
            reverse: reverse,
            color: NSColor(theme.accent.opacity(0.6))
        )
        .frame(
            width: axis == .vertical ? 3 : nil,
            height: axis == .horizontal ? 3 : nil
        )
    }
}

private struct DragHandleRepresentable: NSViewRepresentable {
    @Binding var size: Double
    let minSize: Double
    let maxSize: Double?
    let axis: Axis
    let reverse: Bool
    let color: NSColor

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.axis = axis
        view.fillColor = color
        view.onDragBegin = { [coordinator = context.coordinator] in
            coordinator.dragStartSize = coordinator.sizeBinding.wrappedValue
        }
        view.onDragChange = { [coordinator = context.coordinator] delta in
            guard let start = coordinator.dragStartSize else { return }
            let signedDelta = coordinator.reverse ? Double(delta) : -Double(delta)
            var next = start + signedDelta
            next = Swift.max(coordinator.minSize, next)
            if let maxSize = coordinator.maxSize {
                next = Swift.min(maxSize, next)
            }
            coordinator.sizeBinding.wrappedValue = next
        }
        view.onDragEnd = { [coordinator = context.coordinator] in
            coordinator.dragStartSize = nil
        }
        return view
    }

    func updateNSView(_ view: DragHandleView, context: Context) {
        view.axis = axis
        view.fillColor = color
        context.coordinator.sizeBinding = $size
        context.coordinator.reverse = reverse
        context.coordinator.minSize = minSize
        context.coordinator.maxSize = maxSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sizeBinding: $size,
            minSize: minSize,
            maxSize: maxSize,
            reverse: reverse
        )
    }

    final class Coordinator {
        var sizeBinding: Binding<Double>
        var minSize: Double
        var maxSize: Double?
        var reverse: Bool
        var dragStartSize: Double?

        init(sizeBinding: Binding<Double>, minSize: Double, maxSize: Double?, reverse: Bool) {
            self.sizeBinding = sizeBinding
            self.minSize = minSize
            self.maxSize = maxSize
            self.reverse = reverse
        }
    }
}

final class DragHandleView: NSView {
    var axis: Axis = .vertical
    var fillColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    var onDragBegin: (() -> Void)?
    var onDragChange: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    private var dragStartWindowPoint: NSPoint?

    override var isFlipped: Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
    }

    override func resetCursorRects() {
        let cursor: NSCursor = axis == .vertical ? .resizeLeftRight : .resizeUpDown
        // Widen the cursor hit region so it's easier to grab the 3pt bar.
        let inset: CGFloat = 4
        let rect: NSRect = switch axis {
        case .vertical:
            bounds.insetBy(dx: -inset, dy: 0)
        case .horizontal:
            bounds.insetBy(dx: 0, dy: -inset)
        }
        addCursorRect(rect, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartWindowPoint = event.locationInWindow
        onDragBegin?()
        // Tight event-tracking loop: pull drag/up events directly from the
        // window's event queue until the mouse is released. This matches native
        // NSSplitView responsiveness — no SwiftUI layout round-trip per event.
        guard let window else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .leftMouseDragged]
        var tracking = true
        while tracking, let next = window.nextEvent(matching: mask) {
            switch next.type {
            case .leftMouseDragged:
                handleDrag(next)
            case .leftMouseUp:
                dragStartWindowPoint = nil
                onDragEnd?()
                tracking = false
            default:
                break
            }
        }
    }

    private func handleDrag(_ event: NSEvent) {
        guard let start = dragStartWindowPoint else { return }
        let loc = event.locationInWindow
        let delta: CGFloat = switch axis {
        case .vertical:
            loc.x - start.x
        case .horizontal:
            // AppKit window coords are bottom-origin: dragging *down* in the
            // view corresponds to a *decrease* in window y. We want a positive
            // delta when dragging down (matches the SwiftUI convention used by
            // callers), so flip the sign.
            -(loc.y - start.y)
        }
        onDragChange?(delta)
    }
}
