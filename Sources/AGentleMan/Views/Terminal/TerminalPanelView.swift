import SwiftTerm
import SwiftUI

struct TerminalPanelView: NSViewRepresentable {
    let agent: Agent
    let terminalManager: TerminalManager
    let onStateChange: (UUID, AgentState) -> Void

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        let terminal = terminalManager.terminal(for: agent, onStateChange: onStateChange)
        embedTerminal(terminal, in: container)
        context.coordinator.currentAgentId = agent.id
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard context.coordinator.currentAgentId != agent.id else { return }

        // Remove old terminal from container
        container.subviews.forEach { $0.removeFromSuperview() }

        // Add the new agent's terminal
        let terminal = terminalManager.terminal(for: agent, onStateChange: onStateChange)
        embedTerminal(terminal, in: container)
        context.coordinator.currentAgentId = agent.id

        // Focus the terminal
        container.window?.makeFirstResponder(terminal)
    }

    private func embedTerminal(_ terminal: LocalProcessTerminalView, in container: NSView) {
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
