import SwiftTerm
import SwiftUI

/// Shell terminal panel — wraps TerminalContainerView with the user's login shell.
struct ShellPanelView: View {
    let selectedAgentId: UUID?
    let store: AgentStore
    let shellManager: ShellManager

    var body: some View {
        let terminal = resolvedTerminal
        TerminalContainerView(
            label: "shell",
            selectedAgentId: selectedAgentId,
            terminal: terminal
        )
    }

    private var resolvedTerminal: LocalProcessTerminalView? {
        guard let agentId = selectedAgentId,
              let agent = store.agents.first(where: { $0.id == agentId })
        else { return nil }
        return shellManager.terminal(for: agent)
    }
}
