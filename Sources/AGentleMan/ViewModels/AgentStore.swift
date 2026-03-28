import Foundation
import SwiftUI

@MainActor
@Observable
final class AgentStore {
    var agents: [Agent] = []
    var selectedAgentId: UUID?

    var selectedAgent: Agent? {
        agents.first { $0.id == selectedAgentId }
    }

    var agentsByFolder: [(folder: String, agents: [Agent])] {
        let grouped = Dictionary(grouping: agents) { $0.folderPath }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (folder: $0.key, agents: $0.value.sorted { $0.createdAt < $1.createdAt }) }
    }

    func addAgent(name: String, folder: URL, initialPrompt: String? = nil) -> Agent {
        let agent = Agent(name: name, folder: folder, initialPrompt: initialPrompt)
        agents.append(agent)
        selectedAgentId = agent.id
        return agent
    }

    func removeAgent(id: UUID) {
        agents.removeAll { $0.id == id }
        if selectedAgentId == id {
            selectedAgentId = agents.first?.id
        }
    }

    func updateState(id: UUID, state: AgentState) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        agents[index].state = state
    }

    func updatePid(id: UUID, pid: Int32) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        agents[index].pid = pid
    }

    var hasActiveAgents: Bool {
        agents.contains { $0.state == .active || $0.state == .awaitingInput }
    }

    var awaitingInputCount: Int {
        agents.filter { $0.state == .awaitingInput }.count
    }
}
