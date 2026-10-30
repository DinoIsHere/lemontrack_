import 'dart:convert';
import 'package:dio/dio.dart';
import '../llm_client.dart';

class OpenAiClient implements LlmClient {
  final Dio _dio;
  final String apiKey;
  final String model;

  OpenAiClient({required this.apiKey, this.model = 'gpt-4o-mini', Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<LlmResponse> send(List<LlmMessage> messages, List<Map<String, dynamic>> tools) async {
    final body = {
      'model': model,
      'temperature': 0.2,
      'tools': tools.map((t) => {'type': 'function', 'function': t}).toList(),
      'messages': [
        for (final m in messages)
          if (m.role == 'tool')
            {'role': 'tool', 'tool_call_id': m.toolCallId, 'content': m.content}
          else if (m.toolCalls.isNotEmpty)
            {
              'role': 'assistant',
              'content': m.content.isEmpty ? null : m.content,
              'tool_calls': [
                for (final tc in m.toolCalls)
                  {
                    'id': tc.id,
                    'type': 'function',
                    'function': {'name': tc.name, 'arguments': jsonEncode(tc.args)},
                  }
              ],
            }
          else
            {'role': m.role, 'content': m.content},
      ],
    };

    final resp = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {'Authorization': 'Bearer $apiKey'},
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
      data: body,
    );

    final msg = resp.data['choices'][0]['message'] as Map<String, dynamic>? ?? {};
    final calls = <ToolCall>[];
    for (final tc in (msg['tool_calls'] as List? ?? [])) {
      final fn = tc['function'] as Map;
      Map<String, dynamic> args;
      final raw = fn['arguments'];
      try {
        args = raw is String ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        args = {};
      }
      calls.add(ToolCall(id: tc['id'] as String? ?? 'call_${calls.length}', name: fn['name'] as String, args: args));
    }
    return LlmResponse(text: msg['content'] as String?, toolCalls: calls);
  }

  @override
  Future<void> testConnection() async {
    await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}, receiveTimeout: const Duration(seconds: 20)),
      data: {
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'ping'}
        ],
        'max_tokens': 1,
      },
    );
  }
}
