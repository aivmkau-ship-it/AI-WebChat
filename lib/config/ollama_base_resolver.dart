import 'package:flutter/foundation.dart' show kIsWeb;

/// Базовый URL Ollama **без** завершающего `/`.
///
/// 1. Если задан `--dart-define=OLLAMA_BASE_URL=...` — используется он.
/// 2. На **Web** без override — тот же origin + путь `/ollama` (в Docker nginx проксирует
///    на сервис `ollama`; браузер не ходит на `127.0.0.1` внутри контейнера).
/// 3. Не-Web (Android, iOS, desktop) — `http://127.0.0.1:11434` (Ollama на хосте / проброшенный порт).
///
/// Локальный `flutter run -d chrome` без nginx: задайте
/// `--dart-define=OLLAMA_BASE_URL=http://127.0.0.1:11434` и `OLLAMA_ORIGINS` на Ollama.
String resolveOllamaBaseUrl() {
  const env = String.fromEnvironment('OLLAMA_BASE_URL');
  if (env.isNotEmpty) {
    return _trimTrailingSlashes(env);
  }
  if (kIsWeb) {
    return _trimTrailingSlashes(Uri.base.resolve('/ollama').toString());
  }
  return 'http://127.0.0.1:11434';
}

String _trimTrailingSlashes(String url) {
  var s = url.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
