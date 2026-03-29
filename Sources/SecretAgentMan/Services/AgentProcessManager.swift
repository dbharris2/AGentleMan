import Foundation
import SwiftTerm

@MainActor
final class AgentProcessManager {
    static let claudePath: String = {
        // Try common locations
        let candidates = [
            NSHomeDirectory() + "/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "claude"
    }()

    func startAgent(
        terminal: LocalProcessTerminalView,
        folder: URL,
        initialPrompt: String? = nil,
        sessionId: String? = nil,
        hasLaunched: Bool = false
    ) {
        var args: [String] = []

        if let sessionId {
            if hasLaunched {
                args.append(contentsOf: ["--resume", sessionId])
            } else {
                args.append(contentsOf: ["--session-id", sessionId])
            }
        }

        // Add plugin directory if configured
        let pluginDir = (UserDefaults.standard.string(forKey: "pluginDirectory") ?? "")
            .replacingOccurrences(of: "~", with: NSHomeDirectory())
        if !pluginDir.isEmpty {
            args.append(contentsOf: ["--plugin-dir", pluginDir])
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
