# 08 AI Assistant

Owner: AI Agent. Lives in `lib/domain/ai/` (logic) and `lib/screens/chat/` (UI). Uses the tool contract in `05`.

## Architecture

```
ChatScreen ──▶ ChatController (Riverpod)
                  │
                  ├─▶ PromptBuilder  (system prompt + day context)
                  ├─▶ LlmClient      (interface)
                  │       ├─ OpenAiClient       (function calling)
                  │       ├─ GeminiClient       (function calling)
                  │       └─ RuleBasedClient    (offline fallback)
                  └─▶ ToolExecutor   (validates, runs use cases, builds envelopes)
```

## LlmClient interface

```dart
abstract interface class LlmClient {
  String get providerName;

  /// Streams assistant text and tool call requests for one model turn.
  Stream<LlmEvent> run({
    required List<ChatMessage> history,
    required String systemPrompt,
    required List<ToolSpec> tools,
  });
}

sealed class LlmEvent {}
class TextDelta extends LlmEvent { final String text; TextDelta(this.text); }
class ToolCallRequest extends LlmEvent {
  final String callId;
  final String name;
  final Map<String, dynamic> arguments;
  ToolCallRequest(this.callId, this.name, this.arguments);
}
class TurnEnd extends LlmEvent { final String stopReason; TurnEnd(this.stopReason); }
class LlmError extends LlmEvent { final String message; LlmError(this.message); }
```

## Turn loop

1. Append the user message to history and persist it.
2. Build the system prompt with current date, local timezone, workday hours, category ids, and a short summary of today's blocks (titles and times only, max 30 blocks).
3. Call `LlmClient.run`.
4. For each `TextDelta`, append to the streaming assistant message.
5. For each `ToolCallRequest`:
   a. Persist the assistant message with the tool call.
   b. Execute via `ToolExecutor`.
   c. Persist a `tool` role message with the envelope as JSON.
   d. Continue the loop with the updated history.
6. On `TurnEnd`, persist the final assistant message.
7. Stop when the model returns no tool calls, or after 5 tool calls in one user turn (`05`, rule 7).

Errors from the provider: show a retry chip. Do not drop the user's message.

## System prompt (contract)

The prompt below is the baseline. Keep it under 900 tokens.

```text
You are LemonTrack's scheduling assistant. You help the user plan and track time blocks.

Context:
- Today (local): {{local_date}}, timezone {{tz}}, time now {{local_time}}.
- Workday: {{workday_start}} to {{workday_end}}. Snap: {{snap_minutes}} min.
- Categories: deep_work, meetings, study, health, admin, personal.
- Today's blocks: {{compact_day_list}}

Rules:
1. Use tools for every change. Never claim a change happened without a successful tool result.
2. Use find_free_slot before create_block when the user gives no exact time.
3. Use get_day or get_range before editing when you need block ids.
4. Use summarize_day to answer questions about totals.
5. When a tool result has conflicts, say so in one short sentence and offer one fix.
6. Ask one short clarifying question if the request is ambiguous. Do not ask more than one.
7. Never delete more than one block without explicit user confirmation.
8. Keep replies under 60 words unless the user asks for detail.
9. Times in replies use 24-hour HH:mm in the user's timezone.
10. You cannot access anything outside LemonTrack's data. Do not invent blocks.
```

## Context injection rules

- Only inject today's blocks, not the whole database. The model calls `get_range` for other days.
- Refresh the block list in the system prompt at the start of each user turn.
- Never inject the API key, the user's name, or device info.

## Tool executor

```dart
class ToolExecutor {
  ToolExecutor({required this.registry, required this.clock, required this.actionLog});
  Future<ToolEnvelope> execute(String name, Map<String, dynamic> args, {required String conversationId});
}
```

Steps (from `05`):

1. Look up `name` in `ToolRegistry`. Unknown → `VALIDATION_FAILED`.
2. Validate args with a small JSON Schema validator (or hand-written checks per tool for the prototype). Reject extra properties.
3. Parse dates. Accept `YYYY-MM-DDTHH:mm:ss±HH:MM`. Reject ambiguous forms like "tomorrow" (the model must resolve them first).
4. Run the use case in a transaction.
5. Build the `changes` array from before and after snapshots.
6. Attach `action_log_id`.

The executor is the **only** place where the AI can change data.

## Diff cards

After every write tool, the chat shows a card built from `changes`:

- Header: action label and count ("Moved 3 blocks").
- Rows: title, before time → after time, both in mono.
- Footer: conflicts (if any) and an `Undo` button.

Undo calls `ActionLogRepository` and restores `before` through the same use cases. Undo is available until the next user turn, or 5 minutes, whichever is first.

## Providers

### OpenAI and Gemini

- Use the provider's native function-calling format. Map `ToolSpec` to the provider's schema. Keep the JSON Schema from `05` unchanged.
- Stream text. Buffer tool call argument deltas until the call is complete.
- Timeouts: 20s to first token, 60s total per turn.
- API key comes from secure storage. Never log request bodies. Redact the `Authorization` header in debug logs.

### RuleBasedClient (offline and fallback)

Used when no key is set, when the key is invalid, or when the network fails. It handles a fixed set of intents with regex and keyword matching:

| Intent pattern | Action |
|---|---|
| "what's left", "what's next" | `get_day` for today, then a text list of upcoming blocks |
| "summarize", "how did today go" | `summarize_day` |
| "move|push|shift .* (\d+) ?(min|minutes|hours)" | `shift_following` from now |
| "add|create|schedule (.+) (at|for) (\d{1,2}(:\d{2})?)" | `create_block` with the parsed time |
| "find (\d+) ?min" | `find_free_slot` then `create_block` if the user confirms |
| "delete|remove (.+)" | `get_day`, match title, `delete_block` (single match only) |

Responses are short templates. The rule-based client must never invent a block id. Unmatched input returns a fixed reply listing the supported phrases.

Mark the chat status chip "Rule-based" whenever this client is active.

## Safety and privacy

- Chat history stays on the device. Only the current turn's context is sent to the provider.
- The user sees a one-time notice in onboarding: "Your schedule summary is sent to the AI provider you choose. Choose rule-based mode to keep everything on-device."
- Filter the user's messages for prompt injection attempts only as far as tools go: tool permissions do not change based on message content. The tool layer enforces rules, not the prompt.
- No tool can run shell code, read files, or reach the network.

## Evaluation (demo quality)

Maintain `test/ai/eval_cases.json` with 25 prompts and expected tool calls. Run them against the rule-based client in CI, and against a live provider manually before the demo. Pass criteria:

- Tool name matches expected: 90% or higher.
- Arguments match after normalization: 80% or higher.
- No invented block ids: 100%.
