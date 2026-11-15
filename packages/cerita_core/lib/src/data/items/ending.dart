import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

enum EndingCategory {
  trueEnding("TRUE"),
  good("GOOD"),
  normal("NORMAL"),
  bad("BAD"),
  secret("SECRET");

  final String key;

  const EndingCategory(this.key);

  static EndingCategory fromKey(String? key) => values.where((e) => e.key == key).firstOrNull ?? normal;
}

/// Marks the end of a route and records it in the global endings registry.
class EndingItemType extends ItemType {
  static const type = "ENDING";

  final String endingId;
  final String title;
  final EndingCategory category;
  final String? summary;

  EndingItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : endingId = json["ending_id"] as String,
        title = localizer.required(json, "title"),
        category = EndingCategory.fromKey(json["category"] as String?),
        summary = localizer.json(json["summary"]);

  @override
  EndingItemType localized(Localizer localizer) => EndingItemType.fromJson(json, localizer: localizer);

  @override
  String getType() => type;

  @override
  String? getText() => title;
}
