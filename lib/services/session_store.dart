import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

const _kSessionKey = 'ai_webchat_session_v1';

class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;

  /// Same instance used for session JSON; safe to share with other stores.
  SharedPreferences get preferences => _prefs;

  static Future<SessionStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionStore(prefs);
  }

  UserProfile? loadProfile() {
    final raw = _prefs.getString(_kSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_kSessionKey, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_kSessionKey);
  }
}
