import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_db.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_home_screen.dart';
import 'services/db_auth_repository.dart';
import 'services/frida_service.dart';
import 'config/ollama_base_resolver.dart';
import 'services/ollama_client.dart';
import 'services/session_store.dart';
import 'sqlite_config.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    configureSqlitePlatform();
    final session = await SessionStore.open();
    final db = await AppDb.open();
    final auth = DbAuthRepository(db);
    final ollama = OllamaClient(baseUrl: resolveOllamaBaseUrl());
    final frida = FridaService(ollama);

    final appState = AppState(
      auth: auth,
      session: session,
      db: db,
      frida: frida,
    );
    await appState.hydrateAfterOpen();

    runApp(
      ChangeNotifierProvider.value(
        value: appState,
        child: const AiWebChatApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(_StartupErrorApp(message: '$e'));
  }
}

/// Понятный экран вместо белого при сбое инициализации (часто веб: нет sqflite_sw.js / sqlite3.wasm).
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI WebChat',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Не удалось запустить приложение.\n\n'
              'Детали: $message\n\n'
              'Если в консоли браузера ошибка про sqflite_sw.js — для веб-сборки нужны файлы '
              'worker и WASM в каталоге web/. Выполните в корне проекта:\n'
              '  dart run sqflite_common_ffi_web:setup\n'
              'затем снова соберите web. В Docker это уже делает образ (см. Dockerfile).',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

class AiWebChatApp extends StatelessWidget {
  const AiWebChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI WebChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _RootSwitcher(),
    );
  }
}

class _RootSwitcher extends StatelessWidget {
  const _RootSwitcher();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        if (app.isSignedIn) {
          return const Scaffold(body: SafeArea(child: ChatHomeScreen()));
        }
        return const Scaffold(body: SafeArea(child: AuthScreen()));
      },
    );
  }
}
