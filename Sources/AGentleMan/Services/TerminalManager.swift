import AppKit
import SwiftTerm

@MainActor
final class TerminalManager {
    private var terminals: [UUID: LocalProcessTerminalView] = [:]
    private var delegates: [UUID: TerminalDelegate] = [:]
    private let processManager = AgentProcessManager()

    func terminal(for agent: Agent, onStateChange: @escaping (UUID, AgentState) -> Void) -> LocalProcessTerminalView {
        if let existing = terminals[agent.id] {
            return existing
        }

        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let delegate = TerminalDelegate(agentId: agent.id, onStateChange: onStateChange)
        terminal.processDelegate = delegate

        terminals[agent.id] = terminal
        delegates[agent.id] = delegate

        processManager.startAgent(
            terminal: terminal,
            folder: agent.folder,
            initialPrompt: agent.initialPrompt,
            sessionId: agent.sessionId
        )

        onStateChange(agent.id, .active)

        return terminal
    }

    func removeTerminal(for agentId: UUID) {
        if let terminal = terminals[agentId] {
            terminal.terminate()
        }
        terminals.removeValue(forKey: agentId)
        delegates.removeValue(forKey: agentId)
    }

    func hasTerminal(for agentId: UUID) -> Bool {
        terminals[agentId] != nil
    }
}

final class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate, @unchecked Sendable {
    let agentId: UUID
    let onStateChange: (UUID, AgentState) -> Void

    init(agentId: UUID, onStateChange: @escaping (UUID, AgentState) -> Void) {
        self.agentId = agentId
        self.onStateChange = onStateChange
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onStateChange(self.agentId, .finished)
        }
    }
}
