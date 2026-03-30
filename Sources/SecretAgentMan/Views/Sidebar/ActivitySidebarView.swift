import SwiftUI

enum ActivityMode: String {
    case agents
    case plans
}

struct ActivitySidebarView: View {
    @Binding var mode: ActivityMode
    @Bindable var store: AgentStore
    var branchNames: [String: String]
    var prInfos: [String: PRInfo]
    var onRemoveAgent: (UUID) -> Void
    @Binding var selectedPlanURL: URL?

    var body: some View {
        switch mode {
        case .agents:
            SidebarView(
                store: store,
                branchNames: branchNames,
                prInfos: prInfos,
                onRemoveAgent: onRemoveAgent
            )
        case .plans:
            PlanListView(selectedPlanURL: $selectedPlanURL)
        }
    }
}
