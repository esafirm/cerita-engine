import 'package:cerita_core/src/data/effect.dart';
import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';
import 'package:cerita_core/src/utils/var_replacer.dart';

import 'branch.dart';
import 'choice.dart';
import 'ending.dart';
import 'flow.dart';
import 'input.dart';
import 'media.dart';
import 'narration.dart';
import 'stage.dart';
import 'text.dart';
import 'wait.dart';

/// Base of every conversation item. Items keep their raw JSON so they can be
/// interpolated ([cloneWithData]), shown in another language ([localized]) and
/// persisted in transcripts ([toJson]). Typed text fields are resolved with the
/// [Localizer] given to [ItemType.fromJson].
abstract class ItemType {
  final Map<String, dynamic> json;

  const ItemType(this.json);

  static ItemType fromJson(Map<String, dynamic> json, {Localizer localizer = const Localizer()}) {
    final type = json["type"] as String?;
    return switch (type) {
      TextItemType.type => TextItemType.fromJson(json, localizer: localizer),
      NarrationItemType.type => NarrationItemType.fromJson(json, localizer: localizer),
      MediaItemType.type => MediaItemType.fromJson(json, localizer: localizer),
      ChoiceItemType.type => ChoiceItemType.fromJson(json, localizer: localizer),
      InputItemType.type => InputItemType.fromJson(json, localizer: localizer),
      BranchItemType.type => BranchItemType.fromJson(json),
      WaitItemType.type => WaitItemType.fromJson(json, localizer: localizer),
      EndingItemType.type => EndingItemType.fromJson(json, localizer: localizer),
      JumpItemType.type => JumpItemType.fromJson(json),
      CallItemType.type => CallItemType.fromJson(json),
      ReturnItemType.type => ReturnItemType.fromJson(json),
      SetItemType.type => SetItemType.fromJson(json),
      StageItemType.type => StageItemType.fromJson(json),
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

  /// The same item with its text in [localizer]'s language.
  ItemType localized(Localizer localizer) => ItemType.fromJson(json, localizer: localizer);

  /// Fills `{{VAR}}` placeholders in every language, then resolves the text with [localizer].
  ItemType cloneWithData(Map<String, dynamic> data, {Localizer localizer = const Localizer()}) =>
      ItemType.fromJson(interpolateItemJson(json, data), localizer: localizer);

  Map<String, dynamic> toJson() => json;
}
