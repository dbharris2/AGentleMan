import Foundation

struct Agent: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var folder: URL
    var state: AgentState
    var sessionId: String?
    var pid: Int32?
    var initialPrompt: String?
    var hasLaunched: Bool
    var createdAt: Date

    var folderName: String {
        folder.lastPathComponent
    }

    var folderPath: String {
        folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    init(
        id: UUID = UUID(),
        name: String,
        folder: URL,
        state: AgentState = .idle,
        sessionId: String? = nil,
        pid: Int32? = nil,
        initialPrompt: String? = nil,
        hasLaunched: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.folder = folder
        self.state = state
        self.sessionId = sessionId
        self.pid = pid
        self.initialPrompt = initialPrompt
        self.hasLaunched = hasLaunched
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folder = try container.decode(URL.self, forKey: .folder)
        state = try container.decode(AgentState.self, forKey: .state)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
        initialPrompt = try container.decodeIfPresent(String.self, forKey: .initialPrompt)
        hasLaunched = try container.decodeIfPresent(Bool.self, forKey: .hasLaunched) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, folder, state, sessionId, pid, initialPrompt, hasLaunched, createdAt
    }
}
