import 'package:sqflite/sqflite.dart';

import '../data/app_db.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';

class DbAuthRepository implements AuthRepository {
  DbAuthRepository(this._db);

  final AppDb _db;

  @override
  Future<RegistrationResult> register({
    required String normalizedPhone,
    required String nickname,
  }) async {
    try {
      final id = await _db.insertUser(phone: normalizedPhone, nickname: nickname);
      await _db.addUserToChat(chatId: AppDb.aiChatId, userId: id);
      return RegistrationResult.success(
        UserProfile(userId: id, phone: normalizedPhone, nickname: nickname),
      );
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (!msg.contains('UNIQUE constraint failed')) rethrow;
      final lower = msg.toLowerCase();
      if (lower.contains('users.phone') || lower.contains('.phone')) {
        return const RegistrationResult.failure(RegistrationIssue.phoneTaken);
      }
      return const RegistrationResult.failure(RegistrationIssue.nicknameTaken);
    }
  }

  @override
  Future<LoginResult> login({required String normalizedPhone}) async {
    final row = await _db.getUserByPhone(normalizedPhone);
    if (row == null) {
      return const LoginResult.failure(LoginIssue.userNotFound);
    }
    final profile = _db.rowToProfile(row);
    await _db.addUserToChat(chatId: AppDb.aiChatId, userId: profile.userId);
    return LoginResult.success(profile);
  }
}
