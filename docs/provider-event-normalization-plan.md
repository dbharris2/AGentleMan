# Provider Event Normalization Plan

## Summary

Create a shared app-level event and state contract for SecretAgentMan so Claude and Codex feed one common session model instead of each provider maintaining its own app-facing dictionaries and UI-facing behavior. Keep provider-specific parsing, recovery, and protocol quirks inside the monitors, and make shared UI and coordination logic consume normalized state, transcript items, prompts, and metadata snapshots.

This work is intended to reduce long-term product drift between Claude and Codex support by strengthening the shared core instead of adding more provider-specific UI logic.

## Key Changes

- Introduce a shared app-owned normalization contract covering:
  - `SessionRunState`
  - `TranscriptItemKind`
  - `SessionTranscriptItem`
  - `SessionPromptRequest`
  - provider-neutral prompt question/option types
  - `SessionMetadataSnapshot`
  - `SessionMetadataUpdate`
  - `SessionEvent`
  - `AgentSessionSnapshot` as the authoritative per-agent reduced state
- Keep provider-specific logic local:
  - `ClaudeStreamMonitor` remains responsible for parsing Claude JSONL and stream events, transcript hydration, approval handling, elicitation handling, slash commands, permission modes, active tool updates, and Claude-specific recovery.
  - `CodexAppServerMonitor` remains responsible for parsing app-server events, approval handling, user-input handling, model and collaboration metadata, streaming deltas, and Codex-specific recovery.
  - Both monitors emit only normalized `SessionEvent` values to shared consumers.
- Make `AgentSessionCoordinator` the shared authoritative reducer:
  - receive normalized events from both providers
  - reduce them in-order per agent
  - publish a new `AgentSessionSnapshot` after every reduced event
  - expose the current snapshot immediately to late subscribers or newly-mounted views
  - keep terminal state rules inside the monitor-to-event normalization boundary rather than scattered across views
- Define the initial normalized transcript model:
  - supported kinds: `userMessage`, `assistantMessage`, `systemMessage`, `toolActivity`, `plan`, `diffSummary`, `error`
  - support both full-item upserts and streaming text deltas
  - monitors are responsible for emitting one canonical ID per logical transcript item
  - hydration and live streaming must converge on the same canonical logical item
  - attachment references use lightweight handles or URLs, not raw `Data`
- Define the initial normalized prompt model:
  - use one shared approval prompt shape for both providers
  - use one shared structured-input prompt shape for both providers
  - support one visible active prompt per agent in shared state
  - if a second prompt arrives while one is active, queue it in arrival order and surface it only after the active prompt resolves
  - do not silently drop or auto-resolve queued prompts
- Define the initial normalized metadata model:
  - display model name
  - raw model identifier
  - context usage percentage
  - permission mode
  - collaboration mode
  - active tool name
  - slash commands or capability-derived actions when available
- Lock down content modeling for provider-sensitive transcript kinds:
  - `plan` and `diffSummary` remain string-backed in v1
  - both providers must normalize those kinds into the shared `text` field only
  - no provider-specific structured payloads for those kinds in v1

## Interfaces

The shared types should be app-owned and provider-neutral. Providers may emit partial metadata updates, and the shared model should normalize only app-consumed behavior rather than every raw protocol detail.

Conceptual shapes:

