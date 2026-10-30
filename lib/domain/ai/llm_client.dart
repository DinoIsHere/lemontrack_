class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  const ToolCall({required this.id, required this.name, required this.args});
}

class LlmResponse {
  final String? text;
  final List<ToolCall> toolCalls;
  const LlmResponse({this.text, this.toolCalls = const []});
  bool get hasToolCalls => toolCalls.isNotEmpty;
}

/// Message roles: system | user | assistant | tool
class LlmMessage {
  final String role;
  final String content;
  final List<ToolCall> toolCalls;
  final String? toolCallId; // for role == 'tool' responses (OpenAI)
  final String? toolName; // for role == 'tool' responses (Gemini functionResponse name)
  const LlmMessage(this.role, this.content, {this.toolCalls = const [], this.toolCallId, this.toolName});
}

abstract interface class LlmClient {
  Future<LlmResponse> send(List<LlmMessage> messages, List<Map<String, dynamic>> tools);

  /// Minimal request to validate a key. Throws on failure.
  Future<void> testConnection();
}
