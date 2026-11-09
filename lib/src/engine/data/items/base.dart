import 'package:fsse/src/engine/data/effect.dart';
import 'package:fsse/src/engine/data/items/profile_info.dart';
import 'package:fsse/src/engine/utils/var_replacer.dart';

import 'branch.dart';
import 'choice.dart';
import 'ending.dart';
import 'input.dart';
import 'media.dart';
import 'narration.dart';
import 'text.dart';
import 'wait.dart';

/// Base of every conversation item. Items keep their raw JSON so they can be
/// interpolated ([cloneWithData]) and persisted in transcripts ([toJson]).
abstract class ItemType {
  final Map<String, dynamic> json;

  const ItemType(this.json);

  static ItemType fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String?;
    return switch (type) {
      TextItemType.type => TextItemType.fromJson(json),
      NarrationItemType.type => NarrationItemType.fromJson(json),
      MediaItemType.type => MediaItemType.fromJson(json),
      ChoiceItemType.type => ChoiceItemType.fromJson(json),
      InputItemType.type => InputItemType.fromJson(json),
      BranchItemType.type => BranchItemType.fromJson(json),
      WaitItemType.type => WaitItemType.fromJson(json),
      EndingItemType.type => EndingItemType.fromJson(json),
      _ => throw Exception("Can't handle $type in conversation"),
    };
  }

  /// Optional step ID within the conversation.
  String? get id => json["id"] as String?;

  /// Expression evaluated against the data map. The item is skipped when `false`.
  String? get condition => json["condition"] as String?;

  /// State mutations applied when the item is executed.
  List<Effect> get effects => Effect.listFromJson(json["effects"]);

  String? getText();

  String getType();

  ProfileInfo? getProfileInfo() => null;

  ItemType cloneWithData(Map<String, dynamic> data) => ItemType.fromJson(interpolateItemJson(json, data));

  Map<String, dynamic> toJson() => json;
}
