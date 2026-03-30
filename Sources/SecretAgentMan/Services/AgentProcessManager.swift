import Foundation
import OSLog
import SwiftTerm

@MainActor
final class AgentProcessManager {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.secretagentman", category: "AgentProcess")
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
        var args = ["--enable-auto-mode"]

        if let sessionId {
            if hasLaunched {
                args.append(contentsOf: ["--resume", sessionId])
                Self.logger.info("Resuming session \(sessionId)")
            } else {
                args.append(contentsOf: ["--session-id", sessionId])
                Self.logger.info("Starting new session \(sessionId)")
            }
        } else {
            Self.logger.warning("No session ID — session will not be resumable")
        }

        // Add plugin directory if configured
        let pluginDir = (UserDefaults.standard.string(forKey: UserDefaultsKeys.pluginDirectory) ?? "")
            .replacingOccurrences(of: "~", with: NSHomeDirectory())
        if !pluginDir.isEmpty {
            args.append(contentsOf: ["--plugin-dir", pluginDir])
        }

        if let prompt = initialPrompt, !prompt.isEmpty {
            args.append(prompt)
        }

        let env = currentEnvironment()

        Self.logger
            .info(
                "Launching claude: \(Self.claudePath) \(args.joined(separator: " ")) | cwd=\(folder.path) hasLaunched=\(hasLaunched) sessionId=\(sessionId ?? "nil") prompt=\(initialPrompt != nil ? "yes" : "nil")"
            )

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
