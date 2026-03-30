import SwiftUI

/// A vertical split view that persists its divider position via NSSplitView's autosaveName.
struct PersistentSplitView<Top: View, Bottom: View>: NSViewRepresentable {
    let autosaveName: String
    let topMinHeight: CGFloat
    let bottomMinHeight: CGFloat
    let defaultTopFraction: CGFloat
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.autosaveName = autosaveName

        let topHost = NSHostingView(rootView: top())
        let bottomHost = NSHostingView(rootView: bottom())
        splitView.addSubview(topHost)
        splitView.addSubview(bottomHost)

        context.coordinator.topHost = topHost
        context.coordinator.bottomHost = bottomHost

        splitView.delegate = context.coordinator
        context.coordinator.topMinHeight = topMinHeight
        context.coordinator.bottomMinHeight = bottomMinHeight
        context.coordinator.defaultTopFraction = defaultTopFraction

        return splitView
    }

    func updateNSView(_: NSSplitView, context: Context) {
        context.coordinator.topHost?.rootView = top()
        context.coordinator.bottomHost?.rootView = bottom()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var topHost: NSHostingView<Top>?
        var bottomHost: NSHostingView<Bottom>?
        var topMinHeight: CGFloat = 100
        var bottomMinHeight: CGFloat = 100
        var defaultTopFraction: CGFloat = 0.7
        private var hasSetInitialPosition = false

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            topMinHeight
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            splitView.bounds.height - bottomMinHeight
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  !hasSetInitialPosition,
                  splitView.bounds.height > 0
            else { return }

            hasSetInitialPosition = true

            // Only set default if autosave hasn't restored a position
            let topHeight = splitView.subviews.first?.frame.height ?? 0
            let totalHeight = splitView.bounds.height
            if totalHeight > 0, abs(topHeight / totalHeight - 0.5) < 0.01 {
                // NSSplitView defaults to 50/50; apply our preferred ratio
                splitView.setPosition(totalHeight * defaultTopFraction, ofDividerAt: 0)
            }
        }
    }
}
