import 'dart:convert';

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
