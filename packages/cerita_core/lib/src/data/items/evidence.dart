import 'package:cerita_core/src/data/effect.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

import 'choice.dart';

/// A `CHOICE` with `"source": "clues"`: the player answers by presenting a clue they found. It has no
/// `choices`, the options are the clues found in this playthrough. See `specs/data-schema.md` section 4.4.
class EvidenceItemType extends ChoiceItemType {
  static const source = "clues";

  /// Outcomes for specific clues. Final, whether right or wrong.
  final List<EvidenceResponse> responses;

  /// How many wrong clues the player can present before [fallback].
  final int retries;

  /// Plays after a wrong clue while retries remain. Null, or no target, asks the question again.
  final EvidenceOutcome? retry;

  /// Plays after a wrong clue once no retries remain, and when no clue is found at all.
  final EvidenceOutcome? fallback;

  /// Plays when `timeout_ms` runs out. Null plays [fallback].
  final EvidenceOutcome? timeout;

  EvidenceItemType.fromJson(super.json, {super.localizer})
      : responses = [
          for (final raw in json["responses"] as List<dynamic>? ?? const [])
            EvidenceResponse.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
        retries = (json["retries"] as num?)?.toInt() ?? 0,
        retry = EvidenceOutcome.maybe(json["retry"]),
        fallback = EvidenceOutcome.maybe(json["fallback"]),
        timeout = EvidenceOutcome.maybe(json["timeout"]),
        super.fromJson(choices: const []);

  /// Evidence questions have no listed options to replace.
  @override
  EvidenceItemType withChoices(List<Choice> choices) => this;

  @override
  EvidenceItemType localized(Localizer localizer) => EvidenceItemType.fromJson(json, localizer: localizer);

  EvidenceResponse? responseFor(String clueId) => responses.where((response) => response.clue == clueId).firstOrNull;
}

/// What plays after an answer: its [effects], then its [target]. No target continues after the question.
class EvidenceOutcome {
  final List<Effect> effects;
  final String? target;

  const EvidenceOutcome({this.effects = const [], this.target});

  factory EvidenceOutcome.fromJson(Map<String, dynamic> json) =>
      EvidenceOutcome(effects: Effect.listFromJson(json["effects"]), target: json["target"] as String?);

  static EvidenceOutcome? maybe(Object? json) =>
      json is Map ? EvidenceOutcome.fromJson(Map<String, dynamic>.from(json)) : null;
}

/// The outcome of presenting one specific [clue].
class EvidenceResponse extends EvidenceOutcome {
  /// The clue `id`.
  final String clue;

  const EvidenceResponse(this.clue, {super.effects, super.target});

  factory EvidenceResponse.fromJson(Map<String, dynamic> json) => EvidenceResponse(
        json["clue"] as String? ?? (throw FormatException("An evidence response needs a 'clue'", json)),
        effects: Effect.listFromJson(json["effects"]),
        target: json["target"] as String?,
      );
}
