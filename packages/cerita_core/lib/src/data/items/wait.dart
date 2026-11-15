import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

/// Pauses progression for [durationMs], optionally surfacing [notificationText].
class WaitItemType extends ItemType {
  static const type = "WAIT";

  final int durationMs;
  final String? notificationText;

  WaitItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : durationMs = (json["duration_ms"] as num? ?? 0).toInt(),
        notificationText = localizer.json(json["notification_text"]);

  @override
  String getType() => type;

  @override
  String? getText() => notificationText;
}
