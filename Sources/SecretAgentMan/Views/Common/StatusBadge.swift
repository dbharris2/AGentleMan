import SwiftUI

struct StatusBadge: View {
    let state: AgentState

    var body: some View {
        Image(systemName: state.systemImage)
            .foregroundStyle(state.color)
            .font(.system(size: 10))
            .help(state.label)
    }
}
