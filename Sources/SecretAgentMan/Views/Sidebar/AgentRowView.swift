import SwiftUI

struct AgentRowView: View {
    let agent: Agent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            StatusBadge(state: agent.state)

            Text(agent.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
