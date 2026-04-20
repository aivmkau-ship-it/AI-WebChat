import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _loginPhone = TextEditingController();
  final _regPhone = TextEditingController();
  final _regNick = TextEditingController();

  final _loginForm = GlobalKey<FormState>();
  final _regForm = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginPhone.dispose();
    _regPhone.dispose();
    _regNick.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Введите номер полностью (минимум 10 цифр).';
    }
    return null;
  }

  String? _validateNick(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 2) {
      return 'Ник не короче 2 символов.';
    }
    if (v.length > 32) {
      return 'Ник не длиннее 32 символов.';
    }
    return null;
  }

  Future<void> _submitLogin() async {
    if (!(_loginForm.currentState?.validate() ?? false)) return;
    final app = context.read<AppState>();
    await app.login(phoneRaw: _loginPhone.text);
    if (!mounted) return;
    final err = app.authError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _submitRegister() async {
    if (!(_regForm.currentState?.validate() ?? false)) return;
    final app = context.read<AppState>();
    await app.register(
      phoneRaw: _regPhone.text,
      nicknameRaw: _regNick.text,
    );
    if (!mounted) return;
    final err = app.authError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Вход'),
                  Tab(text: 'Регистрация'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _loginForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Вход по телефону',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Номер должен совпадать с тем, что указан при регистрации.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _loginPhone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Телефон',
                                hintText: '+7 900 000-00-00',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitLogin(),
                            ),
                            const SizedBox(height: 28),
                            Consumer<AppState>(
                              builder: (context, app, _) {
                                return FilledButton(
                                  onPressed: app.isBusy ? null : _submitLogin,
                                  child: app.isBusy
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Войти'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _regForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Регистрация',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Телефон и ник должны быть уникальными.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _regPhone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Телефон',
                                hintText: '+7 900 000-00-00',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _regNick,
                              decoration: const InputDecoration(
                                labelText: 'Ник',
                                hintText: 'Как к вам обращаться',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateNick,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitRegister(),
                            ),
                            const SizedBox(height: 28),
                            Consumer<AppState>(
                              builder: (context, app, _) {
                                return FilledButton(
                                  onPressed: app.isBusy ? null : _submitRegister,
                                  child: app.isBusy
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Зарегистрироваться'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
