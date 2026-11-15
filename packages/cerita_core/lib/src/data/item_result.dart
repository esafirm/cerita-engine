import '../l10n/localized_text.dart';
import '../utils/text_markup.dart';
import 'effect.dart';
import 'items/choice.dart';

/// The player's answer to an INPUT or CHOICE item, passed to `FsseEngine.next`.
class ItemResult {
  final String? variable;
  final dynamic value;
  final List<Effect> effects;
  final String? target;

  /// Text shown as the player's outgoing message (chat transcript / backlog), without text tags.
  final String? text;

  /// [Choice.index] of the picked choice.
  final int? choiceIndex;

  /// [text] in every language, for a localized choice. The transcript keeps it so history can be shown in
  /// another language later.
  final LocalizedText? localizedText;

  const ItemResult({
    this.variable,
    this.value,
    this.effects = const [],
    this.target,
    this.text,
    this.choiceIndex,
    this.localizedText,
  });

  const ItemResult.input(this.variable, String this.value)
      : effects = const [],
        target = null,
        text = value,
        choiceIndex = null,
        localizedText = null;

  ItemResult.choice(this.variable, Choice choice)
      : value = choice.value ?? TextMarkup.plain(choice.text),
        effects = choice.effects,
        target = choice.target,
        text = TextMarkup.plain(choice.text),
        choiceIndex = choice.index,
        localizedText = choice.localizedText?.map(TextMarkup.plain);
}
