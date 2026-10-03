import 'dart:convert';

import 'package:http/http.dart' as http;

class CoachException implements Exception {
  CoachException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One chat turn sent to the model.
class AiMsg {
  const AiMsg(this.user, this.text);
  final bool user;
  final String text;
  Map<String, dynamic> toJson() => {'role': user ? 'user' : 'assistant', 'content': text};
}

/// Anthropic API keys start with this prefix.
bool looksLikeClaudeKey(String k) => k.trim().startsWith('sk-ant-');

/// Talks to the configured AI provider. Methods return null when no provider
/// is usable so callers can fall back to built-in offline behaviour.
class CoachService {
  CoachService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const claudeModel = 'claude-opus-5-5';
  static const ollamaModel = 'llama3.2';

  /// Single-prompt text completion.
  Future<String?> complete({
    required String provider,
    required String apiKey,
    required String system,
    required String prompt,
    int maxTokens = 2048,
  }) =>
      chat(provider: provider, apiKey: apiKey, system: system, messages: [AiMsg(true, prompt)], maxTokens: maxTokens);

  /// Multi-turn chat. [messages] must end with a user turn.
  Future<String?> chat({
    required String provider,
    required String apiKey,
    required String system,
    required List<AiMsg> messages,
    int maxTokens = 2048,
  }) async {
    final turns = _normalize(messages);
    switch (provider) {
      case 'Claude':
        if (apiKey.trim().isEmpty) return null;
        return _claude(apiKey.trim(), system, turns, maxTokens);
      case 'Ollama':
        return _ollama(system, turns);
      default:
        return null;
    }
  }

  /// Structured output: the reply is guaranteed to match [schema] (Claude) or
  /// is requested in that shape (Ollama). Returns the decoded JSON object.
  Future<Map<String, dynamic>?> json({
    required String provider,
    required String apiKey,
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    final turns = [AiMsg(true, prompt)];
    String? text;
    switch (provider) {
      case 'Claude':
        if (apiKey.trim().isEmpty) return null;
        text = await _claude(apiKey.trim(), system, turns, maxTokens, schema: schema);
      case 'Ollama':
        text = await _ollama(system, turns, schema: schema);
      default:
        return null;
    }
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      throw CoachException('The AI returned malformed JSON.');
    }
  }

  /// The API requires the conversation to start with a user turn and to
  /// alternate roles; merge or drop turns that would break that.
  List<AiMsg> _normalize(List<AiMsg> msgs) {
    final out = <AiMsg>[];
    for (final m in msgs) {
      if (m.text.trim().isEmpty) continue;
      if (out.isEmpty && !m.user) continue;
      if (out.isNotEmpty && out.last.user == m.user) {
        out[out.length - 1] = AiMsg(m.user, '${out.last.text}\n\n${m.text}');
      } else {
        out.add(m);
      }
    }
    return out;
  }

  Future<String> _claude(String key, String system, List<AiMsg> turns, int maxTokens, {Map<String, dynamic>? schema}) async {
    if (!looksLikeClaudeKey(key)) {
      throw CoachException('That doesn\'t look like an Anthropic API key (they start with "sk-ant-"). Update it in Settings → AI provider.');
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode({
              'model': claudeModel,
              'max_tokens': maxTokens,
              'output_config': {
                'effort': 'low',
                if (schema != null) 'format': {'type': 'json_schema', 'schema': schema},
              },
              'fallbacks': 'default',
              'system': system,
              'messages': turns.map((m) => m.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 120));
    } on Exception catch (e) {
      throw CoachException('Couldn\'t reach Claude ($e). Check your connection.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw CoachException('Claude API ${res.statusCode}: unexpected response.');
    }
    if (res.statusCode != 200) {
      final msg = (body['error'] as Map<String, dynamic>?)?['message'] ?? 'request failed';
      throw CoachException(switch (res.statusCode) {
        401 => 'Claude rejected the API key (401). Paste a valid key in Settings → AI provider.',
        403 => 'This API key isn\'t allowed to use $claudeModel (403).',
        429 => 'Rate limited by Claude (429). Try again in a minute.',
        529 || 503 => 'Claude is overloaded right now (${res.statusCode}). Try again shortly.',
        _ => 'Claude API ${res.statusCode}: $msg',
      });
    }
    if (body['stop_reason'] == 'refusal') {
      throw CoachException('The model declined this request.');
    }
    final text = (body['content'] as List)
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join()
        .trim();
    if (text.isEmpty) throw CoachException('Empty reply from Claude.');
    return text;
  }

  Future<String> _ollama(String system, List<AiMsg> turns, {Map<String, dynamic>? schema}) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('http://localhost:11434/api/chat'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'model': ollamaModel,
              'stream': false,
              'format': ?schema,
              'messages': [
                {'role': 'system', 'content': system},
                ...turns.map((m) => m.toJson()),
              ],
            }),
          )
          .timeout(const Duration(seconds: 180));
    } on Exception {
      throw CoachException('Couldn\'t reach Ollama on localhost:11434. Is it running?');
    }
    if (res.statusCode != 200) throw CoachException('Ollama ${res.statusCode}: ${res.body}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return ((body['message'] as Map?)?['content'] as String? ?? '').trim();
  }
}
