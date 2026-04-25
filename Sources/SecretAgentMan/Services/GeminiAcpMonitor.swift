// swiftlint:disable file_length
import Foundation
import Observation

/// Per-agent monitor for `gemini --acp` ACP/JSON-RPC sessions.
///
/// Mirrors the shape of `CodexAppServerMonitor`: the outer class is a
/// per-agent dispatcher that owns one `Observer` (process + JSON-RPC client)
/// per agent and routes incoming protocol events through normalized
/// `SessionEvent`s.
@MainActor
@Observable
final class GeminiAcpMonitor {
    @ObservationIgnored var onStateChange: ((UUID, AgentState) -> Void)?
    @ObservationIgnored var onSessionReady: ((UUID, String) -> Void)?
    @ObservationIgnored var onSessionEvent: ((UUID, SessionEvent) -> Void)?

    /// Tracks an outstanding ACP `session/request_permission`. The monitor
    /// keeps the original request shape so it can answer the JSON-RPC request
    /// with the user's selected `optionId` (or a `cancelled` outcome) later.
    struct PendingApproval: Equatable {
        let promptId: String
        let acpRequestId: GeminiAcpRpc.Id
        let sessionId: String
    }

    private(set) var pendingApprovalRequests: [UUID: PendingApproval] = [:]
    /// Debug-only channel for surfacing raw monitor diagnostics. Mirrors
    /// Codex's `debugMessages`.
    private(set) var debugMessages: [UUID: String] = [:]

    /// Local user-message reconciliation. Gemini echoes user messages back as
    /// part of `session/update.user_message_chunk` for loaded history; for
    /// in-flight prompts the monitor stamps a local id and reuses it when the
    /// agent's `userMessageId` arrives via `PromptResponse`.
    struct PendingLocalUserMessage: Equatable {
        let id: String
        let text: String
        let imageData: [Data]
    }

    @ObservationIgnored private(set) var pendingLocalUserMessages: [UUID: [PendingLocalUserMessage]] = [:]

    /// Active streaming-bubble item id per agent, keyed by stream type. The
    /// `messageId` in incoming `ContentChunk`s is optional, so the monitor
    /// allocates a stable id on first chunk and reuses it for deltas until the
    /// turn ends.
    @ObservationIgnored private var activeAssistantStreamId: [UUID: String] = [:]
    @ObservationIgnored private var activeThoughtStreamId: [UUID: String] = [:]

    /// Tool call lifecycle state. Gemini sends `tool_call` once and then
    /// arbitrary `tool_call_update`s; the monitor merges partial fields into
    /// the cached snapshot before emitting normalized transcript updates.
    @ObservationIgnored private(set) var toolCallSnapshots: [UUID: [String: ToolCallSnapshot]] = [:]

    @ObservationIgnored private var observers: [UUID: Observer] = [:]

    init() {}

    // MARK: - Public API (production)

    func syncMonitoredAgents(_ agents: [Agent]) {
        let desired = Dictionary(
            uniqueKeysWithValues: agents.compactMap { agent -> (UUID, Agent)? in
                guard agent.provider == .codex || agent.provider == .claude else {
                    // Provider-enum doesn't include `.gemini` until PR 4. The
                    // monitor remains dormant until then; tests drive `apply*`
                    // entry points directly without a real Observer.
                    return nil
                }
                return nil
            }
        )

        for agentId in observers.keys where desired[agentId] == nil {
            observers.removeValue(forKey: agentId)?.stop()
        }
    }

    func stopAll() {
        for observer in observers.values {
            observer.stop()
        }
        observers.removeAll()
    }

    func removeObserver(for agentId: UUID) {
        observers.removeValue(forKey: agentId)?.stop()
        clearAgentState(for: agentId)
    }

    func sendMessage(for agentId: UUID, text: String, imageData: [Data] = []) {
        observers[agentId]?.sendPrompt(text: text, imageData: imageData)
    }

    func interrupt(for agentId: UUID) {
        observers[agentId]?.cancel()
    }

    func respondToApproval(for agentId: UUID, optionId: String) {
        guard let pending = pendingApprovalRequests[agentId] else { return }
        observers[agentId]?.respondToPermission(
            acpRequestId: pending.acpRequestId,
            outcome: .selected(optionId: optionId)
        )
        emit(.promptResolved(id: pending.promptId), for: agentId)
        pendingApprovalRequests.removeValue(forKey: agentId)
    }

    func cancelApproval(for agentId: UUID) {
        guard let pending = pendingApprovalRequests[agentId] else { return }
        observers[agentId]?.respondToPermission(
            acpRequestId: pending.acpRequestId,
            outcome: .cancelled
        )
        emit(.promptResolved(id: pending.promptId), for: agentId)
        pendingApprovalRequests.removeValue(forKey: agentId)
    }

