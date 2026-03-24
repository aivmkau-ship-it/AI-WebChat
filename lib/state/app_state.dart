import 'package:flutter/foundation.dart';

import '../config/ollama_config.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../services/auth_repository.dart';
import '../services/chat_repository.dart';
import '../services/frida_service.dart';
import '../services/session_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthRepository auth,
    required SessionStore session,
    required ChatRepository chats,
    required FridaService frida,
  })  : _auth = auth,
        _session = session,
        _chats = chats,
        _frida = frida {
    _profile = _session.loadProfile();
    if (_profile != null) {
      _reloadThreads();
    }
  }

  final AuthRepository _auth;
  final SessionStore _session;
  final ChatRepository _chats;
  final FridaService _frida;

  UserProfile? _profile;
  bool _busy = false;
  String? _authError;
  List<ChatThread> _threads = [];
  String? _selectedThreadId;
  bool _aiConsultantEnabled = false;
  bool _fridaBusy = false;

  UserProfile? get profile => _profile;
  bool get isBusy => _busy;
  bool get aiConsultantEnabled => _aiConsultantEnabled;
  bool get fridaBusy => _fridaBusy;
  String? get authError => _authError;
  List<ChatThread> get threads => List.unmodifiable(_threads);
  String? get selectedThreadId => _selectedThreadId;

  ChatThread? get selectedThread {
    if (_selectedThreadId == null) return null;
    try {
      return _threads.firstWhere((t) => t.id == _selectedThreadId);
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> get selectedMessages {
    final id = _selectedThreadId;
    if (id == null) return const [];
    return _chats.messagesFor(id);
  }

  bool get isSignedIn => _profile != null;

  void _reloadThreads() {
    _threads = _chats.listThreads();
    if (_threads.isEmpty) {
      _selectedThreadId = null;
    } else if (_selectedThreadId == null ||
        !_threads.any((t) => t.id == _selectedThreadId)) {
      _selectedThreadId = _threads.first.id;
    }
  }

  Future<void> register({
    required String phoneRaw,
    required String nicknameRaw,
  }) async {
    _authError = null;
    _busy = true;
    notifyListeners();

    final phone = _normalizePhone(phoneRaw);
    final nickname = nicknameRaw.trim();

    final result = await _auth.register(
      normalizedPhone: phone,
      nickname: nickname,
    );

    if (result.isSuccess && result.profile != null) {
      _profile = result.profile;
      await _session.saveProfile(_profile!);
      _reloadThreads();
    } else {
      switch (result.issue) {
        case RegistrationIssue.phoneTaken:
          _authError = 'Этот номер уже зарегистрирован.';
        case RegistrationIssue.nicknameTaken:
          _authError = 'Этот ник уже занят.';
        case null:
          _authError = 'Не удалось зарегистрироваться.';
      }
    }

    _busy = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _profile = null;
    _selectedThreadId = null;
    _threads = [];
    _authError = null;
    await _session.clear();
    notifyListeners();
  }

  void selectThread(String id) {
    _selectedThreadId = id;
    notifyListeners();
  }

  void setAiConsultantEnabled(bool value) {
    if (_aiConsultantEnabled == value) return;
    _aiConsultantEnabled = value;
    notifyListeners();
  }

  Future<void> sendMessageToSelectedThread(String text) async {
    final id = _selectedThreadId;
    if (id == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _chats.appendUserMessage(threadId: id, text: trimmed);
    notifyListeners();

    final aiOnly = ChatRepository.isAiConsultantThread(id);
    if (aiOnly) {
      await _runFridaReply(id, trimmed);
      return;
    }

    if (!_aiConsultantEnabled) return;

    final query = FridaService.consultantQueryFromMessage(trimmed);
    if (query == null) return;

    await _runFridaReply(id, query);
  }

  Future<void> _runFridaReply(String threadId, String queryForModel) async {
    _fridaBusy = true;
    notifyListeners();

    try {
      final reply = await _frida.answer(
        queryForModel,
        inDedicatedAiChat: ChatRepository.isAiConsultantThread(threadId),
      );
      _chats.appendAgentMessage(
        threadId: threadId,
        text: reply,
        senderLabel: FridaService.agentName,
      );
    } catch (e) {
      _chats.appendAgentMessage(
        threadId: threadId,
        text:
            'Не удалось получить ответ от FRIDA: ${_formatFridaError(e)}. '
            'Проверьте, что Ollama запущена и модель `${_ollamaModelHint()}` доступна. '
            'В Docker запросы идут на тот же сайт, путь /ollama. '
            'Если в ошибке указан 127.0.0.1:11434 — это старый JS в кэше браузера: '
            'жёсткое обновление (Ctrl+Shift+R) или «Очистить данные сайта» для localhost.',
        senderLabel: FridaService.agentName,
      );
    } finally {
      _fridaBusy = false;
      notifyListeners();
    }
  }

  String _ollamaModelHint() => OllamaConfig.model;

  static String _formatFridaError(Object e) {
    final s = e.toString();
    if (s.length > 160) return '${s.substring(0, 160)}…';
    return s;
  }

  /// Digits only, suitable for uniqueness checks across locales.
  static String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }
}