```swift
enum SessionRunState: Equatable {
    case idle
    case running
    case needsPermission
    case needsInput
    case finished
    case error(message: String?)
}

enum TranscriptItemKind: Equatable {
    case userMessage
    case assistantMessage
    case systemMessage
    case toolActivity
    case plan
    case diffSummary
    case error
}

struct SessionTranscriptItem: Identifiable, Equatable {
    let id: String
    let kind: TranscriptItemKind
    let text: String
    let isStreaming: Bool
    let createdAt: Date?
    let imageReferences: [URL]
    let metadata: TranscriptItemMetadata?
}

struct TranscriptItemMetadata: Equatable {
    let toolName: String?
    let displayTitle: String?
    let providerItemType: String?
}

enum SessionPromptRequest: Equatable, Identifiable {
    case approval(ApprovalPrompt)
    case userInput(UserInputPrompt)
}

struct ApprovalPrompt: Equatable {
    let id: String
    let title: String
    let message: String
    let options: [String]
}

struct UserInputPrompt: Equatable {
    let id: String
    let title: String
    let message: String
    let questions: [PromptQuestion]
}

struct PromptQuestion: Equatable {
    let id: String
    let header: String
    let question: String
    let allowsOther: Bool
    let options: [PromptOption]
}

struct PromptOption: Equatable {
    let label: String
    let description: String
}

struct SessionMetadataSnapshot: Equatable {
    var sessionId: String?
    var displayModelName: String?
    var rawModelName: String?
    var contextPercentUsed: Double?
    var permissionMode: String?
    var collaborationMode: String?
    var activeToolName: String?
    var slashCommands: [String]?
}

enum MetadataFieldUpdate<Value: Equatable>: Equatable {
    case unchanged
    case set(Value)
    case clear
}

struct SessionMetadataUpdate: Equatable {
    var sessionId: MetadataFieldUpdate<String> = .unchanged
    var displayModelName: MetadataFieldUpdate<String> = .unchanged
    var rawModelName: MetadataFieldUpdate<String> = .unchanged
    var contextPercentUsed: MetadataFieldUpdate<Double> = .unchanged
    var permissionMode: MetadataFieldUpdate<String> = .unchanged
    var collaborationMode: MetadataFieldUpdate<String> = .unchanged
    var activeToolName: MetadataFieldUpdate<String> = .unchanged
    var slashCommands: MetadataFieldUpdate<[String]> = .unchanged
}

enum SessionEvent: Equatable {
    case sessionReady(sessionId: String)
    case runStateChanged(SessionRunState)
    case transcriptUpsert(SessionTranscriptItem)
    case transcriptDelta(id: String, appendedText: String)
    case transcriptFinished(id: String)
    case promptPresented(SessionPromptRequest)
    case promptResolved(id: String)
    case metadataUpdated(SessionMetadataUpdate)
}

struct AgentSessionSnapshot: Equatable {
    var runState: SessionRunState = .idle
    var transcript: [SessionTranscriptItem] = []
    var activePrompt: SessionPromptRequest?
    var queuedPrompts: [SessionPromptRequest] = []
    var metadata: SessionMetadataSnapshot = .init()
    var hasUnread: Bool = false
}
```

Semantics:

- `SessionMetadataSnapshot` is stored state.
- `SessionMetadataUpdate` is an event payload.
- Metadata omission means `unchanged`, not clear.
- Clearing a field requires explicit `.clear`.
- Reducer logic applies each `MetadataFieldUpdate` onto the existing snapshot field-by-field.
- `providerItemType` is debug-only metadata; view and reducer logic must not branch on it.
- `sessionReady(sessionId:)` writes `metadata.sessionId` in the shared snapshot.
- A later `sessionReady` for the same agent is treated as a session replacement event:
  - update `metadata.sessionId`
  - reset `runState` to `.idle`
  - clear transcript
  - clear `activePrompt`
  - clear `queuedPrompts`
  - preserve other metadata only if the monitor re-emits it for the new session during normal event flow

## Boundary Rules

### Reducer Contract

- `AgentSessionCoordinator` is the authoritative reducer for normalized session state.
- Event ordering is guaranteed per agent in arrival order from the monitor.
- Events for different agents may be processed independently.
- The reducer may be stateful, but it must be deterministic for a given prior snapshot plus ordered event stream.
- A new `AgentSessionSnapshot` is published after every reduced event.
- Late subscribers must be able to read the current snapshot immediately without waiting for a new event.
- Views and downstream stores must read shared session snapshots rather than monitor-owned provider dictionaries once migrated.
- `.error` is non-terminal:
  - it updates `runState` to `.error(message:)`
  - it does not clear transcript, active prompt, or queued prompts
  - a later `.running`, `.idle`, `.needsPermission`, `.needsInput`, or `.finished` replaces the error state through normal reduction
- `transcriptFinished(id:)` is the source of truth for ending streaming state:
  - reducer flips the matching item to `isStreaming = false`
  - `transcriptDelta` requires the item to be streaming
  - later `transcriptUpsert` may still replace content, but should not be required just to end streaming

### Terminal Normalization Rules

- Terminal signals are never exposed directly through `SessionEvent`.
- Each monitor decides whether a terminal signal should emit a normalized state event or be suppressed.
- Claude:
  - terminal state is never authoritative for normalized running or waiting states
  - Claude terminal signals may only contribute to `.finished` if the Claude monitor has no more authoritative stream state indicating active, approval, or input waiting
  - otherwise terminal signals are suppressed at normalization time
- Codex:
  - terminal `.active` is suppressed whenever runtime status, approval state, or input state is more specific
  - Codex terminal `.finished` may emit `runStateChanged(.finished)` only when the monitor has no active runtime state, no pending approval, and no pending user-input request
  - terminal state never overrides `.needsPermission` or `.needsInput`

### Transcript Identity Rules

- Canonical transcript IDs are owned by the monitors, not by the reducer.
- Each monitor must emit a single canonical ID per logical transcript item.
- If hydration and live streaming reference the same logical item with different provider-native IDs, the monitor must reconcile that before emitting normalized events.
- Reconciliation happens inside the monitor by rewriting later events to the already-emitted canonical ID.
- The reducer never guesses transcript merges by text alone.
- A `transcriptDelta` must always reference a canonical ID that either already exists in shared state or will be created by the same monitor’s immediately-related upsert flow.

