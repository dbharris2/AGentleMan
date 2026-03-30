import SwiftTerm
import SwiftUI

/// A reusable NSViewRepresentable container that swaps terminal views when
/// the selected agent changes. Used by both the agent terminal and shell panels.
struct TerminalContainerView: NSViewRepresentable {
    let selectedAgentId: UUID?
    let store: AgentStore
    let terminalProvider: (Agent) -> LocalProcessTerminalView

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        if let agentId = selectedAgentId, let agent = store.agents.first(where: { $0.id == agentId }) {
            let terminal = terminalProvider(agent)
            Self.embed(terminal, in: container)
            context.coordinator.currentAgentId = agentId
        }
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let newId = selectedAgentId
        let oldId = context.coordinator.currentAgentId

        guard newId != oldId else { return }

        for subview in container.subviews {
            subview.removeFromSuperview()
        }

        context.coordinator.currentAgentId = newId

        guard let agentId = newId, let agent = store.agents.first(where: { $0.id == agentId }) else {
            return
        }

        let terminal = terminalProvider(agent)
        Self.embed(terminal, in: container)

        DispatchQueue.main.async {
            container.window?.makeFirstResponder(terminal)
        }
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
    }
}
