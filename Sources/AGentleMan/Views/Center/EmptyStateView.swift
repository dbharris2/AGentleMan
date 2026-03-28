import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Agent Selected", systemImage: "terminal")
        } description: {
            Text("Select an agent from the sidebar or create a new one with +")
        }
    }
}
