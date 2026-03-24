import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _nick = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _nick.dispose();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final app = context.read<AppState>();
    await app.register(
      phoneRaw: _phone.text,
      nicknameRaw: _nick.text,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Регистрация',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Укажите телефон и желаемый ник. Оба должны быть уникальными.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _phone,
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
                    controller: _nick,
                    decoration: const InputDecoration(
                      labelText: 'Ник',
                      hintText: 'Как к вам обращаться',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateNick,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 28),
                  Consumer<AppState>(
                    builder: (context, app, _) {
                      return FilledButton(
                        onPressed: app.isBusy ? null : _submit,
                        child: app.isBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Продолжить'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
