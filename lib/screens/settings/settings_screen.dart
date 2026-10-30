import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/block_repository.dart';
import '../../data/settings/settings_repository.dart';
import '../../domain/ai/llm_client.dart';
import '../../domain/ai/providers/openai_client.dart';
import '../../domain/ai/providers/gemini_client.dart';
import '../../domain/models/time_block.dart';
import '../../theme/lt_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(backgroundColor: LTColors.ink, title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: LTColors.lemon)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('AI PROVIDER · BYOK'),
            const SizedBox(height: 8),
            SegmentedButton<AiProvider>(
              segments: const [
                ButtonSegment(value: AiProvider.ruleBased, label: Text('Rule-based'), icon: Icon(Icons.bolt)),
                ButtonSegment(value: AiProvider.openai, label: Text('OpenAI'), icon: Icon(Icons.smart_toy)),
                ButtonSegment(value: AiProvider.gemini, label: Text('Gemini'), icon: Icon(Icons.auto_awesome)),
              ],
              selected: {state.settings.aiProvider},
              onSelectionChanged: (s) => ref.read(settingsControllerProvider.notifier).setProvider(s.first),
              style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? LTColors.lemonDeep : LTColors.steel)),
            ),
            const SizedBox(height: 16),
            if (state.settings.aiProvider != AiProvider.ruleBased) ...[
              _ApiKeyField(
                provider: state.settings.aiProvider,
                hasKey: state.settings.aiProvider == AiProvider.openai ? state.hasOpenAiKey : state.hasGeminiKey,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Model name', hintText: 'gpt-4o-mini / gemini-1.5-flash'),
                onSubmitted: (v) => ref.read(settingsControllerProvider.notifier).setModel(v.trim()),
              ),
              const SizedBox(height: 8),
              _TestConnectionButton(provider: state.settings.aiProvider, state: state),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Rule-based mode needs no key and works fully offline. Set an API key to unlock natural-language tool calling.',
                  style: TextStyle(color: LTColors.ash, fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            const _SectionLabel('SCHEDULE'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Workday'),
              subtitle: const Text('09:00 – 18:00'),
              trailing: const Icon(Icons.lock_outline, size: 16, color: LTColors.ash),
            ),
            ListTile(
              title: const Text('Snap interval'),
              subtitle: Text('${state.settings.snapMinutes} min'),
            ),
            ListTile(
              title: const Text('Default block length'),
              subtitle: Text('${state.settings.defaultBlockMinutes} min'),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('DATA'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Reseed demo data'),
              subtitle: const Text('Replaces everything with the sample day'),
              leading: const Icon(Icons.restart_alt, color: LTColors.ember),
              onTap: () async {
                final repo = ref.read(blockRepositoryProvider);
                await repo.clearAll();
                repo.seedDemoData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data seeded')));
                }
              },
            ),
            ListTile(
              title: const Text('Clear all blocks'),
              leading: const Icon(Icons.delete_forever, color: LTColors.coral),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: LTColors.slate,
                    title: const Text('Clear all blocks?'),
                    content: const Text('This deletes every block on this device. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: LTColors.coral, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(blockRepositoryProvider).clearAll();
                }
              },
            ),
            const SizedBox(height: 24),
            const _SectionLabel('ABOUT'),
            const SizedBox(height: 8),
            const ListTile(title: Text('LemonTrack'), subtitle: Text('0.1.0 · Plan in blocks. Talk to your time.')),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.labelSmall);
}

class _ApiKeyField extends ConsumerStatefulWidget {
  final AiProvider provider;
  final bool hasKey;
  const _ApiKeyField({required this.provider, required this.hasKey});

  @override
  ConsumerState<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends ConsumerState<_ApiKeyField> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: '${widget.provider.name} API key',
            helperText: widget.hasKey ? 'Key saved in secure storage' : 'Stored on device only — you bring your own key',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (v) {
            ref.read(settingsControllerProvider.notifier).setApiKey(widget.provider, v);
            _ctrl.clear();
          },
        ),
        if (widget.hasKey)
          TextButton(
            onPressed: () => ref.read(settingsControllerProvider.notifier).setApiKey(widget.provider, ''),
            child: const Text('Remove saved key', style: TextStyle(color: LTColors.coral, fontSize: 12)),
          ),
      ],
    );
  }
}

class _TestConnectionButton extends ConsumerWidget {
  final AiProvider provider;
  final SettingsState state;
  const _TestConnectionButton({required this.provider, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.wifi_tethering, size: 16),
      label: const Text('Test connection'),
      onPressed: () async {
        final scaffold = ScaffoldMessenger.of(context);
        scaffold.showSnackBar(const SnackBar(content: Text('Testing…')));
        try {
          final repo = ref.read(settingsRepositoryProvider);
          final key = await repo.getApiKey(provider.name);
          if (key == null || key.isEmpty) throw 'No API key saved';
          final model = state.settings.aiModelName;
          LlmClient client = provider == AiProvider.openai
              ? OpenAiClient(apiKey: key, model: model.isEmpty ? 'gpt-4o-mini' : model)
              : GeminiClient(apiKey: key, model: model.isEmpty ? 'gemini-1.5-flash' : model);
          await client.testConnection();
          scaffold.showSnackBar(const SnackBar(content: Text('Connection OK'), backgroundColor: LTColors.up));
        } on DioException catch (e) {
          scaffold.showSnackBar(SnackBar(content: Text('Failed: HTTP ${e.response?.statusCode ?? e.message}'), backgroundColor: LTColors.coral));
        } catch (e) {
          scaffold.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: LTColors.coral));
        }
      },
    );
  }
}