    func setMode(for agentId: UUID, modeId: String) {
        observers[agentId]?.setMode(modeId: modeId)
        var update = SessionMetadataUpdate()
        update.currentModeId = .set(modeId)
        emit(.metadataUpdated(update), for: agentId)
    }

    func setModel(for agentId: UUID, modelId: String) {
        observers[agentId]?.setModel(modelId: modelId)
        var update = SessionMetadataUpdate()
        update.currentModelId = .set(modelId)
        emit(.metadataUpdated(update), for: agentId)
    }

    // MARK: - Internal emit (also used by tests)

    func emit(_ event: SessionEvent, for agentId: UUID) {
        onSessionEvent?(agentId, event)
    }

    /// Records a locally-sent user message before the agent echoes it back.
    /// Mirrors Codex's `recordSentUserMessage`: a `local-user-*` id is created
    /// up front so the transcript shows the user's text immediately.
    func recordSentUserMessage(for agentId: UUID, text: String, imageData: [Data] = []) {
        guard !text.isEmpty || !imageData.isEmpty else { return }
        let localId = "local-user-\(UUID().uuidString)"
        pendingLocalUserMessages[agentId, default: []].append(
            PendingLocalUserMessage(id: localId, text: text, imageData: imageData)
        )
        emit(
            .transcriptUpsert(SessionTranscriptItem(
                id: localId,
                kind: .userMessage,
                text: text,
                createdAt: Date(),
                imageData: imageData
            )),
            for: agentId
        )
    }

    func recordSystemTranscript(for agentId: UUID, text: String) {
        emit(
            .transcriptUpsert(SessionTranscriptItem(
                id: "system-\(UUID().uuidString)",
                kind: .systemMessage,
                text: text,
                createdAt: Date()
            )),
            for: agentId
        )
    }

    private func clearAgentState(for agentId: UUID) {
        pendingApprovalRequests.removeValue(forKey: agentId)
        debugMessages.removeValue(forKey: agentId)
        pendingLocalUserMessages.removeValue(forKey: agentId)
        activeAssistantStreamId.removeValue(forKey: agentId)
        activeThoughtStreamId.removeValue(forKey: agentId)
        toolCallSnapshots.removeValue(forKey: agentId)
    }

    // MARK: - Internal accessors used by +SessionEvents extension

    func consumeAssistantStreamId(for agentId: UUID) -> String? {
        activeAssistantStreamId.removeValue(forKey: agentId)
    }

    func ensureAssistantStreamId(for agentId: UUID) -> (id: String, isNew: Bool) {
        if let existing = activeAssistantStreamId[agentId] {
            return (existing, false)
        }
        let id = "gemini-stream-\(UUID().uuidString)"
        activeAssistantStreamId[agentId] = id
        return (id, true)
    }

    func consumeThoughtStreamId(for agentId: UUID) -> String? {
        activeThoughtStreamId.removeValue(forKey: agentId)
    }

    func ensureThoughtStreamId(for agentId: UUID) -> (id: String, isNew: Bool) {
        if let existing = activeThoughtStreamId[agentId] {
            return (existing, false)
        }
        let id = "gemini-thought-\(UUID().uuidString)"
        activeThoughtStreamId[agentId] = id
        return (id, true)
    }

    func setPendingApproval(_ pending: PendingApproval, for agentId: UUID) {
        pendingApprovalRequests[agentId] = pending
    }

    func mergeToolCall(_ snapshot: ToolCallSnapshot, for agentId: UUID) {
        toolCallSnapshots[agentId, default: [:]][snapshot.toolCallId] = snapshot
    }

    func currentToolCall(_ toolCallId: String, for agentId: UUID) -> ToolCallSnapshot? {
        toolCallSnapshots[agentId]?[toolCallId]
    }

    func dropToolCall(_ toolCallId: String, for agentId: UUID) {
        toolCallSnapshots[agentId]?.removeValue(forKey: toolCallId)
    }

    /// Pop the oldest pending local user message matching `text`. Returns
    /// `nil` if there's no match — the agent emitted a user_message_chunk
    /// from session-history hydration rather than echoing a fresh prompt.
    func popPendingLocalUserMessage(for agentId: UUID, matching text: String) -> PendingLocalUserMessage? {
        guard var pending = pendingLocalUserMessages[agentId],
              let index = pending.firstIndex(where: { $0.text == text })
        else { return nil }
        let popped = pending.remove(at: index)
        pendingLocalUserMessages[agentId] = pending.isEmpty ? nil : pending
        return popped
    }

    /// Mid-turn cancel: clears any active streaming ids so a fresh turn
    /// allocates new transcript items rather than appending to the cancelled
    /// stream's bubble.
    func resetTurnState(for agentId: UUID) {
        activeAssistantStreamId.removeValue(forKey: agentId)
        activeThoughtStreamId.removeValue(forKey: agentId)
    }
}

// MARK: - Tool call snapshot

