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
    "TELL_THREAT": "show",
    "GROUP_REPLY": "quiet",
    "TASYA_OPEN": "warm",
    "TASYA_PROOF": "tasya_warning",
    "BIMA_PHONE": "ask",
    "ANGKE": "mussels|stall|boats",
    "HENDRA_PROOF": "listener_photo",
    "TELL_BOAT": "keep",
    "HANDOVER": "present",
    "DIDIT_PROOF": "threat_message",
    "WHO_PICKED": "bima_deleted",
    "BIMA_PUSH": "listen",
    "RECORD": "record",
    "ROUTE_LEAN": "harbor",
    "DAWN_REPLY": "ask",
    "REPORT_DIDIT": "recording",
  },
  inputs: ["0530", "karta0530", "1427"],
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
    "TELL_THREAT": "hide",
    "GROUP_REPLY": "reply",
    "TASYA_OPEN": "blunt",
    "TASYA_PROOF": "threat_message",
    "BIMA_PHONE": "give",
    "ANGKE": "fisherman|mussels|boats|stall",
    "HENDRA_PROOF": "unsent_message",
    "TELL_BOAT": "tell",
    "HANDOVER": "send",
  },
  inputs: ["1234", "0500", "9999", "0530", "karta", "sekar", "0914", "1452", "9999"],
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
    "TASYA_PROOF": "sekar_notebook",
    "BIMA_PHONE": _timeout,
    "HENDRA_PROOF": "ferry_schedule",
    "HANDOVER": _timeout,
    "WHO_PICKED": "cctv_still",
    "BIMA_PUSH": _timeout,
  },
  inputs: ["0530", "Karta0530", "1427"],
);

