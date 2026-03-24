import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../services/chat_repository.dart';
import '../state/app_state.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({super.key});

  static const double _splitBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _splitBreakpoint;
        if (wide) {
          return Row(
            children: [
              SizedBox(
                width: (constraints.maxWidth * 0.32).clamp(260.0, 360.0),
                child: const _HistoryPanel(),
              ),
              const VerticalDivider(width: 1),
              const Expanded(child: _ChatPane()),
            ],
          );
        }
        return _NarrowInbox();
      },
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({this.onThreadPicked});

  final void Function(String id)? onThreadPicked;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'Чаты',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (profile != null)
                  Text(
                    profile.nickname,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                IconButton(
                  tooltip: 'Выйти',
                  onPressed: () => app.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SearchBar(
            hintText: 'Поиск по чатам',
            leading: const Icon(Icons.search),
            onChanged: (_) {},
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: app.threads.length,
            itemBuilder: (context, index) {
              final thread = app.threads[index];
              final selected = thread.id == app.selectedThreadId;
              return _ThreadTile(
                thread: thread,
                isAiConsultant: thread.id == ChatRepository.aiConsultantThreadId,
                selected: selected,
                onTap: () {
                  app.selectThread(thread.id);
                  onThreadPicked?.call(thread.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.isAiConsultant,
    required this.selected,
    required this.onTap,
  });

  final ChatThread thread;
  final bool isAiConsultant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.surfaceContainerHighest.withOpacity(0.6),
      leading: isAiConsultant
          ? CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                color: scheme.onTertiaryContainer,
                size: 22,
              ),
            )
          : CircleAvatar(
              child: Text(thread.peerNickname.characters.first.toUpperCase()),
            ),
      title: Text(thread.peerNickname, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        thread.lastSnippet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _shortDate(thread.updatedAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: onTap,
    );
  }

  static String _shortDate(DateTime d) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }
}

class _ChatPane extends StatefulWidget {
  const _ChatPane();

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final app = context.read<AppState>();
    if (app.fridaBusy) return;
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    _composer.clear();
    await app.sendMessageToSelectedThread(text);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final thread = app.selectedThread;

    if (thread == null) {
      return const Center(child: Text('Выберите чат слева'));
    }

    final messages = app.selectedMessages;
    final scheme = Theme.of(context).colorScheme;
    final aiOnly = thread.id == ChatRepository.aiConsultantThreadId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 0,
          color: scheme.surface,
          child: ListTile(
            title: Text(thread.peerNickname),
            subtitle: Text(
              aiOnly
                  ? 'Только диалог с FRIDA (Ollama). Каждое сообщение уходит консультанту.'
                  : 'Последнее обновление: ${_ThreadTile._shortDate(thread.updatedAt)}',
            ),
          ),
        ),
        if (aiOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Системный чат: обычные беседы с людьми — в других диалогах слева; там FRIDA по @FRIDA / @AI, если включён переключатель.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Подключить AI консультанта'),
              subtitle: Text(
                app.aiConsultantEnabled
                    ? 'Напишите @FRIDA или @AI и текст вопроса после упоминания.'
                    : 'FRIDA (Ollama) не вызывается для этого чата.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: app.aiConsultantEnabled,
              onChanged: (v) => app.setAiConsultantEnabled(v),
            ),
          ),
        if (app.fridaBusy) const LinearProgressIndicator(minHeight: 2),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              return _MessageBubble(message: m);
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  readOnly: app.fridaBusy,
                  decoration: InputDecoration(
                    hintText: aiOnly
                        ? 'Вопрос консультанту…'
                        : app.aiConsultantEnabled
                            ? 'Сообщение… (@FRIDA или @AI для вопроса)'
                            : 'Написать сообщение…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(context),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: app.fridaBusy ? null : () => _submit(context),
                tooltip: 'Отправить',
                icon: app.fridaBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isFrida = !message.isMine && message.senderLabel != null;
    final align = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isMine
        ? scheme.primaryContainer
        : isFrida
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest;
    final fg = message.isMine
        ? scheme.onPrimaryContainer
        : isFrida
            ? scheme.onTertiaryContainer
            : scheme.onSurfaceVariant;

    return Align(
      alignment: align,
      child: Column(
        crossAxisAlignment:
            message.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFrida)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    message.senderLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message.text, style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}

class _NarrowInbox extends StatefulWidget {
  @override
  State<_NarrowInbox> createState() => _NarrowInboxState();
}

class _NarrowInboxState extends State<_NarrowInbox> {
  bool _showThread = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (_showThread && app.selectedThread != null) {
      return Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showThread = false),
              ),
              Expanded(
                child: Text(
                  app.selectedThread!.peerNickname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const Expanded(child: _ChatPane()),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: _HistoryPanel(
            onThreadPicked: (_) => setState(() => _showThread = true),
          ),
        ),
      ],
    );
  }
}
