import Foundation
import SwiftTerm

@MainActor
final class AgentProcessManager {
    static let claudePath = "/Users/devonmars/.local/bin/claude"

    func startAgent(
        terminal: LocalProcessTerminalView,
        folder: URL,
        initialPrompt: String? = nil,
        sessionId: String? = nil
    ) {
        var args: [String] = []

        if let sessionId {
            args.append(contentsOf: ["--resume", sessionId])
        }

        if let prompt = initialPrompt, !prompt.isEmpty {
            args.append(prompt)
        }

        let env = currentEnvironment()

        terminal.startProcess(
            executable: Self.claudePath,
            args: args,
            environment: env,
            execName: "claude",
            currentDirectory: folder.path
        )
    }

    private func currentEnvironment() -> [String] {
        ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
    }
}
