import '../l10n/localized_text.dart';

/// Messenger thread metadata from the optional `channels.json`.
class Channel {
  final String id;
  final String name;
  final String? avatar;
  final String? status;
  final List<String> members;

  /// The JSON it was read from, to show it in another language. Null when built in code.
  final Map<String, dynamic>? _json;

  const Channel({required this.id, required this.name, this.avatar, this.status, this.members = const []})
      : _json = null;

  Channel._fromJson(Map<String, dynamic> json, Localizer localizer)
      : id = json["id"] as String,
        name = localizer.required(json, "name"),
        avatar = json["avatar"] as String?,
        status = localizer.json(json["status"]),
        members = [for (final member in json["members"] as List<dynamic>? ?? const []) member.toString()],
        _json = json;

  factory Channel.fromJson(Map<String, dynamic> json, {Localizer localizer = const Localizer()}) =>
      Channel._fromJson(json, localizer);

  /// The same channel with [name] and [status] in [localizer]'s language.
  Channel localized(Localizer localizer) => switch (_json) {
        final json? => Channel._fromJson(json, localizer),
        null => this,
      };

  static List<Channel> listFromJson(Map<String, dynamic> json) {
    final list = json["channels"] as List<dynamic>? ?? const [];
    return list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
