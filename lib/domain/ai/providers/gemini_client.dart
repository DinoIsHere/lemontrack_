import 'package:dio/dio.dart';
import '../llm_client.dart';

class GeminiClient implements LlmClient {
  final Dio _dio;
  final String apiKey;
  final String model;

  GeminiClient({required this.apiKey, this.model = 'gemini-1.5-flash', Dio? dio}) : _dio = dio ?? Dio();

  String get _url =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  @override
  Future<LlmResponse> send(List<LlmMessage> messages, List<Map<String, dynamic>> tools) async {
    final systemText = messages.where((m) => m.role == 'system').map((m) => m.content).join('\n');
    final contents = <Map<String, dynamic>>[];

    for (final m in messages) {
      if (m.role == 'system') continue;
      if (m.role == 'tool') {
        contents.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': m.toolName ?? m.toolCallId ?? 'tool',
                'response': {'result': m.content},
              }
            }
          ]
        });
      } else if (m.role == 'assistant' && m.toolCalls.isNotEmpty) {
        contents.add({
          'role': 'model',
          'parts': [
            for (final tc in m.toolCalls)
              {
                'functionCall': {'name': tc.name, 'args': tc.args}
              }
          ]
        });
      } else {
        contents.add({
          'role': m.role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': m.content}
          ]
        });
      }
    }

    final body = {
      'contents': contents,
      if (systemText.isNotEmpty) 'systemInstruction': {'parts': [
        {'text': systemText}
      ]},
      'generationConfig': {'temperature': 0.2},
      'tools': [
        {
          'functionDeclarations': [
            for (final t in tools)
              {
                'name': t['name'],
                'description': t['description'],
                'parameters': t['parameters'],
              }
          ]
        }
      ],
    };

    final resp = await _dio.post(
      _url,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
      data: body,
    );

    final parts = ((resp.data['candidates'] as List?)?.first?['content']?['parts'] as List?) ?? [];
    final text = StringBuffer();
    final calls = <ToolCall>[];
    for (final p in parts) {
      if (p['text'] != null) {
        text.write(p['text']);
      } else if (p['functionCall'] != null) {
        final fc = p['functionCall'];
        calls.add(ToolCall(
          id: 'fc_${calls.length}',
          name: fc['name'] as String,
          args: fc['args'] == null ? {} : Map<String, dynamic>.from(fc['args'] as Map),
        ));
      }
    }
    return LlmResponse(text: text.isEmpty ? null : text.toString(), toolCalls: calls);
  }

  @override
  Future<void> testConnection() async {
    await _dio.post(
      _url,
      options: Options(receiveTimeout: const Duration(seconds: 20)),
      data: {
        'contents': [
          {'role': 'user', 'parts': [
            {'text': 'ping'}
          ]}
        ]
      },
    );
  }
}
