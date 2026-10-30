import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/time_block.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

class SettingsRepository {
  static const _kProvider = 'lt.ai.provider';
  static const _kModel = 'lt.ai.model';
  static const _kOnboarded = 'lt.onboarding.done';
  static const _kSnap = 'lt.settings.snapMinutes';
  static const _kDefaultDur = 'lt.settings.defaultBlockMinutes';

  final FlutterSecureStorage _secure;

  SettingsRepository(this._secure);

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = (prefs.getString(_kProvider) ?? 'ruleBased')
        .toLowerCase();
    return Settings(
      aiProvider: provider == 'openai'
          ? AiProvider.openai
          : provider == 'gemini'
              ? AiProvider.gemini
              : AiProvider.ruleBased,
      aiModelName: prefs.getString(_kModel) ?? '',
      snapMinutes: prefs.getInt(_kSnap) ?? 5,
      defaultBlockMinutes: prefs.getInt(_kDefaultDur) ?? 30,
      hasSeenOnboarding: prefs.getBool(_kOnboarded) ?? false,
    );
  }

  Future<void> saveProvider(AiProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, p.name);
  }

  Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, model);
  }

  Future<void> setOnboarded(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, v);
  }

  Future<void> saveApiKey(String provider, String key) =>
      _secure.write(key: 'lt.ai.apiKey.$provider', value: key);

  Future<String?> getApiKey(String provider) =>
      _secure.read(key: 'lt.ai.apiKey.$provider');

  Future<void> deleteApiKey(String provider) =>
      _secure.delete(key: 'lt.ai.apiKey.$provider');
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.watch(secureStorageProvider)));

class SettingsState {
  final Settings settings;
  final bool hasOpenAiKey;
  final bool hasGeminiKey;
  final bool loaded;

  const SettingsState({
    this.settings = const Settings(),
    this.hasOpenAiKey = false,
    this.hasGeminiKey = false,
    this.loaded = false,
  });

  SettingsState copyWith({Settings? settings, bool? hasOpenAiKey, bool? hasGeminiKey, bool? loaded}) => SettingsState(
        settings: settings ?? this.settings,
        hasOpenAiKey: hasOpenAiKey ?? this.hasOpenAiKey,
        hasGeminiKey: hasGeminiKey ?? this.hasGeminiKey,
        loaded: loaded ?? this.loaded,
      );

  bool get llmEnabled =>
      (settings.aiProvider == AiProvider.openai && hasOpenAiKey) ||
      (settings.aiProvider == AiProvider.gemini && hasGeminiKey);
}

class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() => _load();

  Future<SettingsState> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.load();
    return SettingsState(
      settings: s,
      hasOpenAiKey: (await repo.getApiKey('openai')) != null,
      hasGeminiKey: (await repo.getApiKey('gemini')) != null,
      loaded: true,
    );
  }

  Future<void> setProvider(AiProvider p) async {
    await ref.read(settingsRepositoryProvider).saveProvider(p);
    state = AsyncData(await _load());
  }

  Future<void> setModel(String m) async {
    await ref.read(settingsRepositoryProvider).saveModel(m);
    state = AsyncData(await _load());
  }

  Future<void> setApiKey(AiProvider p, String key) async {
    if (key.trim().isEmpty) {
      await ref.read(settingsRepositoryProvider).deleteApiKey(p.name);
    } else {
      await ref.read(settingsRepositoryProvider).saveApiKey(p.name, key.trim());
    }
    state = AsyncData(await _load());
  }

  Future<void> setOnboarded() async {
    await ref.read(settingsRepositoryProvider).setOnboarded(true);
    state = AsyncData(await _load());
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(SettingsController.new);
