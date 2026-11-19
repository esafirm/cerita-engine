# Last Seen M4: Day 7 and the endings

The beat plan for M4 (spec [`last-seen.md`](last-seen.md) §9): Day 7's two openings and its ending router, the
seven endings M3 left (#1 to #6 and #10), the cross-run true ending and the secret ending. The hidden truth is in
[`last-seen-m2.md`](last-seen-m2.md) §2 and [`last-seen-m3.md`](last-seen-m3.md) §2. Word counts follow M3's drafts
until the M1 timed playtest sets the budgets.

## 1. What Day 6 leaves open

| Thread | State after Day 6 | Picked up |
| :--- | :--- | :--- |
| Harbor | `reached_pari`: Raka walks down the Pari jetty at dusk toward Sekar. The phone is in Hendra's tin box, at home with Dinda (`left_phone`) or in the sea (`phone_lost`) | The reunion, Day 6 night |
| Network | `on_first_ferry`: Raka, Tasya and (with `bima_confessed`) Bima board the 05:30 to Pari. Nobody knows where on the island she is | Day 7 morning |
| The raid | `pari_raid`: the police and Bentang's security cross as soon as the sea opens. Didit goes with them | Day 7, the jetty |
| The proof | `clue_crossing_log` (Harbor) clears Hendra. `clue_bima_email` (Network) shows who told Bentang. Each is remembered across runs (`knows_crossing_log`, `knows_bima_email`) | The jetty |
| Sekar's recorder | Has the second copy of Darmawan's recording | Every ending |

## 2. Endings

Each ending has a short scene and a CG. The table is the whole router.

| # | Ending | Category | Reached by |
| :--- | :--- | :--- | :--- |
| 1 | Undertow | TRUE | The jetty with both proofs: the logbook clears Hendra and the email shows who told Bentang. One run holds only one of them, so the other comes from memory of an earlier run (§5) |
| 2 | Still Water | GOOD | Raka finds Sekar, but she goes into hiding on Pulau Tidung with Hendra: Raka stayed silent at the reunion, or chose to let her go at dawn. The recording never leaves the island |
| 3 | Episode 12 | GOOD | The email without the logbook: Hendra is held, Sekar slips away to protect him, and Tasya publishes. Also the Network route's cold trail, with the email and `trust_tasya >= 5` |
| 4 | Unsent | GOOD | The Network trail goes cold, nothing is published, and Raka has heard Sekar's voice note (`heard_unsent_01`). He answers it |
| 5 | Runaway | NORMAL | The jetty with no proof, or the cold trail with nothing at all. Case closed as a runaway. Raka goes back to Bandung |
| 6 | Low Tide | NORMAL | The logbook without the email: Hendra is cleared, the report is withdrawn, the permit story dies. Also the cold trail with the email but no Tasya and no voice note |
| 10 | Off the Record | SECRET | All four of Sekar's unsent voice notes heard, across any runs (§6). At the reunion Raka asks about the file `0612` |

## 3. Day 7, Harbor

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d6h_sekar` | VN, the Pari jetty at night (Day 6) | The reunion. Sekar has heard everything from Hendra. "Lo telat setahun." | Timed choice (12s), the prologue's echo: "I'm sorry", "The episodes were good", "I knew where to start" (`heard_unsent_01`), or silence (default). Anything but silence sets `reconciled`. The secret question (§6) |
| 2 | `d7h_dawn` | VN, the jetty at dawn, checkpoint "Hari 7" | Hendra's radio: the police boat and Bentang's speedboat left Muara Angke at five. He can take her to Tidung before they land | With `reconciled`, Sekar lets Raka choose: stay (the jetty) or go (#2). Without it, she goes |

## 4. Day 7, Network

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d7n_ferry` | VN, the ferry deck, checkpoint "Hari 7" | Raka, Tasya, maybe Bima. Pari has three jetties and a thousand people | Memory: with `knows_crossing_log`, Raka can look for the *Sri Rejeki*. Otherwise the evidence question |
| 2 | `d7n_pari` | VN, the island | Where on Pari? | Evidence (`WHERE_PARI`, one retry): `sunrise_photo` is right (the mangrove jetty), `ferry_schedule` earns the retry, anything else loses the trail |
| 3 | `d7n_sekar` | VN, the jetty | The reunion, with Tasya there. Bima apologizes if he came | The same timed choice. Silence sends her to Tidung: #3 with the email, else #2 |
| 4 | `d7n_cold` | VN, the island | Wrong jetty. The police find the *Sri Rejeki* first and take Hendra. Sekar left an hour before | With the email Raka clears Hendra. Router: #3, #4, #6 or #5 |

## 5. The jetty: the final deduction

`d7_jetty` (VN, 07:40) is shared. The police boat comes in with Yusuf, two men in Bentang shirts and Didit, in
person for the first time. Didit calls it a rescue, points at Hendra and asks for the recorder "as evidence".
Sekar says she came on her own. Yusuf: her word isn't enough against a report with a witness.

1. **Memory.** A run that lacks a proof can still have it from an earlier run:
   - The Network route with `meta.flag.knows_crossing_log`: Raka tells Yusuf about Pak Karta's logbook in Kamal
     Muara. Yusuf has the post there photograph the page. Clue `crossing_log`.
   - The Harbor route with `meta.flag.knows_bima_email`: Raka calls Bima: "I know about the email." Bima forwards it.
     Clue `bima_email`.
   - Raka has never seen either one in this run. The narration calls it a feeling, like rereading a page.
2. **"She didn't come on her own."** Evidence `KIDNAP`, one retry. `crossing_log` is right (`proof_log`).
   `ferry_schedule` and `sunrise_photo` earn the retry ("where, not how").
3. **"Why would Bentang lie?"** Evidence `MOTIVE`, one retry. `bima_email` is right (`proof_email`). `didit_call`,
   `burner_profile` and `threat_message` show a threat, not the permit: no retry, Yusuf notes it (`proof_threat`).
4. **Router:** both proofs, #1. Only the log, #6. Only the email, #3. Neither, #5.

## 6. The secret: four unsent voice notes

Sekar kept talking to Raka for a year in notes she never sent. Four can be heard, each remembered across runs, and
each one is optional:

| Note | Where | Content |
| :--- | :--- | :--- |
| `heard_unsent_01` | Day 1 drafts or the Day 4 replay (exists) | "If I disappear, you'll know where to start." |
| `heard_unsent_02` | Day 6 Harbor, waiting with Hendra (`hendra_told`): Sekar recorded it on his phone on Monday night | "If you're hearing this from Pak Hendra's phone..." |
| `heard_unsent_03` | Day 6 Network, the waiting room (`trust_tasya >= 5`): the end of an Episode 9 session, after Sekar thought the recorder was off | "This one's good, right, Ka?" |
| `heard_unsent_04` | Day 2, an unlisted file `0612` on the podcast dashboard | Saturday a year ago, 06:12, at the pier, waiting |

No single run hears both 02 and 03. With all four remembered, the Harbor reunion offers a question (the Network
reunion happens in the morning with the police twenty minutes out, so it doesn't): "0612". Sekar plays him the hidden episode, *Episode 0: Off the Record*, a year of segments recorded for him. They
record its last segment together on the jetty, and the case is left for the morning. Ending #10.

## 7. Flags read by the router

| Flag | Set by |
| :--- | :--- |
| `reconciled` | The reunion: anything but silence |
| `found_sekar` | Harbor always. Network: the right jetty |
| `proof_log`, `proof_email`, `proof_threat` | The jetty's two questions |
| `hendra_held` | The jetty without the log, or the cold trail |

## 8. Systems totals after M4

| System | Spec target | After M3 | M4 adds | After M4 |
| :--- | ---: | ---: | ---: | ---: |
| Clues | 24 | 20 | 4 (`kidnap_report`, `pier_wait`, `boat_note`, `off_mic`) | 24 |
| Key clues | 8 | 8 | 0 | 8 |
| Evidence questions | ~8 | 7 | 3 (`WHERE_PARI`, `KIDNAP`, `MOTIVE`) | 10 |
| Timed choices | ~10 | 7 | 2 (the reunion on each route) | 9 |
| Endings | 10 | 3 | 7 | 10 |

## 9. Production list

- **Art:** `bg_pari_jetty_night`, `bg_pari_jetty_morning`, `bg_ferry_deck`, and a CG per ending: `cg_undertow`,
  `cg_still_water`, `cg_episode_12`, `cg_unsent`, `cg_runaway`, `cg_low_tide`, `cg_off_the_record`. Didit has no
  sprite: on the jetty he speaks off stage, and the narration places him.
- **Voice:** Sekar's notes 02 to 04 and the hidden episode, about 10 lines a locale.
- **Tests:** a route test per ending, and two cross-run tests that share one meta-state between runs: Network then
  Harbor for #1, and the four notes then the reunion for #10.
- **Removed:** `d7_stub` and `end_00_preview`.

## 10. As written

`story/70_day7.cerita` and `story/80_endings.cerita`, plus the three new voice notes in Days 2 and 6. Day 7 runs
0.5k to 1.0k words a route and each ending about 0.2k, short of the 3.0k and 0.8k budgets (see the decisions log).

- **The secret question** is asked at the Harbor reunion only (§6).
- **The email** is the one from Day 5: Pak Rudy to Didit, three weeks before Sekar vanished. Yusuf reads it aloud.
- **The kidnapping report** was filed on Monday, six days after the crossing. Yusuf shows it on the jetty
  (`kidnap_report`), so the logbook's date answers it.
- **The cold trail** offers the email to the police as a single choice (`CLEAR_HENDRA`, `hendra_cleared`), and
  ends as in §4.
- **Didit** speaks off stage on the jetty, in a batik shirt with an umbrella though it isn't raining.
- **Endings:** *Undertow* closes on "Sekar was last seen Saturday, 5:30 AM. Recording.", the prologue's last line
  answered. *Unsent* has Raka record his own voice note on the seawall, read three days later at 4:58 with two
  clicks. *Off the Record* is Episode 0, a folder of twelve monthly files named "KA".
