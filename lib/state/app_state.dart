import 'package:flutter/foundation.dart';

import '../config/ollama_config.dart';
import '../data/app_db.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../services/auth_repository.dart';
import '../services/frida_service.dart';
import '../services/session_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthRepository auth,
    required SessionStore session,
    required AppDb db,
    required FridaService frida,
  })  : _auth = auth,
        _session = session,
        _db = db,
        _frida = frida {
    _profile = _session.loadProfile();
  }

  final AuthRepository _auth;
  final SessionStore _session;
  final AppDb _db;
  final FridaService _frida;

  UserProfile? _profile;
  bool _busy = false;
  String? _authError;
  List<ChatThread> _threads = [];
  List<ChatMessage> _messages = [];
  String? _selectedThreadId;
  String _threadFilter = '';
  bool _aiConsultantEnabled = false;
  bool _fridaBusy = false;

  UserProfile? get profile => _profile;
  bool get isBusy => _busy;
  bool get aiConsultantEnabled => _aiConsultantEnabled;
  bool get fridaBusy => _fridaBusy;
  String? get authError => _authError;
  String get threadFilter => _threadFilter;

  List<ChatThread> get threads {
    final q = _threadFilter.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_threads);
    return _threads
        .where((t) =>
            t.peerNickname.toLowerCase().contains(q) ||
            t.lastSnippet.toLowerCase().contains(q))
        .toList();
  }

  String? get selectedThreadId => _selectedThreadId;

  ChatThread? get selectedThread {
    if (_selectedThreadId == null) return null;
    try {
      return _threads.firstWhere((t) => t.id == _selectedThreadId);
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> get selectedMessages => List.unmodifiable(_messages);

  bool get isSignedIn => _profile != null;

  Future<void> hydrateAfterOpen() async {
    _profile = _session.loadProfile();
    if (_profile == null) {
      notifyListeners();
      return;
    }
    final row = await _db.getUserById(_profile!.userId);
    if (row == null) {
      await signOut();
      return;
    }
    _profile = _db.rowToProfile(row);
    await _session.saveProfile(_profile!);
    await _db.addUserToChat(chatId: AppDb.aiChatId, userId: _profile!.userId);
    await _loadThreads();
    await _loadMessages();
    notifyListeners();
  }

  void setThreadFilter(String value) {
    if (_threadFilter == value) return;
    _threadFilter = value;
    notifyListeners();
  }

  Future<void> _loadThreads() async {
    final uid = _profile?.userId;
    if (uid == null) {
      _threads = [];
      return;
    }
    _threads = await _db.listThreadsForUser(uid);
    if (_threads.isEmpty) {
      _selectedThreadId = null;
    } else if (_selectedThreadId == null ||
        !_threads.any((t) => t.id == _selectedThreadId)) {
      _selectedThreadId = _threads.first.id;
    }
  }

  Future<void> _loadMessages() async {
    final tid = _selectedThreadId;
    final uid = _profile?.userId;
    if (tid == null || uid == null) {
      _messages = [];
      return;
    }
    _messages = await _db.messagesForChat(chatId: tid, viewerUserId: uid);
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
      await _loadThreads();
      await _loadMessages();
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

  Future<void> login({required String phoneRaw}) async {
    _authError = null;
    _busy = true;
    notifyListeners();

    final phone = _normalizePhone(phoneRaw);

    final result = await _auth.login(normalizedPhone: phone);

    if (result.isSuccess && result.profile != null) {
      _profile = result.profile;
      await _session.saveProfile(_profile!);
      await _loadThreads();
      await _loadMessages();
    } else {
      switch (result.issue) {
        case LoginIssue.userNotFound:
          _authError =
              'Пользователь с таким номером не найден. Сначала зарегистрируйтесь.';
        case null:
          _authError = 'Не удалось войти.';
      }
    }

    _busy = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _profile = null;
    _selectedThreadId = null;
    _threads = [];
    _messages = [];
    _authError = null;
    _threadFilter = '';
    await _session.clear();
    notifyListeners();
  }

  Future<void> selectThread(String id) async {
    _selectedThreadId = id;
    await _loadMessages();
    notifyListeners();
  }

  void setAiConsultantEnabled(bool value) {
    if (_aiConsultantEnabled == value) return;
    _aiConsultantEnabled = value;
    notifyListeners();
  }

  Future<String?> createGroup({
    required String titleRaw,
    String? descriptionRaw,
  }) async {
    final uid = _profile?.userId;
    if (uid == null) return 'Не авторизованы';
    final title = titleRaw.trim();
    if (title.isEmpty) return 'Укажите название';
    _busy = true;
    notifyListeners();
    try {
      final id = await _db.createGroup(
        creatorUserId: uid,
        title: title,
        description: descriptionRaw?.trim(),
      );
      await _loadThreads();
      _selectedThreadId = id;
      await _loadMessages();
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> addMemberToSelectedGroupByPhone(String phoneRaw) async {
    final uid = _profile?.userId;
    final tid = _selectedThreadId;
    if (uid == null || tid == null) return 'Нет активного чата';
    final thread = selectedThread;
    if (thread == null || !thread.isGroup) return 'Откройте группу';
    final phone = _normalizePhone(phoneRaw);
    if (phone.length < 10) return 'Введите номер полностью';
    final row = await _db.getUserByPhone(phone);
    if (row == null) return 'Пользователь не найден';
    final memberId = row['id']! as int;
    if (memberId == uid) return 'Это ваш номер';
    try {
      await _db.addMemberToGroup(chatId: tid, memberUserId: memberId);
    } catch (_) {
      return 'Не удалось добавить (возможно, уже в группе)';
    }
    await _loadThreads();
    notifyListeners();
    return null;
  }

  Future<List<UserProfile>> searchUsersByPhoneQuery(String queryRaw) async {
    final uid = _profile?.userId;
    if (uid == null) return [];
    final digits = _normalizePhone(queryRaw);
    if (digits.length < 3) return [];
    final rows = await _db.searchUsersByPhone(
      digitsQuery: digits,
      excludeUserId: uid,
    );
    return rows
        .map(
          (r) => UserProfile(
            userId: r['id']! as int,
            phone: r['phone']! as String,
            nickname: r['nickname']! as String,
          ),
        )
        .toList();
  }

  Future<void> sendMessageToSelectedThread(String text) async {
    final id = _selectedThreadId;
    final uid = _profile?.userId;
    if (id == null || uid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _db.insertUserMessage(
      chatId: id,
      senderUserId: uid,
      text: trimmed,
    );
    await _loadMessages();
    await _loadThreads();
    notifyListeners();

    final aiOnly = ChatIds.isAiConsultant(id);
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
        inDedicatedAiChat: ChatIds.isAiConsultant(threadId),
      );
      await _db.insertAgentMessage(
        chatId: threadId,
        text: reply,
        senderLabel: FridaService.agentName,
      );
    } catch (e) {
      await _db.insertAgentMessage(
        chatId: threadId,
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
      await _loadMessages();
      await _loadThreads();
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
