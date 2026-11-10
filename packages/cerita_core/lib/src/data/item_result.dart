import 'effect.dart';
import 'items/choice.dart';

/// The player's answer to an INPUT or CHOICE item, passed to `FsseEngine.next`.
class ItemResult {
  final String? variable;
  final dynamic value;
  final List<Effect> effects;
  final String? target;

  /// Text shown as the player's outgoing message (chat transcript / backlog).
  final String? text;

  /// [Choice.index] of the picked choice.
  final int? choiceIndex;

  const ItemResult({this.variable, this.value, this.effects = const [], this.target, this.text, this.choiceIndex});

  const ItemResult.input(this.variable, String this.value)
      : effects = const [],
        target = null,
        text = value,
        choiceIndex = null;

  ItemResult.choice(this.variable, Choice choice)
      : value = choice.value ?? choice.text,
        effects = choice.effects,
        target = choice.target,
        text = choice.text,
        choiceIndex = choice.index;
}
