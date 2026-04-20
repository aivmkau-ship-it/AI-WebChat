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
