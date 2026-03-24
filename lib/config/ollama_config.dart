/// Модель: `--dart-define=OLLAMA_MODEL=...` (в Docker см. build-arg в compose).
///
/// Базовый URL — [resolveOllamaBaseUrl]: на Web по умолчанию `/ollama` на том же origin
/// (nginx в compose проксирует на сервис `ollama`).
/// Для прямого доступа к Ollama с браузера задайте `OLLAMA_BASE_URL` и при необходимости
/// `OLLAMA_ORIGINS` на стороне Ollama.
abstract final class OllamaConfig {
  static const String model = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'llama3.2',
  );
}
