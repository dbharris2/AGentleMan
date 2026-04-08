import SwiftTerm
import SwiftUI

/// A reusable NSViewRepresentable container that swaps terminal views when
/// the selected agent changes. Used by both the agent terminal and shell panels.
///
/// IMPORTANT: This view intentionally takes a pre-resolved `terminal` instead
/// of a closure or store reference. Reading @Observable properties inside
/// `updateNSView` establishes observation that, combined with closure parameters
/// SwiftUI can't compare, causes cascading re-render loops when multiple
/// containers exist (e.g. agent + shell panels both visible).
struct TerminalContainerView: NSViewRepresentable {
    var label: String = "unknown"
    let selectedAgentId: UUID?
    let terminal: LocalProcessTerminalView?

    func makeNSView(context: Context) -> NSView {
        context.coordinator.label = label
        let container = NSView(frame: .zero)
        if let terminal {
            Self.embed(terminal, in: container)
            context.coordinator.currentAgentId = selectedAgentId
            context.coordinator.currentTerminal = terminal
        }
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let newId = selectedAgentId
        let oldId = context.coordinator.currentAgentId

        guard let terminal else {
            if newId != oldId || context.coordinator.currentTerminal != nil {
                for subview in container.subviews {
                    subview.removeFromSuperview()
                }
                context.coordinator.currentAgentId = newId
                context.coordinator.currentTerminal = nil
            }
            return
        }

        // Re-embed if agent changed or terminal instance changed (e.g. session restart)
        guard newId != oldId || terminal !== context.coordinator.currentTerminal else { return }

        for subview in container.subviews {
            subview.removeFromSuperview()
        }
        context.coordinator.currentAgentId = newId
        context.coordinator.currentTerminal = terminal

        Self.embed(terminal, in: container)
    }

    private static func embed(_ terminal: LocalProcessTerminalView, in container: NSView) {
        terminal.removeFromSuperview()
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var currentAgentId: UUID?
        weak var currentTerminal: LocalProcessTerminalView?
        var label: String = "unknown"
    }
}