### Prompt Queue Policy

- Shared state shows one visible active prompt per agent.
- Additional prompts are queued in arrival order.
- Resolving the active prompt promotes the next queued prompt immediately.
- If `promptResolved(id:)` targets a queued but not active prompt, remove that queued prompt in place and do not affect the active prompt.
- If `promptResolved(id:)` targets neither the active prompt nor any queued prompt, treat it as a no-op.
- This is an intentional product policy choice, not an invariant about provider behavior.

## Provider Mapping

### Claude Mapping

- Claude assistant streaming text becomes `transcriptDelta`
- Claude completed assistant, user, and system rows become `transcriptUpsert`
- Claude approval requests become `promptPresented(.approval(...))`
- Claude elicitation requests become `promptPresented(.userInput(...))`
- Claude prompt completion becomes `promptResolved`
- Claude permission mode, active tool, model info, context usage, and slash commands become `metadataUpdated`
- Claude hydrated transcript history becomes normalized transcript upserts using canonical IDs that match the corresponding live logical items

### Codex Mapping

- Codex `thread/status/changed` becomes `runStateChanged`
- Codex `item/agentMessage/delta` becomes `transcriptDelta`
- Codex completed transcript items become `transcriptUpsert` or `transcriptFinished`
- Codex approval requests become `promptPresented(.approval(...))`
- Codex `item/tool/requestUserInput` becomes `promptPresented(.userInput(...))`
- Codex prompt resolution becomes `promptResolved`
- Codex model, raw model, collaboration mode, context usage, and active tool updates become `metadataUpdated`

## Migration Plan

### Phase 1

- Add the shared normalized types and event contract.
- Teach both monitors to emit normalized `SessionEvent` values in parallel with their existing state dictionaries and callbacks.
- Add debug-only invariant checks comparing normalized reduced state against the existing provider-specific state for a short bake period.
- Log or assert on drift in:
  - run state
  - active prompt visibility
  - transcript item count only
  - model and active-tool metadata where both systems expose them
- Keep canonical transcript ID checks inside monitor-level golden tests rather than dual-store invariants, because the normalized canonical ID layer intentionally does not match legacy dictionary keys during the bake period.

### Phase 2

- Move shared consumers to read from normalized session state instead of provider-specific monitor dictionaries where possible.
- Make `AgentSessionCoordinator` the only authoritative reducer for shared session updates.
- Preserve current visible behavior during migration, including:
  - Codex terminal state remaining secondary to runtime approval and input state
  - Claude terminal state remaining non-authoritative
  - existing transcript hydration behavior

### Phase 3

- Remove duplicated provider-specific app-facing state once shared-state parity is confirmed.
- Keep only provider-local parsing, recovery, ID reconciliation, and protocol-specific translation inside the monitors.

## Test Plan

- Shared reducer tests:
  - identical state transitions for Claude-emitted and Codex-emitted normalized events
  - metadata update semantics for `.unchanged`, `.set`, and `.clear`
  - `sessionReady` replacement semantics
  - error-state replacement semantics
  - prompt queue promotion and resolution
  - publish-after-every-event snapshot behavior
  - `transcriptFinished(id:)` flipping `isStreaming` to `false`
- Monitor-level golden tests:
  - given raw Claude input, emit exactly the expected normalized event sequence
  - given raw Codex protocol input, emit exactly the expected normalized event sequence
  - verify terminal signals are converted or suppressed per provider rules
  - verify hydration and streaming converge on the same canonical transcript IDs
- Transcript behavior tests:
  - assistant deltas append to the correct shared item
  - completed items replace or finalize streamed placeholders
  - hydrated transcript history merges without duplicate visible rows
  - plan and diff summary content remain normalized into the shared `text` field only
- Coordinator behavior tests:
  - shared UI consumers can render session state, transcript, and active prompt without branching on provider
  - late subscribers can read the current snapshot immediately
  - Codex terminal events do not override normalized approval or input states
  - Claude terminal events remain non-authoritative

## Assumptions And Defaults

- Target scope is limited to the shared event and state contract plus the migration path.
- This plan does not include broader feature work such as unread badges, response-required notifications, worktree flows, or remote-backend features.
- The normalized model is intentionally minimal and should only cover behavior already used by the app or clearly needed for near-term shared UX.
- `plan` and `diffSummary` stay string-backed in v1 to avoid introducing divergent provider-specific payload schemas during the normalization rollout.
- Session restart or thread replacement resets transcript and prompt state rather than persisting prior-session conversation into the new session snapshot.
- Provider-specific raw event details may still exist internally for debugging, but shared UI and coordination logic should depend only on the normalized contract.
