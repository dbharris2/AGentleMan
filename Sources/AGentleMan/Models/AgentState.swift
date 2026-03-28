import SwiftUI

enum AgentState: String, Hashable {
    case idle
    case active
    case awaitingInput
    case finished
    case error

    var label: String {
        switch self {
        case .idle: "Idle"
        case .active: "Active"
        case .awaitingInput: "Waiting"
        case .finished: "Done"
        case .error: "Error"
        }
    }

    var color: Color {
        switch self {
        case .idle: .secondary
        case .active: .green
        case .awaitingInput: .orange
        case .finished: .blue
        case .error: .red
        }
    }

    var systemImage: String {
        switch self {
        case .idle: "circle"
        case .active: "circle.fill"
        case .awaitingInput: "hourglass.circle.fill"
        case .finished: "checkmark.circle.fill"
        case .error: "exclamationmark.circle.fill"
        }
    }
}
