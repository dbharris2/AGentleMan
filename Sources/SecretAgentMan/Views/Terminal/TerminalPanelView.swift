import SwiftTerm
import SwiftUI

/// Agent terminal panel — wraps TerminalContainerView with agent process management.
struct TerminalPanelView: View {
    let selectedAgentId: UUID?
    let store: AgentStore
    let terminalManager: TerminalManager

    var body: some View {
        let terminal = resolvedTerminal
        TerminalContainerView(
            label: "agent",
            selectedAgentId: selectedAgentId,
            terminal: terminal
        )
    }

    /// Resolve the terminal in the parent view so TerminalContainerView never
    /// reads @Observable state or receives a closure parameter. This keeps
    /// observation at the SwiftUI view level and out of updateNSView.
    private var resolvedTerminal: LocalProcessTerminalView? {
        guard let agentId = selectedAgentId,
              let agent = store.agents.first(where: { $0.id == agentId })
        else { return nil }
        return terminalManager.terminal(for: agent, onStateChange: { id, state in
            Task { @MainActor in store.updateState(id: id, state: state) }
        })
    }
}