/// The cold run, except Raka stalls Didit, so Day 4 plays its harsh side: the hidden threat found, the voice
/// note replayed, a wrong answer twice on the timeline, Bima pushed into hanging up, Didit not recorded.
final _Run _wary = (
  picks: {
    ..._cold.picks,
    "HANDOVER": "stall",
    "WHO_PICKED": "ferry_schedule",
    "BIMA_PUSH": "push",
    "RECORD": "listen",
    "ROUTE_LEAN": "network",
    "DAWN_REPLY": "quiet",
    "REPORT_DIDIT": "keep",
  },
  inputs: _cold.inputs,
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
    test('kind run ($locale): Dinda trusts Raka, Yusuf checks the CCTV, Tasya talks', () async {
      final (ending, engine) = await _play(locale, _kind);
      expect(ending.endingId, "end_00_preview");
      // Day 3: the CCTV comes from Yusuf, Hendra warns Raka, and the threat makes Didit slip.
      expect(engine.dataMap["heard_of_didit"], isTrue);
      expect(engine.dataMap["hull_tries"], isNull);
      expect(engine.dataMap["trust_hendra"], 5);
      expect(engine.dataMap["hendra_warned"], isTrue);
      expect(engine.dataMap["yusuf_knows_boat"], isNull);
      expect(engine.dataMap["didit_slipped"], isTrue);
      expect(engine.dataMap["heard_silent_call"], isTrue);
      expect(engine.dataMap["pass_tries"], isNull, reason: "first try");
      expect(engine.dataMap["yusuf_cctv"], isTrue);
      expect(engine.dataMap["told_dinda_truth"], isTrue);
      expect(engine.dataMap["threat_screenshot"], isTrue);
      // Day 1: worried 2, safe 5, now 5, care 4, unlocked 3, careful 2, honest -2, together 3, truth 5, care 3.
      // Day 2: the screenshot 4, staying quiet in the group 1. Day 4: naming Bima on the timeline 2.
      expect(engine.dataMap["trust_dinda"], 37);
      expect(engine.dataMap["dash_tries"], isNull, reason: "the dashboard on the first try");
      expect(engine.dataMap["tasya_admitted"], isTrue);
      expect(engine.dataMap["trust_tasya"], 7);
      expect(engine.dataMap["bima_on_edge"], isTrue);
      expect(engine.dataMap["group_alerted"], isNull);
      expect(engine.dataMap["hid_threat"], isNull);
      for (final clue in ["unsent_message", "ep12_teaser", "stake_map", "ferry_schedule", "missing_recorder",
          "sekar_notebook", "threat_message", "listener_photo", "tasya_warning", "bima_deleted", "ep12_draft", "boat_registration", "cctv_still", "didit_card", "didit_call", "notebook_page", "sunrise_photo"]) {
        expect(engine.dataMap["clue_$clue"], isTrue, reason: clue);
      }
    });

    test('cold run ($locale): wrong passwords, Yusuf unconvinced, the phone handed to Didit', () async {
      final (ending, engine) = await _play(locale, _cold);
      expect(ending.endingId, "end_07_handed_over", reason: "the phone goes to Didit's courier");
      // Day 3: no CCTV request, so the stall owner's son has the still. Three wrong hull numbers.
      expect(engine.dataMap["nudged_stall"], isTrue);
      expect(engine.dataMap["clue_cctv_still"], isTrue);
      expect(engine.dataMap["hull_tries"], 3);
      expect(engine.dataMap["clue_boat_registration"], isTrue);
      // unsent message -3, telling Yusuf about the boat -2
      expect(engine.dataMap["trust_hendra"], -5);
      expect(engine.dataMap["hendra_warned"], isNull);
      expect(engine.dataMap["heard_silent_call"], isNull);
      expect(engine.dataMap["pass_tries"], 2, reason: "the third wrong code sends Raka to remember it");
      expect(engine.dataMap["yusuf_cctv"], isNull);
      expect(engine.dataMap["lied_to_yusuf"], isTrue);
      // Day 1: alone -3, silent -2, hedge -4, unlocked 3, ferry -3, lie 3, police -3, half -2. Day 2: giving the phone -3.
      expect(engine.dataMap["trust_dinda"], -14);
      expect(engine.dataMap["clue_sekar_notebook"], isNull);
      expect(engine.dataMap["hid_threat"], isTrue);
      expect(engine.dataMap["group_alerted"], isTrue);
      expect(engine.dataMap["dash_tries"], 3, reason: "three wrong passwords send Raka to remember it");
      expect(engine.dataMap["clue_ep12_draft"], isTrue);
      expect(engine.dataMap["tasya_admitted"], isNull);
      expect(engine.dataMap["trust_tasya"], -1);
      expect(engine.dataMap["trust_bima"], -2);
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
      // Day 2: a capitalized password still opens the dashboard, and the notebook makes Tasya defensive.
      expect(engine.dataMap["dash_tries"], isNull);
      expect(engine.dataMap["TASYA_PROOF"], "sekar_notebook");
      expect(engine.dataMap["trust_tasya"], -1);
      expect(engine.dataMap["BIMA_PHONE"], "silent");
      // Day 3: the handover timer runs out, which only stalls Didit.
      expect(engine.dataMap["HANDOVER"], "ignore");
      // the ferry schedule 4, telling Yusuf about the boat -2
      expect(engine.dataMap["trust_hendra"], 2);
      expect(engine.dataMap["yusuf_knows_boat"], isTrue);
      expect(engine.dataMap["BIMA_PUSH"], "listen", reason: "silence lets Bima talk");
      expect(engine.dataMap["heard_silent_call"], isTrue);
    });

    test('wary run ($locale): Dinda finds the hidden threat, Bima hangs up, Didit unrecorded', () async {
      final (ending, engine) = await _play(locale, _wary);
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["dinda_found_threat"], isTrue);
      expect(engine.dataMap["heard_unsent_01"], isTrue, reason: "the voice note is replayed on Day 4");
      expect(engine.dataMap["WHO_PICKED"], isNotNull);
      expect(engine.dataMap["clue_didit_call"], isNull);
      expect(engine.dataMap["clue_notebook_page"], isNull, reason: "the notebook was never rubbed");
      expect(engine.dataMap["clue_sunrise_photo"], isTrue);
      expect(engine.dataMap["route_lean"], "network");
      expect(engine.dataMap["yusuf_knows_didit"], isNull);
      // Day 1 and 2 as the cold run, -14. Day 4: finding the hidden threat -4.
      expect(engine.dataMap["trust_dinda"], -18);
      // giving the phone -2, pushing -2
      expect(engine.dataMap["trust_bima"], -4);
    });
  }
}
