import SwiftUI

struct SidebarView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.appTheme) private var theme
    @Binding var selectedPlanURL: URL?
    @SceneStorage("collapsedAgentFolders") private var collapsedFoldersStorage = ""
    @State private var showingNewAgent = false
    @State private var renamingAgentId: UUID?
    @State private var renameText = ""

    private var groupedAgents: [(folder: String, agents: [Agent])] {
        coordinator.store.agentsByFolder
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { coordinator.store.selectedAgentId },
            set: { coordinator.store.selectAgent(id: $0) }
        )
    }

    var body: some View {
        let collapsedSet = collapsedFolders
        List(selection: selectionBinding) {
            ForEach(groupedAgents, id: \.folder) { group in
                let isExpanded = folderExpandedBinding(for: group.folder, in: collapsedSet)

                HStack(spacing: 8) {
                    Image(systemName: isExpanded.wrappedValue ? "folder.fill" : "folder")
                        .scaledFont(size: 13)
                        .foregroundStyle(theme.accent)
                        .frame(width: 16)

                    Text(group.agents.first?.folderName ?? "")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundStyle(theme.foreground)

                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.2)) {
                        isExpanded.wrappedValue.toggle()
                    }
                }

                if isExpanded.wrappedValue {
                    ForEach(group.agents) { agent in
                        AgentRowView(
                            agent: agent,
                            isSelected: coordinator.store.selectedAgentId == agent.id,
                            pendingPromptCount: coordinator.store.pendingPrompts(for: agent.id).count,
                            branchName: coordinator.repositoryMonitor.branchNames[agent.folderPath]
                        )
                        .tag(agent.id)
                        .padding(.leading, 16)
                        .contextMenu {
                            Button("Rename...") {
                                renameText = agent.name
                                renamingAgentId = agent.id
                            }
                            Divider()
                            Button("Remove", role: .destructive) {
                                coordinator.removeAgent(agent.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.surface)
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
            NewAgentSheet(store: coordinator.store, isPresented: $showingNewAgent)
        }
        .alert("Rename Agent", isPresented: Binding(
            get: { renamingAgentId != nil },
            set: { if !$0 { renamingAgentId = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingAgentId = nil }
            Button("Rename") {
                if let id = renamingAgentId, !renameText.isEmpty {
                    coordinator.store.renameAgent(id: id, name: renameText)
                }
                renamingAgentId = nil
            }
        }
    }

    private var collapsedFolders: Set<String> {
        Set(
            collapsedFoldersStorage
                .split(separator: "\n")
                .map(String.init)
        )
    }

    private func folderExpandedBinding(for folder: String, in collapsed: Set<String>) -> Binding<Bool> {
        Binding(
            get: { !collapsed.contains(folder) },
            set: { isExpanded in
                var updated = collapsed
                if isExpanded {
                    updated.remove(folder)
                } else {
                    updated.insert(folder)
                }
                collapsedFoldersStorage = updated.sorted().joined(separator: "\n")
            }
        )
    }
}
