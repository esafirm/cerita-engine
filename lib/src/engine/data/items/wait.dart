import 'base.dart';

/// Pauses progression for [durationMs], optionally surfacing [notificationText].
class WaitItemType extends ItemType {
  static const type = "WAIT";

  final int durationMs;
  final String? notificationText;

  WaitItemType.fromJson(super.json)
      : durationMs = (json["duration_ms"] as num? ?? 0).toInt(),
        notificationText = json["notification_text"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => notificationText;
}
