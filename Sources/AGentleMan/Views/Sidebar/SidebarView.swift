import SwiftUI

struct SidebarView: View {
    @Bindable var store: AgentStore
    var onRemoveAgent: (UUID) -> Void
    @State private var showingNewAgent = false

    var body: some View {
        List(selection: $store.selectedAgentId) {
            ForEach(store.agentsByFolder, id: \.folder) { group in
                Section(group.folder) {
                    ForEach(group.agents) { agent in
                        AgentRowView(agent: agent, isSelected: store.selectedAgentId == agent.id)
                            .tag(agent.id)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    onRemoveAgent(agent.id)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewAgent = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Agent (Cmd+N)")
                .keyboardShortcut("n")
            }
        }
        .sheet(isPresented: $showingNewAgent) {
            NewAgentSheet(store: store, isPresented: $showingNewAgent)
        }
    }
}
