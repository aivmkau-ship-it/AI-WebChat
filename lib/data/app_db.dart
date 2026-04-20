import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/chat.dart';
import '../models/user_profile.dart';

/// Локальная SQLite: пользователи, группы, участники, сообщения.
class AppDb {
  AppDb._(this._db);

  final Database _db;

  static const _dbName = 'ai_webchat.db';
  static const aiChatId = ChatIds.aiConsultant;

  static Future<AppDb> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), _dbName),
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    final app = AppDb._(db);
    await app._ensureAiConsultant();
    return app;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT NOT NULL UNIQUE,
  nickname TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE chats (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  created_by_user_id INTEGER REFERENCES users(id),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE chat_members (
  chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (chat_id, user_id)
);
''');
    await db.execute('''
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_user_id INTEGER REFERENCES users(id),
  body TEXT NOT NULL,
  sender_label TEXT,
  created_at INTEGER NOT NULL
);
''');
    await db.execute(
      'CREATE INDEX idx_messages_chat ON messages(chat_id, created_at);',
    );
    await db.execute(
      'CREATE INDEX idx_users_phone ON users(phone);',
    );
  }

  Future<void> _ensureAiConsultant() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      'chats',
      {
        'id': aiChatId,
        'type': ChatIds.typeAi,
        'title': 'AI консультант',
        'description': null,
        'created_by_user_id': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final welcome = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM messages WHERE chat_id = ?',
      [aiChatId],
    );
    final c = (welcome.first['c'] as int?) ?? 0;
    if (c == 0) {
      await _db.insert('messages', {
        'chat_id': aiChatId,
        'sender_user_id': null,
        'body':
            'Здравствуйте! Я FRIDA, AI-консультант. В этом чате вы общаетесь только со мной — '
            'просто напишите вопрос, без @FRIDA и без отдельного включения консультанта.',
        'sender_label': 'FRIDA',
        'created_at': now,
      });
    }
  }

  Future<int> insertUser({
    required String phone,
    required String nickname,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.insert('users', {
      'phone': phone,
      'nickname': nickname,
      'created_at': now,
    });
  }

  Future<Map<String, Object?>?> getUserByPhone(String phone) async {
    final rows = await _db.query(
      'users',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> getUserById(int id) async {
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> addUserToChat({
    required String chatId,
    required int userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      'chat_members',
      {
        'chat_id': chatId,
        'user_id': userId,
        'joined_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> searchUsersByPhone({
    required String digitsQuery,
    required int excludeUserId,
    int limit = 20,
  }) async {
    if (digitsQuery.isEmpty) return [];
    final like = '%$digitsQuery%';
    return _db.rawQuery(
      '''
SELECT id, phone, nickname FROM users
WHERE phone LIKE ? AND id != ?
ORDER BY phone
LIMIT ?
''',
      [like, excludeUserId, limit],
    );
  }

  Future<String> createGroup({
    required int creatorUserId,
    required String title,
    String? description,
  }) async {
    final id = 'group_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.insert('chats', {
        'id': id,
        'type': ChatIds.typeGroup,
        'title': title.trim(),
        'description': description?.trim().isEmpty ?? true
            ? null
            : description!.trim(),
        'created_by_user_id': creatorUserId,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('chat_members', {
        'chat_id': id,
        'user_id': creatorUserId,
        'joined_at': now,
      });
    });
    return id;
  }

  Future<void> addMemberToGroup({
    required String chatId,
    required int memberUserId,
  }) async {
    final row = await _db.query(
      'chats',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    if (row.isEmpty || row.first['type'] != ChatIds.typeGroup) {
      throw StateError('Не группа');
    }
    await addUserToChat(chatId: chatId, userId: memberUserId);
    await _touchChat(chatId);
  }

  Future<void> _touchChat(String chatId) async {
    await _db.update(
      'chats',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<List<ChatThread>> listThreadsForUser(int userId) async {
    final rows = await _db.rawQuery(
      '''
SELECT c.id, c.type, c.title, c.updated_at,
  (SELECT m.body FROM messages m WHERE m.chat_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_body,
  (SELECT MAX(m.created_at) FROM messages m WHERE m.chat_id = c.id) AS last_msg_at
FROM chats c
INNER JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = ?
ORDER BY COALESCE(
  (SELECT MAX(m2.created_at) FROM messages m2 WHERE m2.chat_id = c.id),
  c.updated_at
) DESC
''',
      [userId],
    );
    return rows.map((r) {
      final id = r['id']! as String;
      final title = r['title']! as String;
      final lastBody = r['last_body'] as String?;
      final lastMsgAt = r['last_msg_at'] as int?;
      final updated = r['updated_at']! as int;
      final ts = lastMsgAt ?? updated;
      final type = r['type']! as String;
      return ChatThread(
        id: id,
        peerNickname: title,
        lastSnippet: lastBody ?? (type == ChatIds.typeAi ? 'Диалог с FRIDA' : 'Нет сообщений'),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ts),
        isGroup: type == ChatIds.typeGroup,
      );
    }).toList();
  }

  Future<List<ChatMessage>> messagesForChat({
    required String chatId,
    required int viewerUserId,
  }) async {
    final rows = await _db.rawQuery(
      '''
SELECT m.id, m.body, m.sender_user_id, m.sender_label, m.created_at,
  u.nickname AS author_nick
FROM messages m
LEFT JOIN users u ON u.id = m.sender_user_id
WHERE m.chat_id = ?
ORDER BY m.created_at ASC
''',
      [chatId],
    );
    return rows.map((r) {
      final sid = r['sender_user_id'] as int?;
      final isMine = sid != null && sid == viewerUserId;
      final authorNick = r['author_nick'] as String?;
      return ChatMessage(
        id: '${r['id']}',
        text: r['body']! as String,
        isMine: isMine,
        sentAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        senderLabel: r['sender_label'] as String?,
        authorNickname:
            !isMine && authorNick != null && (r['sender_label'] == null) ? authorNick : null,
      );
    }).toList();
  }

  Future<void> insertUserMessage({
    required String chatId,
    required int senderUserId,
    required String text,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('messages', {
      'chat_id': chatId,
      'sender_user_id': senderUserId,
      'body': text,
      'sender_label': null,
      'created_at': now,
    });
    await _touchChat(chatId);
  }

  Future<void> insertAgentMessage({
    required String chatId,
    required String text,
    required String senderLabel,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('messages', {
      'chat_id': chatId,
      'sender_user_id': null,
      'body': text,
      'sender_label': senderLabel,
      'created_at': now,
    });
    await _touchChat(chatId);
  }

  UserProfile rowToProfile(Map<String, Object?> row) {
    return UserProfile(
      userId: row['id']! as int,
      phone: row['phone']! as String,
      nickname: row['nickname']! as String,
    );
  }

  Future<void> close() => _db.close();
}
