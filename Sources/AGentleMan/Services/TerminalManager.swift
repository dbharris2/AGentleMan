import AppKit
import SwiftTerm

@MainActor
final class TerminalManager {
    private var terminals: [UUID: LocalProcessTerminalView] = [:]
    private var delegates: [UUID: TerminalDelegate] = [:]
    private let processManager = AgentProcessManager()

    var themeName: String = "Catppuccin Mocha" {
        didSet { applyThemeToAll() }
    }

    private var currentTheme: GhosttyTheme? {
        GhosttyThemeLoader.load(named: themeName)
    }

    func terminal(for agent: Agent, onStateChange: @escaping (UUID, AgentState) -> Void) -> LocalProcessTerminalView {
        if let existing = terminals[agent.id] {
            return existing
        }

        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        applyTheme(to: terminal)

        let delegate = TerminalDelegate(agentId: agent.id, onStateChange: onStateChange)
        terminal.processDelegate = delegate

        terminals[agent.id] = terminal
        delegates[agent.id] = delegate

        processManager.startAgent(
            terminal: terminal,
            folder: agent.folder,
            initialPrompt: agent.initialPrompt,
            sessionId: agent.sessionId
        )

        onStateChange(agent.id, .active)

        return terminal
    }

    func removeTerminal(for agentId: UUID) {
        if let terminal = terminals[agentId] {
            terminal.terminate()
        }
        terminals.removeValue(forKey: agentId)
        delegates.removeValue(forKey: agentId)
    }

    func hasTerminal(for agentId: UUID) -> Bool {
        terminals[agentId] != nil
    }

    private func applyTheme(to terminal: LocalProcessTerminalView) {
        guard let theme = currentTheme else { return }

        terminal.nativeBackgroundColor = theme.background
        terminal.nativeForegroundColor = theme.foreground
        terminal.caretColor = theme.cursorColor
        terminal.selectedTextBackgroundColor = theme.selectionBackground

        let swiftTermColors = theme.swiftTermColors.map { nsColorToTermColor($0) }
        terminal.installColors(swiftTermColors)
    }

    private func nsColorToTermColor(_ nsColor: NSColor) -> SwiftTerm.Color {
        guard let color = nsColor.usingColorSpace(.deviceRGB) else {
            return SwiftTerm.Color(red: 32768, green: 32768, blue: 32768)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SwiftTerm.Color(red: UInt16(r * 65535), green: UInt16(g * 65535), blue: UInt16(b * 65535))
    }

    private func applyThemeToAll() {
        for terminal in terminals.values {
            applyTheme(to: terminal)
        }
    }
}

final class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate, @unchecked Sendable {
    let agentId: UUID
    let onStateChange: (UUID, AgentState) -> Void

    init(agentId: UUID, onStateChange: @escaping (UUID, AgentState) -> Void) {
        self.agentId = agentId
        self.onStateChange = onStateChange
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onStateChange(self.agentId, .finished)
        }
    }
}
