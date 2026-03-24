import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ollama_config.dart';

/// Клиент [Ollama HTTP API](https://github.com/ollama/ollama/blob/main/docs/api.md) (`/api/chat`).
class OllamaClient {
  OllamaClient({
    required String baseUrl,
    String? model,
    this.timeout = const Duration(seconds: 120),
  })  : _base = _normalizeBase(baseUrl),
        _model = model ?? OllamaConfig.model;

  final String _base;
  final String _model;
  final Duration timeout;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  Uri get _chatUri => Uri.parse('$_base/api/chat');

  Future<String> chat(List<Map<String, String>> messages) async {
    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': false,
    });

    final response = await http
        .post(
          _chatUri,
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OllamaException(
        'HTTP ${response.statusCode}: ${response.body.length > 200 ? '${response.body.substring(0, 200)}…' : response.body}',
      );
    }

    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const OllamaException('Некорректный JSON от Ollama');
    }

    final msg = decoded['message'];
    if (msg is! Map<String, dynamic>) {
      throw const OllamaException('В ответе нет поля message');
    }

    final content = msg['content'];
    if (content is! String) {
      throw const OllamaException('В ответе нет текста assistant');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const OllamaException('Пустой ответ модели');
    }
    return trimmed;
  }
}

class OllamaException implements Exception {
  const OllamaException(this.message);
  final String message;

  @override
  String toString() => message;
}
