import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/chat_home_screen.dart';
import 'screens/registration_screen.dart';
import 'services/chat_repository.dart';
import 'services/frida_service.dart';
import 'services/memory_auth_repository.dart';
import 'config/ollama_base_resolver.dart';
import 'services/ollama_client.dart';
import 'services/session_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionStore.open();
  final auth = InMemoryAuthRepository(session.preferences);
  final chats = ChatRepository();
  final ollama = OllamaClient(baseUrl: resolveOllamaBaseUrl());
  final frida = FridaService(ollama);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        auth: auth,
        session: session,
        chats: chats,
        frida: frida,
      ),
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
        return const Scaffold(body: SafeArea(child: RegistrationScreen()));
      },
    );
  }
}
