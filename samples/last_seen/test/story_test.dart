import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// One playthrough's answers: a choice `value` (or a clue id for an evidence question) per variable, and the
/// text typed into each INPUT, in order.
typedef _Run = ({Map<String, String> picks, List<String> inputs});

/// The answer that lets a timed choice run out, so it takes its `[default]` option.
const _timeout = "<timeout>";

/// Plays Last Seen headlessly in [locale], so every route and JSON file is exercised. A choice without an
/// answer in [run] takes its first available option.
Future<(EndingItemType, RealFsseEngine)> _play(String locale, _Run run) async {
  final engine = RealFsseEngine(AssetEngineLoader(const LoaderConfig()))..locale = locale;
  final inputs = [...run.inputs];
  ItemResult? result;
  for (var step = 0; step < 2000; step++) {
    final item = await engine.next(prevResult: result);
    result = null;
    switch (item) {
      case EndingItemType():
        return (item, engine);
      case EvidenceItemType():
        final clue = engine.clues.byId(run.picks[item.variable]!);
        expect(clue, isNotNull, reason: "no clue '${run.picks[item.variable]}'");
        result = ItemResult.present(item, clue!);
      case ChoiceItemType():
        final wanted = run.picks[item.variable];
        if (wanted == _timeout) expect(item.timeoutMs, isNotNull, reason: "${item.variable} has no timer");
        // "a|b|c" is an order of preference, for hubs that come back to the same choice.
        final preferred = wanted?.split("|") ?? const <String>[];
        final choice = wanted == _timeout
            ? item.timeoutChoice!
            : [
                for (final value in preferred) ...item.availableChoices.where((c) => c.value == value),
                item.availableChoices.first,
              ].first;
        expect(choice.locked, isFalse, reason: "'${choice.text}' is locked");
        result = ItemResult.choice(item.variable, choice);
      case InputItemType():
        expect(inputs, isNotEmpty, reason: "unexpected input ${item.variable}");
        result = ItemResult.input(item.variable, inputs.removeAt(0));
      default:
        break;
    }
  }
  fail("No ending reached");
}

/// Everything kind to Dinda, every room spot, the passcode on the first try.
const _Run _kind = (
  picks: {
    "FALLOUT": "silent",
    "UNSENT": "sorry",
    "PLAY_EP": "play",
    "FIRST_REPLY": "worried",
    "CALL_REACT": "safe",
    "ANSWER": "now",
    "ASK_FIRST": "care",
    "NOTEBOOK": "rub",
    "PHONE_PLAN": "careful",
    "YUSUF_PROOF": "missing_recorder",
    "TELL_YUSUF": "honest",
    "LUNCH_ASK": "scared",
    "LUNCH_COMFORT": "together",
    "PLAY_VN": "play",
    "ROOF_TRUTH": "truth",
    "WULAN_REPLY": "care",
    "THREAT_REPLY": "quiet",
  },
  inputs: ["0530"],
);

/// Cold all the way, a short room search, three wrong passcodes before Raka remembers.
const _Run _cold = (
  picks: {
    "FALLOUT": "cruel",
    "UNSENT": "closed",
    "PLAY_EP": "close",
    "FIRST_REPLY": "guarded",
    "CALL_REACT": "alone",
    "ANSWER": "silent",
    "ASK_FIRST": "hedge",
    "NOTEBOOK": "skip",
    "PHONE_PLAN": "rush",
    "YUSUF_PROOF": "ferry_schedule",
    "TELL_YUSUF": "lie",
    "LUNCH_ASK": "bima",
    "LUNCH_MORE": "eat",
    "LUNCH_COMFORT": "police",
    "PLAY_VN": "later",
    "ROOF_TRUTH": "half",
    "WULAN_REPLY": "sorry",
    "THREAT_REPLY": "threaten",
  },
  inputs: ["1234", "0500", "9999"],
);

/// Every timed choice left to run out, and a room search that walks past the gear shelf.
const _Run _timeouts = (
  picks: {
    "FALLOUT": _timeout,
    "ANSWER": _timeout,
    "ROOM": "photo|desk|corkboard|window|leave",
    "YUSUF_PROOF": "missing_recorder",
    "TELL_YUSUF": _timeout,
    "THREAT_REPLY": _timeout,
  },
  inputs: ["0530"],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every text tag in the story is a known tag, in both languages', () async {
    for (final locale in ["id", "en"]) {
      final engine = RealFsseEngine(AssetEngineLoader(const LoaderConfig()))..locale = locale;
      final catalog = await StoryCatalog.load(engine.loader);
      for (final conversation in catalog.conversations) {
        for (final item in conversation.conversations) {
          final text = item.getText()?.replaceAll(variablePattern, "");
          if (text == null) continue;
          expect(TextMarkup.plain(text), isNot(contains("{")), reason: "'$text' in ${conversation.key}");
        }
      }
    }
  });

  for (final locale in ["id", "en"]) {
    test('kind run ($locale): Dinda trusts Raka, Yusuf checks the CCTV', () async {
      final (ending, engine) = await _play(locale, _kind);
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["pass_tries"], isNull, reason: "first try");
      expect(engine.dataMap["yusuf_cctv"], isTrue);
      expect(engine.dataMap["told_dinda_truth"], isTrue);
      expect(engine.dataMap["threat_screenshot"], isTrue);
      // worried 2, safe 5, now 5, care 4, unlocked 3, careful 2, honest -2, together 3, truth 5, care 3
      expect(engine.dataMap["trust_dinda"], 30);
      expect(engine.dataMap["trust_yusuf"], 8);
      for (final clue in ["unsent_message", "ep12_teaser", "stake_map", "ferry_schedule", "missing_recorder",
          "sekar_notebook", "threat_message"]) {
        expect(engine.dataMap["clue_$clue"], isTrue, reason: clue);
      }
    });

    test('cold run ($locale): wrong passcodes, Yusuf unconvinced', () async {
      final (ending, engine) = await _play(locale, _cold);
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["pass_tries"], 2, reason: "the third wrong code sends Raka to remember it");
      expect(engine.dataMap["yusuf_cctv"], isNull);
      expect(engine.dataMap["lied_to_yusuf"], isTrue);
      // alone -3, silent -2, hedge -4, unlocked 3, ferry -3, lie 3, police -3, half -2
      expect(engine.dataMap["trust_dinda"], -11);
      expect(engine.dataMap["clue_sekar_notebook"], isNull);
    });

    test('timeout run ($locale): timed choices fall back to silence, the room waits for the shelf', () async {
      final (ending, engine) = await _play(locale, _timeouts);
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["FALLOUT"], "silent");
      expect(engine.dataMap["ANSWER"], "silent");
      expect(engine.dataMap["TELL_YUSUF"], "silent");
      expect(engine.dataMap["THREAT_REPLY"], "ignore");
      expect(engine.dataMap["threat_screenshot"], isNull);
      // Photo, desk and corkboard make three spots, but leaving stays locked until the shelf is checked.
      expect(engine.dataMap["nudged_shelf"], isTrue);
      expect(engine.dataMap["room_looked"], 4);
      expect(engine.dataMap["clue_missing_recorder"], isTrue);
      expect(engine.dataMap["yusuf_cctv"], isTrue);
      expect(engine.dataMap["lunch_served"], isTrue);
    });
  }
}
