import '../l10n/localized_text.dart';
import '../utils/text_markup.dart';
import 'clue.dart';
import 'effect.dart';
import 'items/choice.dart';
import 'items/evidence.dart';

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

  /// The `id` of the clue presented to an evidence question. The engine picks the outcome.
  final String? presentedClue;

  /// An evidence question's countdown ran out. The engine plays its timeout outcome.
  final bool evidenceTimedOut;

  const ItemResult({
    this.variable,
    this.value,
    this.effects = const [],
    this.target,
    this.text,
    this.choiceIndex,
    this.localizedText,
    this.presentedClue,
    this.evidenceTimedOut = false,
  });

  const ItemResult.input(this.variable, String this.value)
      : effects = const [],
        target = null,
        text = value,
        choiceIndex = null,
        localizedText = null,
        presentedClue = null,
        evidenceTimedOut = false;

  /// A [Choice.silent] option has no [text], so nothing is sent as the player's reply.
  ItemResult.choice(this.variable, Choice choice)
      : value = choice.value ?? TextMarkup.plain(choice.text),
        effects = choice.effects,
        target = choice.target,
        text = choice.silent ? null : TextMarkup.plain(choice.text),
        choiceIndex = choice.index,
        localizedText = choice.silent ? null : choice.localizedText?.map(TextMarkup.plain),
        presentedClue = null,
        evidenceTimedOut = false;

  /// Presents [clue] to the evidence [question]. Its `variable` receives the clue `id`, and the transcript
  /// keeps the clue's title in every language.
  ItemResult.present(EvidenceItemType question, Clue clue)
      : variable = question.variable,
        value = clue.id,
        effects = const [],
        target = null,
        text = clue.title.toString(),
        choiceIndex = null,
        localizedText = clue.title,
        presentedClue = clue.id,
        evidenceTimedOut = false;

  /// The countdown of an evidence question ran out.
  const ItemResult.evidenceTimeout()
      : variable = null,
        value = null,
        effects = const [],
        target = null,
        text = null,
        choiceIndex = null,
        localizedText = null,
        presentedClue = null,
        evidenceTimedOut = true;
}
