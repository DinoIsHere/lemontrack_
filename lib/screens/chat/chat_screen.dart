import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state/chat_controller.dart';
import '../../data/settings/settings_repository.dart';
import '../../domain/ai/tool_executor.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';
import '../../widgets/common/lt_logo.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final providerLabel = settings == null
        ? 'Rule-based'
        : settings.llmEnabled
            ? (settings.settings.aiProvider.name + (settings.settings.aiModelName.isNotEmpty ? ' · ${settings.settings.aiModelName}' : ''))
            : 'Rule-based';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LtLogo(size: 20),
            const SizedBox(width: 6),
            Text('AI', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            if (state.busy) const _LiveDot(),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: LTColors.lemonDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: settings?.llmEnabled ?? false ? LTColors.lemon : LTColors.wire),
            ),
            child: Text(providerLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LTColors.lemonSoft)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length,
              itemBuilder: (context, i) {
                final m = state.messages[i];
                if (m.result != null) return _DiffCard(result: m.result!, onUndo: () => ref.read(chatControllerProvider.notifier).undo(m.result!.actionLogId!));
                return _Bubble(message: m);
              },
            ),
          ),
          if (state.messages.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  "What's left today?",
                  'Move my afternoon back 30 min',
                  'Find 45 min',
                  'Summarize my day',
                ].map((q) => GestureDetector(
                      onTap: () => _send(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: LTColors.steel, borderRadius: BorderRadius.circular(12), border: Border.all(color: LTColors.wire)),
                        child: Text(q, style: const TextStyle(fontSize: 11)),
                      ),
                    )).toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(hintText: 'move gym to 18:00'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: state.busy ? null : () => _send(),
                    icon: Icon(Icons.send, color: state.busy ? LTColors.ash : LTColors.lemon),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatUiMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (message.pending) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const _LiveDot(),
            const SizedBox(width: 8),
            const Text('Working…', style: TextStyle(color: LTColors.ash, fontSize: 13)),
          ],
        ),
      );
    }
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? LTColors.lemonDeep : LTColors.graphite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isUser ? LTColors.lemon : LTColors.wire),
        ),
        child: Text(message.text, style: TextStyle(color: isUser ? LTColors.lemonSoft : LTColors.paper, fontSize: 14, height: 1.4)),
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  final ToolResult result;
  final VoidCallback onUndo;
  const _DiffCard({required this.result, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1400),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LTColors.lemonDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(result.tool, style: const TextStyle(color: LTColors.lemon, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          ...result.changes.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '${c.label}: ${c.before} → ${c.after}',
                  style: LTText.ticker.copyWith(fontSize: 11, color: LTColors.ash),
                ),
              )),
          if (result.conflicts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: LTColors.coral),
                  const SizedBox(width: 4),
                  Text('Conflicts: ${result.conflicts.join(", ")}', style: const TextStyle(color: LTColors.coral, fontSize: 11)),
                ],
              ),
            ),
          if (result.actionLogId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onUndo,
                style: TextButton.styleFrom(foregroundColor: LTColors.coral, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                child: const Text('Undo', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: LTColors.lemon, shape: BoxShape.circle)),
    );
  }
}
