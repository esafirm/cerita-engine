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
  // "a|b" answers an evidence question asked twice: a, then b.
  final asked = <String, int>{};
  ItemResult? result;
  for (var step = 0; step < 4000; step++) {
    final item = await engine.next(prevResult: result);
    result = null;
    switch (item) {
      case EndingItemType():
        return (item, engine);
      case EvidenceItemType():
        final answers = run.picks[item.variable]!.split("|");
        final times = asked.update(item.variable!, (n) => n + 1, ifAbsent: () => 0);
        final clue = engine.clues.byId(answers[times.clamp(0, answers.length - 1)]);
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
    "WATCH_MEN": "watch",
    "TALK_KARTA": "sorry",
    "WHERE_SEKAR": "crossing_log",
    "LEAVE_PHONE": "leave",
    "CROSS_NOW": "wait",
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
    "WHERE_SEKAR": "unsent_message",
    "LEAVE_PHONE": "take",
    "CROSS_NOW": _timeout,
    "THROW_PHONE": _timeout,
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
    "WHO_LEAKED": "tasya_warning",
  },
  inputs: _cold.inputs,
);

/// The kind run on the Network route: Dinda stops a wrong accusation once, Bima confesses, Yusuf hears Didit, and
/// they wait for the first ferry.
final _Run _network = (
  picks: {
    ..._kind.picks,
    "ROUTE_LEAN": "network",
    "SHOW_PAGE": "show",
    "WHO_LEAKED": "tasya_warning|didit_card",
    "DIDIT_DEAL": "yusuf",
    "CROSS_NOW": "wait",
  },
  inputs: _kind.inputs,
);

/// The kind run, except Raka takes the speedboat into the storm.
final _Run _reckless = (picks: {..._kind.picks, "CROSS_NOW": "now"}, inputs: _kind.inputs);

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

  test('unlocking everything reaches every chapter with a real playthrough behind it', () async {
    final meta = GlobalMetaState();
    final report = await StoryUnlocker(AssetEngineLoader(const LoaderConfig())).unlockAll(meta);
    expect(report.unplayedChapters, isEmpty);
    expect(meta.unlockedEndingIds, containsAll(["end_00_preview", "end_07_handed_over"]));
    expect(meta.unlockedMediaIds, contains("cg_handed_over"));
    // Day 4 starts with what Days 2 and 3 found.
    final day4 = meta.unlockedCheckpoints["d4_timeline"]!.dataMap;
    for (final clue in ["listener_photo", "bima_deleted", "boat_registration", "cctv_still", "didit_card"]) {
      expect(day4["clue_$clue"], isTrue, reason: clue);
    }
    expect(meta.rememberedFacts, isEmpty);
  });

  for (final locale in ["id", "en"]) {
    test('kind run ($locale): Dinda trusts Raka, Yusuf checks the CCTV, Tasya talks', () async {
      final (ending, engine) = await _play(locale, _kind);
      expect(ending.endingId, "end_00_preview");
      // Day 3: the CCTV comes from Yusuf, Hendra warns Raka, and the threat makes Didit slip.
      expect(engine.dataMap["heard_of_didit"], isTrue);
      expect(engine.dataMap["hull_tries"], isNull);
      expect(engine.dataMap["hendra_warned"], isTrue);
      expect(engine.dataMap["yusuf_knows_boat"], isNull);
      expect(engine.dataMap["didit_slipped"], isTrue);
      expect(engine.dataMap["heard_silent_call"], isTrue);
      expect(engine.dataMap["pass_tries"], isNull, reason: "first try");
      expect(engine.dataMap["yusuf_cctv"], isTrue);
      expect(engine.dataMap["told_dinda_truth"], isTrue);
      expect(engine.dataMap["threat_screenshot"], isTrue);
      // Day 1: worried 2, safe 5, now 5, care 4, unlocked 3, careful 2, honest -2, together 3, truth 5, care 3.
      // Day 2: the screenshot 4, staying quiet in the group 1. Day 4: naming Bima on the timeline 2. Day 5: leaving
      // her the phone 2.
      expect(engine.dataMap["trust_dinda"], 39);
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
      // Day 3: the ferry schedule 4, telling Yusuf about the boat -2. Day 5: sorry 2, a wrong answer -1, then -2.
      expect(engine.dataMap["trust_hendra"], 1);
      expect(engine.dataMap["yusuf_knows_boat"], isTrue);
      expect(engine.dataMap["BIMA_PUSH"], "listen", reason: "silence lets Bima talk");
      // Day 5: a wrong answer twice and Hendra refuses. Day 6: the lull, and the phone over the side on the timer.
      expect(engine.dataMap["hendra_refused"], isTrue);
      expect(engine.dataMap["hendra_told"], isNull);
      expect(engine.dataMap["CROSS_NOW"], "sit");
      expect(engine.dataMap["THROW_PHONE"], "throw");
      expect(engine.dataMap["phone_lost"], isTrue);
      expect(engine.dataMap["reached_pari"], isTrue);
      expect(engine.dataMap["heard_silent_call"], isTrue);
    });

    test('network run ($locale): Dinda stops a wrong name, Bima confesses, the first ferry', () async {
      final (ending, engine) = await _play(locale, _network);
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["route"], "network");
      expect(engine.dataMap["dinda_stopped_wrong"], isTrue);
      expect(engine.dataMap["clue_burner_profile"], isTrue);
      expect(engine.dataMap["clue_bima_email"], isTrue);
      expect(engine.meta.rememberedFacts, contains("knows_bima_email"));
      expect(engine.dataMap["bima_confessed"], isTrue);
      expect(engine.dataMap["yusuf_heard_didit"], isTrue);
      expect(engine.dataMap["on_first_ferry"], isTrue);
      // Through Day 4 as the kind run, 37. Day 5: Dinda arguing -2.
      expect(engine.dataMap["trust_dinda"], 35);
      // Day 2: warm 2, the right clue 5. Day 5: the notebook page 4. Day 6: waiting together 2.
      expect(engine.dataMap["trust_tasya"], 13);
      // Day 4: letting him talk 3. Day 5: Didit's card 2.
      expect(engine.dataMap["trust_bima"], 5);
    });

    test('reckless run ($locale): the speedboat into the storm', () async {
      final (ending, engine) = await _play(locale, _reckless);
      expect(ending.endingId, "end_09_the_storm");
      expect(engine.dataMap["reached_pari"], isNull);
    });

    test('wary run ($locale): Dinda finds the hidden threat, Bima hangs up, Raka names Tasya', () async {
      final (ending, engine) = await _play(locale, _wary);
      expect(ending.endingId, "end_08_wrong_name", reason: "with Dinda's trust gone, nobody stops Raka naming Tasya");
      expect(engine.dataMap["route"], "network");
      expect(engine.dataMap["dinda_stopped_wrong"], isNull);
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
