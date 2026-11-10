import 'base.dart';

/// Base of the items the engine resolves by itself without showing them: [JumpItemType],
/// [CallItemType], [ReturnItemType] and [SetItemType]. Their `effects` are applied on the way.
abstract class FlowItemType extends ItemType {
  const FlowItemType(super.json);

  @override
  String? getText() => null;
}

/// Continues at [target] (`conv`, `#label` or `conv#label`).
class JumpItemType extends FlowItemType {
  static const type = "JUMP";

  final String target;

  JumpItemType.fromJson(super.json) : target = json["target"] as String;

  @override
  String getType() => type;
}

/// Continues at [target] and comes back to the next item on [ReturnItemType].
class CallItemType extends FlowItemType {
  static const type = "CALL";

  final String target;

  CallItemType.fromJson(super.json) : target = json["target"] as String;

  @override
  String getType() => type;
}

/// Goes back to the item after the last [CallItemType].
class ReturnItemType extends FlowItemType {
  static const type = "RETURN";

  const ReturnItemType.fromJson(super.json);

  @override
  String getType() => type;
}

/// Only applies its `effects`.
class SetItemType extends FlowItemType {
  static const type = "SET";

  const SetItemType.fromJson(super.json);

  @override
  String getType() => type;
}
