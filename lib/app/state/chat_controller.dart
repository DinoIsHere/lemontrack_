import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/block_repository.dart';
import '../../data/settings/settings_repository.dart';
import '../../domain/ai/llm_client.dart';
import '../../domain/ai/prompt_builder.dart';
import '../../domain/ai/tool_executor.dart';
import '../../domain/ai/tool_registry.dart';
import '../../domain/ai/providers/openai_client.dart';
import '../../domain/ai/providers/gemini_client.dart';
import '../../domain/models/time_block.dart';

class ChatUiMessage {
  final String id;
  final String role; // user | assistant
  final String text;
  final ToolResult? result;
  final bool pending;

  const ChatUiMessage({required this.id, required this.role, this.text = '', this.result, this.pending = false});

  ChatUiMessage copyWith({String? text, bool? pending}) => ChatUiMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        result: result,
        pending: pending ?? this.pending,
      );
}

class ChatState {
  final List<ChatUiMessage> messages;
  final bool busy;
  const ChatState({this.messages = const [], this.busy = false});
}

class ChatController extends StateNotifier<ChatState> {
  final Ref _ref;
  final _uuid = const Uuid();
  late final ToolExecutor _executor = ToolExecutor(_ref.read(blockRepositoryProvider));

  ChatController(this._ref) : super(const ChatState()) {
    state = ChatState(messages: [
      ChatUiMessage(
        id: _uuid.v4(),
        role: 'assistant',
        text: 'LemonTrack ready. Try "create gym at 18:00 for 45 min", "move standup to 11:30", "find 45 min", "what\'s left today", or "summarize my day".',
      ),
    ]);
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.busy) return;
    state = ChatState(
      busy: true,
      messages: [...state.messages, ChatUiMessage(id: _uuid.v4(), role: 'user', text: text)],
    );
    try {
      final settings = await _ref.read(settingsControllerProvider.future);
      final client = await _buildClient(settings);
      if (client != null) {
        await _runLlmTurn(client, text);
      } else {
        await _runRuleBased(text);
      }
    } catch (e) {
      dev.log('chat error', error: e);
      _pushAssistant('Error: $e');
    } finally {
      state = ChatState(messages: state.messages, busy: false);
    }
  }

  Future<void> _runRuleBased(String text) async {
    final result = await _executor.handleNaturalLanguage(text);
    if (result == null) {
      _pushAssistant('I did not understand. Try: "create gym at 18:00 for 45 min", "move standup to 11:30", "shift afternoon back 30 min", "find 45 min tomorrow", "complete thesis", "delete email", "what\'s left today", "summarize my day".');
      return;
    }
    if (!result.ok) {
      _pushAssistant(result.reply);
      return;
    }
    _pushAssistant(result.reply, result: result.changes.isNotEmpty || result.conflicts.isNotEmpty ? result : null);
  }

  Future<void> _runLlmTurn(LlmClient client, String text) async {
    final placeholder = ChatUiMessage(id: _uuid.v4(), role: 'assistant', pending: true);
    state = ChatState(messages: [...state.messages, placeholder], busy: true);

    final history = <LlmMessage>[
      LlmMessage('system', PromptBuilder.systemPrompt(llmMode: true)),
      LlmMessage('user', text),
    ];

    final collected = <ToolResult>[];
    var totalCalls = 0;

    try {
      for (var i = 0; i < 5; i++) {
        final resp = await client.send(history, ToolRegistry.tools);
        if (!resp.hasToolCalls) {
          _finish(placeholder.id, resp.text ?? 'Done.', collected);
          return;
        }
        history.add(LlmMessage('assistant', resp.text ?? '', toolCalls: resp.toolCalls));
        for (final call in resp.toolCalls) {
          ToolResult result;
          if (totalCalls >= 5) {
            result = ToolResult.error(call.name, 'VALIDATION_FAILED', 'Tool call limit reached. Ask the user.');
          } else {
            totalCalls++;
            result = await _executor.executeTool(call.name, call.args);
            collected.add(result);
          }
          history.add(LlmMessage(
            'tool',
            result.ok ? result.reply : result.reply,
            toolCallId: call.id,
            toolName: call.name,
          ));
        }
      }
      _finish(placeholder.id, 'Done.', collected);
    } catch (e) {
      dev.log('llm error', error: e);
      _finish(placeholder.id, 'AI request failed: $e', collected);
      await _runRuleBased(text);
    }
  }

  Future<LlmClient?> _buildClient(SettingsState settings) async {
    if (!settings.llmEnabled) return null;
    final repo = _ref.read(settingsRepositoryProvider);
    switch (settings.settings.aiProvider) {
      case AiProvider.openai:
        final key = await repo.getApiKey('openai');
        if (key == null) return null;
        final model = settings.settings.aiModelName.isEmpty ? 'gpt-4o-mini' : settings.settings.aiModelName;
        return OpenAiClient(apiKey: key, model: model);
      case AiProvider.gemini:
        final key = await repo.getApiKey('gemini');
        if (key == null) return null;
        final model = settings.settings.aiModelName.isEmpty ? 'gemini-1.5-flash' : settings.settings.aiModelName;
        return GeminiClient(apiKey: key, model: model);
      case AiProvider.ruleBased:
        return null;
    }
  }

  void _pushAssistant(String text, {ToolResult? result}) {
    state = ChatState(
      messages: [...state.messages, ChatUiMessage(id: _uuid.v4(), role: 'assistant', text: text, result: result)],
      busy: state.busy,
    );
  }

  void _finish(String placeholderId, String text, List<ToolResult> results) {
    final out = <ChatUiMessage>[];
    for (final m in state.messages) {
      if (m.id != placeholderId) {
        out.add(m);
        continue;
      }
      out.add(m.copyWith(text: text, pending: false));
      for (final r in results) {
        if (r.changes.isNotEmpty || r.conflicts.isNotEmpty) {
          out.add(ChatUiMessage(id: _uuid.v4(), role: 'assistant', text: '', result: r));
        }
      }
    }
    state = ChatState(messages: out, busy: state.busy);
  }

  Future<void> undo(String actionLogId) async {
    final result = await _executor.undo(actionLogId);
    _pushAssistant(result.reply);
  }

  void clear() => state = const ChatState();
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) => ChatController(ref));
