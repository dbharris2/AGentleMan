import SwiftUI

// MARK: - Model Pill (read-only)

struct ClaudeModelPill: View {
    let agentId: UUID
    let monitor: ClaudeStreamMonitor
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(monitor.modelNames[agentId] ?? "Claude")
            .scaledFont(size: 11)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.foreground.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Mode Picker

struct ClaudeModePickerButton: View {
    let agentId: UUID
    let monitor: ClaudeStreamMonitor
    @State private var isPresented = false
    @Environment(\.appTheme) private var theme

    private var currentMode: String {
        monitor.permissionModes[agentId] ?? ClaudeStreamMonitor.defaultPermissionMode
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Text(currentMode)
                .scaledFont(size: 11)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .hoverHighlight()
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.foreground.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ClaudeModeList(monitor: monitor, agentId: agentId) { isPresented = false }
        }
    }
}

private struct ClaudeModeList: View {
    let monitor: ClaudeStreamMonitor
    let agentId: UUID
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    private var currentMode: String {
        monitor.permissionModes[agentId] ?? ClaudeStreamMonitor.defaultPermissionMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Mode")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘⇧M")
                    .scaledFont(size: 9, weight: .medium, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(theme.foreground.opacity(0.08))
                    )
            }

            ForEach(ClaudeStreamMonitor.permissionModes, id: \.self) { mode in
                Button {
                    monitor.setPermissionMode(for: agentId, mode: mode)
                    onDismiss()
                } label: {
                    HStack {
                        Text(mode).scaledFont(size: 12)
                        Spacer()
                        if currentMode == mode {
                            Image(systemName: "checkmark")
                                .scaledFont(size: 10)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .hoverHighlight()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(minWidth: 180, maxWidth: 220)
    }
}
