import Foundation
@testable import SecretAgentMan
import Testing

@MainActor
struct AgentProcessManagerTests {
    @Test
    func claudeLaunchConfigurationIncludesSessionAndPrompt() {
        let config = AgentProcessManager.buildLaunchConfiguration(
            provider: .claude,
            folder: URL(fileURLWithPath: "/tmp/project"),
            initialPrompt: "Fix the test failure",
            sessionId: "claude-session",
            hasLaunched: false
        )

        #expect(config.args.starts(with: ["--enable-auto-mode", "--session-id", "claude-session"]))
        #expect(config.args.last == "Fix the test failure")
    }

    @Test
    func codexLaunchConfigurationUsesResumeForExistingSession() {
        let config = AgentProcessManager.buildLaunchConfiguration(
            provider: .codex,
            folder: URL(fileURLWithPath: "/tmp/project"),
            initialPrompt: "Ignored prompt",
            sessionId: "codex-session",
            hasLaunched: true
        )

        #expect(config.args == ["--full-auto", "--cd", "/tmp/project", "resume", "codex-session"])
    }

    @Test
    func codexLaunchConfigurationUsesPromptForNewSession() {
        let config = AgentProcessManager.buildLaunchConfiguration(
            provider: .codex,
            folder: URL(fileURLWithPath: "/tmp/project"),
            initialPrompt: "Implement provider support",
            sessionId: "codex-session",
            hasLaunched: false
        )

        #expect(config.args == ["--full-auto", "--cd", "/tmp/project", "Implement provider support"])
    }
}
