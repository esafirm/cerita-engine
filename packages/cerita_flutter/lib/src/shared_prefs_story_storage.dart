import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
