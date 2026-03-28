import SwiftUI

@main
struct AGentleManApp: App {
    @State private var store = AgentStore()
    @State private var terminalManager = TerminalManager()
    @State private var diffService = DiffService()
    @State private var fileChanges: [FileChange] = []
    @State private var fullDiff: String = ""
    @State private var diffTimer: Timer?

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(store: store, onRemoveAgent: removeAgent)
            } content: {
                if store.selectedAgent != nil {
                    ChangesView(changes: fileChanges, fullDiff: fullDiff)
                } else {
                    EmptyStateView()
                }
            } detail: {
                if let agent = store.selectedAgent {
                    TerminalPanelView(
                        agent: agent,
                        terminalManager: terminalManager,
                        onStateChange: { agentId, state in
                            store.updateState(id: agentId, state: state)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "No Agent",
                        systemImage: "terminal",
                        description: Text("Select an agent to start chatting")
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 900, minHeight: 600)
            .onChange(of: store.selectedAgentId) {
                refreshDiffs()
            }
            .onAppear {
                startDiffPolling()
            }
            .onDisappear {
                diffTimer?.invalidate()
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
    }

    private func removeAgent(_ id: UUID) {
        terminalManager.removeTerminal(for: id)
        store.removeAgent(id: id)
    }

    private func startDiffPolling() {
        diffTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                refreshDiffs()
            }
        }
    }

    private func refreshDiffs() {
        guard let agent = store.selectedAgent else {
            fileChanges = []
            fullDiff = ""
            return
        }

        Task {
            let changes = await diffService.fetchChanges(in: agent.folder)
            let diff = await diffService.fetchFullDiff(in: agent.folder)
            await MainActor.run {
                fileChanges = changes
                fullDiff = diff
            }
        }
    }
}
