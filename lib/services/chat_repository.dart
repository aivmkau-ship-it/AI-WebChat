import '../models/chat.dart';

/// Mock threads until a real API exists.
class ChatRepository {
  /// Системный чат: только диалог с FRIDA, без @ и без переключателя.
  static const String aiConsultantThreadId = 'ai_consultant';

  final Map<String, List<ChatMessage>> _outgoingByThread = {};

  static bool isAiConsultantThread(String id) => id == aiConsultantThreadId;

  List<ChatThread> listThreads() {
    final now = DateTime.now();
    return [
      ChatThread(
        id: aiConsultantThreadId,
        peerNickname: 'AI консультант',
        lastSnippet: 'Диалог только с FRIDA',
        updatedAt: now,
      ),
      ChatThread(
        id: '1',
        peerNickname: 'Support',
        lastSnippet: 'Здравствуйте! Чем помочь?',
        updatedAt: now.subtract(const Duration(minutes: 12)),
      ),
      ChatThread(
        id: '2',
        peerNickname: 'Марина',
        lastSnippet: 'Договорились на завтра.',
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      ChatThread(
        id: '3',
        peerNickname: 'Команда',
        lastSnippet: 'Релиз перенесли на пятницу.',
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  List<ChatMessage> _seedMessages(String threadId) {
    final base = DateTime.now();
    if (threadId == aiConsultantThreadId) {
      return [
        ChatMessage(
          id: '${threadId}_welcome',
          text:
              'Здравствуйте! Я FRIDA, AI-консультант. В этом чате вы общаетесь только со мной — '
              'просто напишите вопрос, без @FRIDA и без отдельного включения консультанта.',
          isMine: false,
          sentAt: base.subtract(const Duration(seconds: 30)),
          senderLabel: 'FRIDA',
        ),
      ];
    }
    return [
      ChatMessage(
        id: '${threadId}_m1',
        text: 'Привет! Это демо-чат. Сообщения пока локальные.',
        isMine: false,
        sentAt: base.subtract(const Duration(minutes: 6)),
      ),
      ChatMessage(
        id: '${threadId}_m2',
        text: 'Понял, спасибо.',
        isMine: true,
        sentAt: base.subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  List<ChatMessage> messagesFor(String threadId) {
    final merged = <ChatMessage>[
      ..._seedMessages(threadId),
      ...(_outgoingByThread[threadId] ?? const <ChatMessage>[]),
    ];
    merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return merged;
  }

  void appendUserMessage({required String threadId, required String text}) {
    final t = text.trim();
    if (t.isEmpty) return;
    final msg = ChatMessage(
      id: '${threadId}_u_${DateTime.now().microsecondsSinceEpoch}',
      text: t,
      isMine: true,
      sentAt: DateTime.now(),
    );
    _outgoingByThread.putIfAbsent(threadId, () => []).add(msg);
  }

  void appendAgentMessage({
    required String threadId,
    required String text,
    required String senderLabel,
  }) {
    final msg = ChatMessage(
      id: '${threadId}_a_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isMine: false,
      sentAt: DateTime.now(),
      senderLabel: senderLabel,
    );
    _outgoingByThread.putIfAbsent(threadId, () => []).add(msg);
  }
}
