import SwiftTerm
import SwiftUI

/// Shell terminal panel — wraps TerminalContainerView with the user's login shell.
///
/// Same pattern as TerminalPanelView — terminal resolution in `onChange`/`onAppear`
/// to avoid AttributeGraph cycles from @Observable tracking in body evaluation.
struct ShellPanelView: View {
    let selectedAgentId: UUID?
    let store: AgentStore
    let shellManager: ShellManager

    @State private var displayedAgentId: UUID?
    @State private var displayedTerminal: LocalProcessTerminalView?

    var body: some View {
        TerminalContainerView(
            selectedAgentId: displayedAgentId,
            terminal: displayedTerminal
        )
        .onAppear { syncTerminal() }
        .onChange(of: selectedAgentId) { _, _ in syncTerminal() }
        .onChange(of: store.terminalRestartCount) { _, _ in syncTerminal() }
    }

    private func syncTerminal() {
        guard let agentId = selectedAgentId,
              let agent = store.agents.first(where: { $0.id == agentId })
        else {
            displayedAgentId = nil
            displayedTerminal = nil
            return
        }
        displayedAgentId = agentId
        displayedTerminal = shellManager.terminal(for: agent)
    }
}