/// Cached state for an in-flight tool call. The agent emits one `tool_call`
/// then arbitrary `tool_call_update`s; the monitor merges partial fields here.
struct ToolCallSnapshot: Equatable {
    let toolCallId: String
    var title: String
    var kind: GeminiAcpProtocol.ToolKind?
    var status: GeminiAcpProtocol.ToolCallStatus?
    var locations: [GeminiAcpProtocol.ToolCallLocation]
    var contentSummary: String

    /// Treat anything that's not pending/in_progress as terminal.
    var isTerminal: Bool {
        switch status {
        case .completed?, .failed?: true
        default: false
        }
    }
}

// MARK: - Observer (private)

/// Wraps one `gemini --acp` process. Owns the JSON-RPC client and routes
/// incoming protocol events back to the monitor via injected callbacks.
///
/// This class is not actively wired into the production app yet; the
/// `AgentProvider.gemini` case lands in PR 4 along with coordinator routing.
/// Tests drive the monitor's `apply*` entry points directly without spawning
/// a process.
private final class Observer: @unchecked Sendable {
    let agent: Agent
    private let onIncomingFrame: (UUID, GeminiAcpRpc.IncomingFrame) -> Void
    private let onProcessExit: (UUID) -> Void
    private let onSpawnError: (UUID, Error) -> Void

    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let stdinPipe = Pipe()
    private let queue: DispatchQueue
    private var stdoutBuffer = Data()
    private var didStart = false

    init(
        agent: Agent,
        onIncomingFrame: @escaping (UUID, GeminiAcpRpc.IncomingFrame) -> Void,
        onProcessExit: @escaping (UUID) -> Void,
        onSpawnError: @escaping (UUID, Error) -> Void
    ) {
        self.agent = agent
        self.onIncomingFrame = onIncomingFrame
        self.onProcessExit = onProcessExit
        self.onSpawnError = onSpawnError
        self.queue = DispatchQueue(label: "GeminiAcpMonitor.\(agent.id.uuidString)")
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        process.executableURL = URL(fileURLWithPath: Self.geminiExecutablePath())
        process.arguments = ["--acp"]
        process.currentDirectoryURL = agent.folder
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeStdout(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] _ in
            // Drained for backpressure; debug capture not implemented yet.
        }
        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            queue.async {
                self.handleProcessExit()
            }
        }

        do {
            try process.run()
        } catch {
            onSpawnError(agent.id, error)
        }
    }

    func stop() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
    }

    func sendRequest(method: String, params: some Encodable, id: GeminiAcpRpc.Id) {
        let request = GeminiAcpRpc.Request(id: id, method: method, params: params)
        writeFrame(request)
    }

    func sendNotification(method: String, params: some Encodable) {
        let note = GeminiAcpRpc.Notification(method: method, params: params)
        writeFrame(note)
    }

    func sendResponse(id: GeminiAcpRpc.Id, result: some Encodable) {
        let response = GeminiAcpRpc.Response(id: id, result: result)
        writeFrame(response)
    }

    func sendPrompt(text: String, imageData: [Data]) {
        // Wired up in PR 4 along with coordinator integration.
        _ = (text, imageData)
    }

    func cancel() {
        // Wired up in PR 4.
    }

    func setMode(modeId: String) {
        _ = modeId
    }

    func setModel(modelId: String) {
        _ = modelId
    }

    func respondToPermission(
        acpRequestId: GeminiAcpRpc.Id,
        outcome: GeminiAcpProtocol.RequestPermissionOutcome
    ) {
        let response = GeminiAcpProtocol.RequestPermissionResponse(outcome: outcome)
        sendResponse(id: acpRequestId, result: response)
    }

    private func writeFrame(_ value: some Encodable) {
        guard process.isRunning else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard var data = try? encoder.encode(value) else { return }
        data.append(0x0A) // newline
        stdinPipe.fileHandleForWriting.write(data)
    }

    private func consumeStdout(_ data: Data) {
        guard !data.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            stdoutBuffer.append(data)
            processBufferedLines()
        }
    }

    private func processBufferedLines() {
        while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
            let lineData = stdoutBuffer.prefix(upTo: newlineIndex)
            stdoutBuffer.removeSubrange(...newlineIndex)
            guard !lineData.isEmpty else { continue }
            handleLine(Data(lineData))
        }
    }

    private func handleLine(_ data: Data) {
        let decoded = try? GeminiAcpRpc.decodeIncoming(data)
        guard let frame = decoded ?? nil else { return }
        let agentId = agent.id
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            onIncomingFrame(agentId, frame)
        }
    }

    private func handleProcessExit() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        let agentId = agent.id
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            onProcessExit(agentId)
        }
    }

    private static func geminiExecutablePath() -> String {
        let candidates = [
            NSHomeDirectory() + "/.local/bin/gemini",
            "/usr/local/bin/gemini",
            "/opt/homebrew/bin/gemini",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "gemini"
    }
}

// swiftlint:enable file_length
