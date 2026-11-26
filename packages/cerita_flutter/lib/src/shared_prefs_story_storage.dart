import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsStoryStorage extends StoryStorage {
  static const _metaKey = "fsse.meta";
  static const _slotPrefix = "fsse.slot.";
  static const _settingsKey = "fsse.settings";

  final String namespace;

  SharedPrefsStoryStorage({this.namespace = "default"});

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String get _meta => "$_metaKey.$namespace";

  String _slot(int id) => "$_slotPrefix$namespace.$id";

  String get _settings => "$_settingsKey.$namespace";

  @override
  Future<GlobalMetaState> loadMeta() async {
    final raw = (await _prefs).getString(_meta);
    return raw == null ? GlobalMetaState() : GlobalMetaState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveMeta(GlobalMetaState meta) async => (await _prefs).setString(_meta, jsonEncode(meta.toJson()));

  @override
  Future<SaveSlot?> loadSlot(int slotId) async {
    final raw = (await _prefs).getString(_slot(slotId));
    return raw == null ? null : SaveSlot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool _isOwnSlotKey(String key) {
    final prefix = "$_slotPrefix$namespace.";
    return key.startsWith(prefix) && int.tryParse(key.substring(prefix.length)) != null;
  }

  @override
  Future<List<SaveSlot>> listSlots() async {
    final prefs = await _prefs;
    final slots = <SaveSlot>[];
    for (final key in prefs.getKeys()) {
      if (!_isOwnSlotKey(key)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        slots.add(SaveSlot.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignore a corrupted slot rather than hiding every other save.
      }
    }
    return slots..sort((a, b) => a.slotId.compareTo(b.slotId));
  }

  @override
  Future<void> saveSlot(SaveSlot slot) async =>
      (await _prefs).setString(_slot(slot.slotId), jsonEncode(slot.toJson()));

  @override
  Future<void> deleteSlot(int slotId) async => (await _prefs).remove(_slot(slotId));

  @override
  Future<PlayerSettings> loadSettings() async {
    final raw = (await _prefs).getString(_settings);
    return raw == null ? const PlayerSettings() : PlayerSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveSettings(PlayerSettings settings) async =>
      (await _prefs).setString(_settings, jsonEncode(settings.toJson()));

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((key) => key == _meta || _isOwnSlotKey(key)).toList();
    await Future.wait([for (final key in keys) prefs.remove(key)]);
  }
}
