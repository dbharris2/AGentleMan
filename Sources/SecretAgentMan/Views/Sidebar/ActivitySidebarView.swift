import SwiftUI

enum SidebarPanel: String {
    case plans
    case prs
}

struct ActivitySidebarView: View {
    @Binding var activePanel: SidebarPanel?
    @Bindable var store: AgentStore
    var branchNames: [String: String]
    var prInfos: [String: PRInfo]
    var onRemoveAgent: (UUID) -> Void
    @Binding var selectedPlanURL: URL?
    var prSections: [GitHubPRService.PRSection: [GitHubPRService.GitHubPR]]
    var onReviewPR: (GitHubPRService.GitHubPR) -> Void
    var onSelectPR: (GitHubPRService.GitHubPR?) -> Void
    var selectedPRId: String?
    @AppStorage("sidebarSplitHeight") private var bottomPanelHeight: Double = 250

    var body: some View {
        if let panel = activePanel {
            VStack(spacing: 0) {
                SidebarView(
                    store: store,
                    branchNames: branchNames,
                    prInfos: prInfos,
                    onRemoveAgent: onRemoveAgent
                )

                ResizableDivider(size: $bottomPanelHeight, minSize: 100, axis: .horizontal)

                // Bottom panel
                Group {
                    switch panel {
                    case .plans:
                        PlanListView(selectedPlanURL: $selectedPlanURL)
                    case .prs:
                        PRListView(
                            sections: prSections,
                            onReview: onReviewPR,
                            onSelect: onSelectPR,
                            selectedPRId: selectedPRId
                        )
                    }
                }
                .frame(height: bottomPanelHeight)
            }
        } else {
            SidebarView(
                store: store,
                branchNames: branchNames,
                prInfos: prInfos,
                onRemoveAgent: onRemoveAgent
            )
        }
    }
}
