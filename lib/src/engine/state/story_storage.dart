import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'meta_state.dart';
import 'save_slot.dart';

/// Persists the global meta-state and playthrough save slots.
abstract class StoryStorage {
  Future<GlobalMetaState> loadMeta();

  Future<void> saveMeta(GlobalMetaState meta);

  Future<SaveSlot?> loadSlot(int slotId);

  Future<List<SaveSlot>> listSlots();

  Future<void> saveSlot(SaveSlot slot);

  Future<void> deleteSlot(int slotId);

  /// Wipes meta-state and every save slot.
  Future<void> clear();
}

class InMemoryStoryStorage extends StoryStorage {
  // Stored as JSON so tests exercise the same serialization as real storage.
  String? _meta;
  final Map<int, String> _slots = {};

  @override
  Future<GlobalMetaState> loadMeta() async =>
      _meta == null ? GlobalMetaState() : GlobalMetaState.fromJson(jsonDecode(_meta!) as Map<String, dynamic>);

  @override
  Future<void> saveMeta(GlobalMetaState meta) async => _meta = jsonEncode(meta.toJson());

  @override
  Future<SaveSlot?> loadSlot(int slotId) async {
    final raw = _slots[slotId];
    return raw == null ? null : SaveSlot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<List<SaveSlot>> listSlots() async {
    final ids = _slots.keys.toList()..sort();
    return [for (final id in ids) (await loadSlot(id))!];
  }

  @override
  Future<void> saveSlot(SaveSlot slot) async => _slots[slot.slotId] = jsonEncode(slot.toJson());

  @override
  Future<void> deleteSlot(int slotId) async => _slots.remove(slotId);

  @override
  Future<void> clear() async {
    _meta = null;
    _slots.clear();
  }
}

class SharedPrefsStoryStorage extends StoryStorage {
  static const _metaKey = "fsse.meta";
  static const _slotPrefix = "fsse.slot.";

  final String namespace;

  SharedPrefsStoryStorage({this.namespace = "default"});

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String get _meta => "$_metaKey.$namespace";

  String _slot(int id) => "$_slotPrefix$namespace.$id";

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

  @override
  Future<List<SaveSlot>> listSlots() async {
    final prefs = await _prefs;
    final prefix = "$_slotPrefix$namespace.";
    final slots = prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .map((key) => SaveSlot.fromJson(jsonDecode(prefs.getString(key)!) as Map<String, dynamic>))
        .toList();
    return slots..sort((a, b) => a.slotId.compareTo(b.slotId));
  }

  @override
  Future<void> saveSlot(SaveSlot slot) async =>
      (await _prefs).setString(_slot(slot.slotId), jsonEncode(slot.toJson()));

  @override
  Future<void> deleteSlot(int slotId) async => (await _prefs).remove(_slot(slotId));

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((key) => key == _meta || key.startsWith("$_slotPrefix$namespace."));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }
}
