abstract final class ChatIds {
  static const String aiConsultant = 'ai_consultant';
  static const String typeAi = 'ai_consultant';
  static const String typeGroup = 'group';

  static bool isAiConsultant(String id) => id == aiConsultant;
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.peerNickname,
    required this.lastSnippet,
    required this.updatedAt,
    this.isGroup = false,
  });

  final String id;
  final String peerNickname;
  final String lastSnippet;
  final DateTime updatedAt;
  final bool isGroup;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.senderLabel,
    this.authorNickname,
  });

  final String id;
  final String text;
  final bool isMine;
  final DateTime sentAt;

  /// Например `FRIDA` для ответа AI; обычные сообщения собеседника — `null`.
  final String? senderLabel;

  /// Подпись в группе для чужих сообщений (не FRIDA).
  final String? authorNickname;
}
