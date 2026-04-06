import SwiftUI

enum SidebarPanel: String {
    case plans
    case prs
}

struct ActivitySidebarView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Binding var selectedPlanURL: URL?
    @AppStorage("sidebarSplitHeight") private var bottomPanelHeight: Double = 250

    var body: some View {
        @Bindable var coordinator = coordinator
        if let panel = coordinator.activeSidebarPanel {
            VStack(spacing: 0) {
                SidebarView(selectedPlanURL: $selectedPlanURL)

                ResizableDivider(size: $bottomPanelHeight, minSize: 100, axis: .horizontal)

                Group {
                    switch panel {
                    case .plans:
                        PlanListView(selectedPlanURL: $selectedPlanURL)
                    case .prs:
                        PRListView(
                            sections: coordinator.githubPRSections,
                            onReview: coordinator.reviewPR,
                            onSelect: coordinator.selectPR,
                            selectedPRId: coordinator.selectedGitHubPR?.id
                        )
                    }
                }
                .frame(height: bottomPanelHeight)
            }
        } else {
            SidebarView(selectedPlanURL: $selectedPlanURL)
        }
    }
}
