import '../models/user_profile.dart';

enum RegistrationIssue {
  phoneTaken,
  nicknameTaken,
}

class RegistrationResult {
  const RegistrationResult.success(this.profile) : issue = null;
  const RegistrationResult.failure(this.issue) : profile = null;

  final UserProfile? profile;
  final RegistrationIssue? issue;

  bool get isSuccess => profile != null;
}

/// Replace [InMemoryAuthRepository] with an HTTP-backed implementation
/// when the backend is ready.
abstract class AuthRepository {
  Future<RegistrationResult> register({
    required String normalizedPhone,
    required String nickname,
  });
}
