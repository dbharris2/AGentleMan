import SwiftTerm
import SwiftUI

/// Agent terminal panel — wraps TerminalContainerView with agent process management.
///
/// Terminal resolution happens in `onChange`/`onAppear` (outside SwiftUI's
/// observation tracking scope) rather than in `body`. Reading `store.agents`
/// during body evaluation creates an AttributeGraph cycle because the async
/// process start mutates `store.agents` and the terminal reference type is
/// not comparable by SwiftUI.
struct TerminalPanelView: View {
    let selectedAgentId: UUID?
    let store: AgentStore
    let terminalManager: TerminalManager

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

    /// Resolve the terminal outside body evaluation to avoid
    /// an AttributeGraph cycle from @Observable tracking.
    private func syncTerminal() {
        guard let agentId = selectedAgentId,
              let agent = store.agents.first(where: { $0.id == agentId })
        else {
            displayedAgentId = nil
            displayedTerminal = nil
            return
        }
        let t = terminalManager.terminal(
            for: agent,
            onStateChange: { id, state in
                Task { @MainActor in store.updateState(id: id, state: state) }
            }
        )
        displayedAgentId = agentId
        displayedTerminal = t
    }
}
