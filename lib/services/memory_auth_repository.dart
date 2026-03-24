import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'auth_repository.dart';

const _kPhonesKey = 'ai_webchat_registered_phones_v1';
const _kNicksKey = 'ai_webchat_registered_nicks_v1';

/// Local persistence of taken phone/nick so uniqueness survives restarts (web refresh).
/// Swap for [AuthRepository] backed by your API in production.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._prefs) {
    _phones.addAll(_readSet(_kPhonesKey));
    _nicknamesLower.addAll(_readSet(_kNicksKey));
  }

  final SharedPreferences _prefs;
  final Set<String> _phones = {};
  final Set<String> _nicknamesLower = {};

  Set<String> _readSet(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeSet(String key, Set<String> values) async {
    await _prefs.setString(key, jsonEncode(values.toList()));
  }

  @override
  Future<RegistrationResult> register({
    required String normalizedPhone,
    required String nickname,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_phones.contains(normalizedPhone)) {
      return const RegistrationResult.failure(RegistrationIssue.phoneTaken);
    }
    final key = nickname.toLowerCase();
    if (_nicknamesLower.contains(key)) {
      return const RegistrationResult.failure(RegistrationIssue.nicknameTaken);
    }
    _phones.add(normalizedPhone);
    _nicknamesLower.add(key);
    await _writeSet(_kPhonesKey, _phones);
    await _writeSet(_kNicksKey, _nicknamesLower);
    return RegistrationResult.success(
      UserProfile(phone: normalizedPhone, nickname: nickname),
    );
  }
}
