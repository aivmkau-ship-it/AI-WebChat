import '../models/user_profile.dart';

enum RegistrationIssue {
  phoneTaken,
  nicknameTaken,
}

enum LoginIssue {
  userNotFound,
}

class RegistrationResult {
  const RegistrationResult.success(this.profile) : issue = null;
  const RegistrationResult.failure(this.issue) : profile = null;

  final UserProfile? profile;
  final RegistrationIssue? issue;

  bool get isSuccess => profile != null;
}

class LoginResult {
  const LoginResult.success(this.profile) : issue = null;
  const LoginResult.failure(this.issue) : profile = null;

  final UserProfile? profile;
  final LoginIssue? issue;

  bool get isSuccess => profile != null;
}

abstract class AuthRepository {
  Future<RegistrationResult> register({
    required String normalizedPhone,
    required String nickname,
  });

  Future<LoginResult> login({required String normalizedPhone});
}
