class ChatThread {
  const ChatThread({
    required this.id,
    required this.peerNickname,
    required this.lastSnippet,
    required this.updatedAt,
  });

  final String id;
  final String peerNickname;
  final String lastSnippet;
  final DateTime updatedAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.senderLabel,
  });

  final String id;
  final String text;
  final bool isMine;
  final DateTime sentAt;

  /// Например `FRIDA` для ответа AI; обычные сообщения собеседника — `null`.
  final String? senderLabel;
}
