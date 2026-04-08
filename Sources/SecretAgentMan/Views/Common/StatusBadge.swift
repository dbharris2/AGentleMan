import SwiftUI

struct StatusBadge: View {
    let state: AgentState

    var body: some View {
        let presentation = state.presentation

        Image(systemName: presentation.systemImage)
            .foregroundStyle(presentation.tone.color)
            .scaledFont(size: 10)
            .help(presentation.label)
    }
}
