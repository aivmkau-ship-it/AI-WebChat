import 'ollama_client.dart';

/// FRIDA — AI-консультант через Ollama. Упоминания в тексте: `@FRIDA` или `@AI`.
class FridaService {
  FridaService(this._ollama);

  final OllamaClient _ollama;

  static final RegExp _mention = RegExp(r'@(?:FRIDA|AI)\b', caseSensitive: false);

  static const String agentName = 'FRIDA';

  static const String _systemPrompt = '''
Ты — FRIDA, корпоративный AI-консультант в чате поддержки.
Отвечай по-русски, кратко и по делу, дружелюбно.
Подключение к внутренней базе знаний пока в разработке: если вопрос требует данных из неё,
честно скажи, что скоро ответы будут браться из базы, а сейчас ты опираешься на общие сведения
и не выдумывай факты о компании.''';

  /// Возвращает текст вопроса для модели, если в сообщении есть `@FRIDA` или `@AI`.
  static String? consultantQueryFromMessage(String message) {
    final m = _mention.firstMatch(message);
    if (m == null) return null;
    final after = message.substring(m.end).trim();
    if (after.isEmpty) return null;
    return after;
  }

  Future<String> answer(
    String userQuery, {
    bool inDedicatedAiChat = false,
  }) async {
    final system = inDedicatedAiChat
        ? '$_systemPrompt\n'
            'Сейчас открыт отдельный чат «AI консультант»: пользователь пишет только тебе, без @.'
        : _systemPrompt;
    return _ollama.chat([
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': userQuery},
    ]);
  }
}
