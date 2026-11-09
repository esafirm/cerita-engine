import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

import '../story_setup.dart';

/// Lists the autosave and manual slots. Saves when [onSave] is set, loads via [onLoad] otherwise.
class SaveSlotsScreen extends StatefulWidget {
  static const manualSlots = [1, 2, 3];

  final StorySetup setup;
  final Future<void> Function(int slotId)? onSave;
  final ValueChanged<SaveSlot>? onLoad;

  const SaveSlotsScreen({super.key, required this.setup, this.onSave, this.onLoad});

  @override
  State<SaveSlotsScreen> createState() => _SaveSlotsScreenState();
}

class _SaveSlotsScreenState extends State<SaveSlotsScreen> {
  late Future<List<SaveSlot>> _slots = widget.setup.storage.listSlots();

  bool get _saving => widget.onSave != null;

  String _describe(SaveSlot slot) {
    final time = slot.updatedAt.toLocal();
    final stamp = "${time.year}-${_two(time.month)}-${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}";
    return "${[slot.chapter, slot.title].whereType<String>().join(" · ")}\n$stamp";
  }

  String _two(int value) => value.toString().padLeft(2, "0");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_saving ? "Save game" : "Load game")),
      body: FutureBuilder(
        future: _slots,
        builder: (context, snapshot) {
          final slots = {for (final slot in snapshot.data ?? const <SaveSlot>[]) slot.slotId: slot};
          final ids = [if (!_saving) SaveSlot.autoSlotId, ...SaveSlotsScreen.manualSlots];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final id in ids)
                Card(
                  child: ListTile(
                    isThreeLine: slots[id] != null,
                    leading: Icon(id == SaveSlot.autoSlotId ? Icons.autorenew : Icons.bookmark_outline),
                    title: Text(id == SaveSlot.autoSlotId ? "Autosave" : "Slot $id"),
                    subtitle: Text(slots[id] == null ? "Empty" : _describe(slots[id]!)),
                    enabled: _saving || slots[id] != null,
                    onTap: () async {
                      if (_saving) {
                        await widget.onSave!(id);
                        setState(() => _slots = widget.setup.storage.listSlots());
                      } else {
                        widget.onLoad?.call(slots[id]!);
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
