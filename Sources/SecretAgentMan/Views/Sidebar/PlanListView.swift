import SwiftUI

struct PlanListView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.appTheme) private var theme
    @Binding var selectedPlanURL: URL?

    var body: some View {
        Group {
            if coordinator.store.selectedAgent?.provider == .codex {
                ContentUnavailableView(
                    "Plans Unavailable",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Codex does not write Claude-style plan files. Use the session terminal and status panels for Codex agents.")
                )
            } else {
                List(coordinator.planStore.plans) { plan in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(plan.title)
                                .scaledFont(size: 13)
                                .lineLimit(1)

                            Spacer()

                            if let modified = plan.modified {
                                Text(Self.relativeDate(modified))
                                    .scaledFont(size: 10)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Text(plan.filename)
                            .scaledFont(size: 11)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                    .contentShape(Rectangle())
                    .hoverHighlight(isSelected: selectedPlanURL == plan.url, cornerRadius: 0)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        if selectedPlanURL == plan.url {
                            selectedPlanURL = nil
                        } else {
                            selectedPlanURL = plan.url
                        }
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deletePlan(plan)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(theme.surface)
            }
        }
    }

    private func deletePlan(_ plan: PlanFile) {
        if selectedPlanURL == plan.url {
            selectedPlanURL = nil
        }
        coordinator.planStore.deletePlan(plan)
    }

    private static func relativeDate(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604_800 { return "\(Int(seconds / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
