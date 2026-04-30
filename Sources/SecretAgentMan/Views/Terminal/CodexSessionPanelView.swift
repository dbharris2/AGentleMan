import SwiftUI

struct CodexSessionPanelView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.fontScale) private var fontScale
    @Environment(\.appTheme) private var theme

    let agent: Agent

    @FocusState private var composerFocused: Bool

    private var snapshot: AgentSessionSnapshot? {
        coordinator.agentSessions.snapshots[agent.id]
    }

    private var transcript: [SessionTranscriptItem] {
        snapshot?.finalizedTranscript ?? []
    }

    private var pendingInput: UserInputPrompt? {
        snapshot?.userInputPrompt
    }

    private var pendingApproval: ApprovalPrompt? {
        snapshot?.approvalPrompt
    }

    private var debugMessage: String? {
        coordinator.codexMonitor.debugMessages[agent.id]
    }

    private var streamingText: String? {
        snapshot?.streamingAssistantText
    }

    private var isThinking: Bool {
        agent.state == .active && streamingText == nil
    }

    private var currentModelName: String {
        let name = snapshot?.metadata.displayModelName
        return (name?.isEmpty == false ? name : nil) ?? "Codex"
    }

    private var currentCollaborationMode: CodexCollaborationMode {
        let raw = snapshot?.metadata.collaborationMode
        return raw.flatMap(CodexCollaborationMode.init(rawValue:)) ?? .default
    }

    var body: some View {
        SessionPanelShell(agent: agent, composerFocused: $composerFocused) {
            SessionChatView(
                providerName: "Codex",
                transcript: transcript,
                streaming: streamingText,
                isThinking: isThinking,
                activeTool: nil,
                hasPendingCard: pendingInput != nil || pendingApproval != nil,
                fontScale: fontScale,
                emptyStateText: "Codex session is ready. Send a message to start."
            ) {
                AnyView(Group {
                    if let debugMessage, pendingInput == nil {
                        Text(debugMessage)
                            .scaledFont(size: 12)
                            .foregroundStyle(theme.yellow)
                            .textSelection(.enabled)
                            .padding(Spacing.xxl)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.yellow.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let pendingInput {
                        inputCard(pendingInput)
                    }

                    if let pendingApproval {
                        approvalCard(pendingApproval)
                    }
                })
            }
        } composer: {
            CodexComposerView(
                agent: agent,
                currentModelName: currentModelName,
                currentCollaborationMode: currentCollaborationMode,
                composerFocused: $composerFocused
            )
        }
    }

    private func approvalCard(_ prompt: ApprovalPrompt) -> some View {
        SessionApprovalCard(
            title: prompt.title,
            detail: prompt.message,
            approveTitle: "Approve",
            declineTitle: "Decline",
            supportsDecisions: prompt.supportsDecisions,
            unsupportedText: "This permission request is not supported by the current UI yet."
        ) {
            coordinator.answerCodexApproval(for: agent.id, accept: true)
        } onDecline: {
            coordinator.answerCodexApproval(for: agent.id, accept: false)
        } onApproveAndSwitchMode: { mode in
            let policy: CodexApprovalPolicy = switch mode {
            case "acceptEdits":
                .onRequest
            case "auto":
                .never
            default:
                .untrusted
            }
            coordinator.setCodexApprovalPolicy(for: agent.id, policy: policy)
            coordinator.answerCodexApproval(for: agent.id, accept: true)
        }
    }

    private func inputCard(_ prompt: UserInputPrompt) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ForEach(prompt.questions) { question in
                SessionQuestionCard(
                    title: question.header,
                    detail: question.question,
                    options: question.options
                ) { option in
                    coordinator.answerCodexUserInput(
                        for: agent.id,
                        answers: [question.id: [option.label]]
                    )
                }
            }
        }
    }
}

/// Owns the per-keystroke draft state so typing only invalidates the composer
/// subtree — the panel body (which renders the full transcript via MarkdownUI)
/// stays put.
private struct CodexComposerView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.fontScale) private var fontScale

    let agent: Agent
    let currentModelName: String
    let currentCollaborationMode: CodexCollaborationMode
    var composerFocused: FocusState<Bool>.Binding

    @State private var draft = ""
    @State private var pendingImages: [PendingImage] = []
    @State private var showingUsagePopover = false

    var body: some View {
        SessionComposer(
            draft: $draft,
            pendingImages: $pendingImages,
            composerFocused: composerFocused,
            fontScale: fontScale,
            statusText: "",
            statusColor: .secondary,
            onKeyPress: { handleComposerSubmitKeyPress($0, send: sendDraft) },
            onDraftChange: {}
        ) {
            EmptyView()
        } trailingControls: {
            HStack(spacing: 6) {
                ComposerPill(text: currentModelName)
                ComposerModePickerButton(
                    title: "Mode",
                    modes: CodexCollaborationMode.allCases,
                    currentMode: currentCollaborationMode,
                    label: { $0.label },
                    shortcutKey: "m",
                    shortcutModifiers: [.command, .shift],
                    shortcutLabel: "⌘⇧M"
                ) { mode in
                    coordinator.setCodexCollaborationMode(for: agent.id, mode: mode)
                }
                if let limits = coordinator.usageMonitor.rateLimits[.codex] {
                    usageRingButton(limits: limits)
                }
            }
        }
    }

    private func usageRingButton(limits: AgentRateLimits) -> some View {
        Button {
            showingUsagePopover.toggle()
        } label: {
            UsageRing(percent: limits.shortWindow.usedPercent)
        }
        .buttonStyle(.plain)
        .help("API Usage")
        .popover(isPresented: $showingUsagePopover) {
            UsagePopover(limits: limits, provider: .codex)
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingImages.isEmpty else { return }
        let imageData = pendingImages.map(\.data)
        let imagePaths = pendingImages.compactMap { img -> String? in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("codex-image-\(UUID().uuidString).png")
            return (try? img.data.write(to: url)) != nil ? url.path : nil
        }
        let sendText = text.isEmpty ? "[Image]" : text
        coordinator.codexMonitor.recordSentUserMessage(
            for: agent.id,
            text: sendText,
            imageData: imageData
        )
        coordinator.sendCodexMessage(for: agent.id, text: sendText, imagePaths: imagePaths)
        draft = ""
        pendingImages.removeAll()
    }
}
