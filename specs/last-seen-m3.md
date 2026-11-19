# Last Seen M3: Days 5 and 6, both routes

The beat plan for M3 (spec [`last-seen.md`](last-seen.md) §9): the route split, the Harbor and Network routes for
Days 5 and 6, and bad ends #8 *Wrong Name* and #9 *The Storm*. The engine side of M3 (route flowchart, read-skip)
is done (CE-07). The hidden truth is in [`last-seen-m2.md`](last-seen-m2.md) §2. Word counts follow M2's drafts,
about 2k Indonesian words a route-day, until the M1 timed playtest sets the budgets.

## 1. What Day 4 leaves open

| Thread | State after Day 4 | Picked up |
| :--- | :--- | :--- |
| The split | `route_lean` is `harbor` or `network` | Day 5 morning |
| Sekar | Went into hiding: switched her phone off, met a source at sea, the 4:58 jetty has mangroves | Both routes |
| Pak Hendra | Knows where she is. `hendra_warned`, `trust_hendra`, maybe `yusuf_knows_boat` | Harbor |
| Bima | Drove her. `bima_leak_planted` if he was let talk, `threatened_bima` if threatened | Network |
| Tasya | `tasya_admitted`, `trust_tasya`. The notebook page clears her | Network |
| Didit | Threatened Dinda's campus. `didit_call` recorded or not. `yusuf_knows_didit` | Both, Day 6 |
| The source | "Only at sea." The recording's second copy is on Sekar's recorder | Harbor names him |

## 2. What the routes add to the truth

Only a route that earns it says this, and only the true ending (M4) says all of it.

- **Harbor:** on Monday night Sekar boarded the *Sri Rejeki* to meet her source at sea: Pak Darmawan, a surveyor
  at the city environment office, who wouldn't talk on land. When they came back after 22:30, two men in
  Bentang shirts were waiting at the pier. Sekar switched her phone off, and Hendra kept her on the boat and took
  her to Pulau Pari at 05:30. Pak Karta's old logbook has the crossing.
- **Network:** Bima told his boss that Sekar "has the real AMDAL". His boss emailed Didit the same night, copying
  Bima. Tasya took nothing, but Didit's call to her was to find out who else knew.
- **Didit, both:** on Day 5 he files a report that Hendra kidnapped Sekar, so the police and Bentang "security" go
  to Pari together. It forces the crossing on Day 6, in a storm.

## 3. The split

`d5_morning` (VN, living room, checkpoint "Hari 5") is shared. Monday. Bima's day of grace is over if he was
threatened (he went to Yusuf, or he didn't). Dinda is home from campus. The scene ends on `route_lean`.

## 4. Day 5, Harbor: Kapal Pak Karta

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d5h_pier` | VN, the pier | The *Sri Rejeki* is out. Two men in Bentang shirts ask the coffee stall about it. Bu Rohmah gives Pak Karta's address in Kamal Muara (or Bu Wulan did, `wulan_knows_karta`) | Choice: watch the men or leave. Watching gets a look at them (`saw_bentang_men`) |
| 2 | `d5h_karta` | VN, Karta's house | Pak Karta, half his face slack from the stroke, knows Raka: "Anak jam lima." He keeps the old logbook Hendra still writes in | Choice how to talk to him. Clue `crossing_log` (key): "Sel 05.30, Pari, 1 org (S.)" |
| 3 | `d5h_hendra` | VN, the pier at noon | Hendra comes back and finds Raka with the logbook | Evidence "Where is she?": `crossing_log` or `sunrise_photo` right (he admits Pari, tells the Monday night story, names Darmawan if `trust_hendra >= 5`), anything else costs trust. With `trust_hendra < 0` and a wrong answer he walks off and the day ends without the story |
| 4 | `d5h_yusuf` | CALL, Yusuf | Bentang has reported Hendra for kidnapping. Police and company security go to Pari tomorrow. Yusuf warns Raka off, or with `yusuf_knows_didit` tells him he'll slow it down | Sets `pari_raid`. Voiced |
| 5 | `d5h_night` | VN, Sekar's room | Raka and Dinda plan the crossing. Hendra calls: a storm is coming | Choice: leave Sekar's phone with Dinda (`left_phone`), Hendra's warning |

## 5. Day 5, Network: Orang-Orang

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d5n_warung` | VN, Bu Sari's stall | Tasya comes, as she promised. With `trust_tasya < 0` she comes only because Dinda asked. She tells the rest of the PR call: Didit asked who else knew about "the documents" | Choice: show her the notebook page (if found): `+trust_tasya`, she cries |
| 2 | `d5n_group` | CHAT, the listener group | mpus, who is good with phones, looked up the threat's number: its cached profile picture is a man at a Bentang golf day. With `group_alerted` the number is still in the group | Clue `burner_profile` |
| 3 | `d5n_bima` | VN, the gate at dusk | Bima comes back. The deduction: who told Bentang? | Evidence: `didit_card` (he got the number from Bima) or `bima_deleted` right, and Bima forwards his boss's email: clue `bima_email` (key). `tasya_warning` or `notebook_page` names Tasya: with `trust_dinda >= 10` Dinda stops it once (retry), else bad end #8 |
| 4 | `d5n_wrong_name` | CHAT, the listener group | Bad end *Wrong Name*: Raka posts that Tasya sold Sekar out. The group turns on her, she deletes everything, Bima goes quiet, Didit is untouched | Ending `end_08_wrong_name` BAD |
| 5 | `d5n_night` | CHAT, Raka and Bima | Bima remembers Sekar asking about the Pari ferry. Didit has seen the email go out | Sets `pari_raid` (Bima hears it at the office) |

## 6. Day 6, Harbor: Badai

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d6h_dawn` | VN, the pier, storm warning | The harbor master has closed the sea. Hendra will go at the lull after noon, not before | Timed choice (10s): wait for Hendra, or hire a speedboat now. Hiring now leads to #9 |
| 2 | `d6h_crossing` | VN, at sea | The crossing in the lull. Hendra steers, Raka bails | Prepared (`left_phone`, `trust_hendra >= 5`): they get through. Otherwise a second chance to turn back |
| 3 | `d6h_storm` | VN | Bad end *The Storm* | Ending `end_09_the_storm` BAD |
| 4 | `d6h_pari` | VN, the Pari jetty at dusk | The jetty from the 4:58 photo. A light at the end of it, and a recorder clicking twice | Day 6 ends. Sets `reached_pari` |

## 7. Day 6, Network: Badai

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d6n_didit` | CALL, Didit | Didit offers a trade: the email and the phone for "Dik Dinda's peace of mind" | Choice: refuse, bluff, or patch Yusuf in (`yusuf_knows_didit`). Voiced |
| 2 | `d6n_kali_adem` | VN, Kali Adem ferry port, storm | Ferries cancelled. A man offers a speedboat across, for a price | Timed choice (10s): take it (#9), or wait for the first ferry with Tasya and Bima |
| 3 | `d6n_storm` | VN | Bad end *The Storm*, from the port | Ending `end_09_the_storm` BAD |
| 4 | `d6n_night` | VN, the port's waiting room | The three of them wait out the storm. Tasya and Raka talk about the podcast | Day 6 ends at 05:20 with the first ferry boarding. Sets `on_first_ferry` |

## 8. Flags for M4

| Flag | Set by | Read by |
| :--- | :--- | :--- |
| `route` | `d5_morning`: `harbor` or `network` | Day 7 router |
| `clue_crossing_log`, `clue_bima_email` | The two key clues | Endings. Remembered (`meta.flag.*`) for the cross-run true ending |
| `knows_source` | Hendra names Darmawan | True ending, *Episode 12* |
| `pari_raid` | Both routes | Day 7: the police are coming |
| `reached_pari`, `on_first_ferry` | End of Day 6 | Day 7 opening |

## 9. Systems totals after M3

| System | Spec target | After M2 | M3 adds | After M3 |
| :--- | ---: | ---: | ---: | ---: |
| Clues | 24 | 17 | 3 (`crossing_log`, `burner_profile`, `bima_email`) | 20 |
| Key clues | 8 | 6 | 2 (`crossing_log`, `bima_email`) | 8 |
| Evidence questions | ~8 | 5 | 2 (Hendra, Bima) | 7 |
| Timed choices | ~10 | 5 | 2 (the speedboat on each route) | 7 |
| Endings | 10 | 1 | 2 (#8, #9) | 3 |

## 10. Production list

- **Art:** `bg_karta_house_day`, `bg_sea_storm`, `bg_kali_adem_storm`, CGs `cg_wrong_name` and `cg_the_storm`,
  photos `photo_crossing_log`, `photo_bima_email`, `photo_burner_profile`. Pak Karta has no sprite: he speaks from
  his bed off stage.
- **Voice:** the Yusuf call (Harbor) and the Didit call (Network), about 20 lines a locale.
- **Sound:** a storm loop and thunder, CC0.

## 11. As written

`story/50_day5.cerita` and `story/60_day6.cerita`. Per route, Harbor runs about 1.3k words on Day 5 and 0.7k on Day
6, Network about 1.0k and 0.5k, so both routes are thinner than M2's days (see the decisions log).

- **The logbook** has no Monday night entry: Hendra logged the Pari crossing but not the secret trip out to sea. He
  tells that part himself, and names Darmawan only with `trust_hendra >= 5`.
- **"Phones can be tracked"** were Sekar's words. Hendra was repeating them on Day 3. He also sent the 4:58 photo
  and made the silent call, because she asked him to.
- **Hendra refusing** (`hendra_refused`, a wrong answer twice) doesn't close the Harbor route. He still calls that
  night, because Yanti told him Raka sat waiting for Karta to speak.
- **The phone on the crossing:** with `left_phone` it's at home with Dinda. Otherwise a Bentang speedboat follows
  the signal. With `trust_hendra >= 5` Hendra hides it in the engine's tin box. Below that, a 10-second choice:
  throw it in the sea (`phone_lost`, the default) or refuse, and Hendra turns back, which leads to #9.
- **New scenes:** `d5n_mpus` (Tasya forwards mpus's screenshot in her own thread) and `d5n_listeners` (Raka asks
  the group for help as himself, and Bang Jaya saw Bima sit five minutes with his head on the wheel,
  `jaya_saw_bima`).
- **Wrong Name** is a VN scene with its CG rather than a chat. Dinda stops the first wrong name with
  `trust_dinda >= 10` (`dinda_stopped_wrong`, `-trust_dinda 2`), and the question is asked again.
- **The Storm** is one conversation, `d6_storm`, reached from either route's speedboat or from Hendra turning back.
- **Didit's call** offers Dinda's "peace of mind". Patching Yusuf in (`yusuf_heard_didit`) needs `yusuf_knows_didit`.
- **Art and sound:** `bg_pari_jetty_dusk` was added for the arrival. The storm loop and thunder were made with ffmpeg
  from filtered noise (CC0, in the credits).

Read by Day 7: `route`, `knows_source`, `pari_raid`, `reached_pari`, `on_first_ferry`, `phone_lost`, `left_phone`,
`bima_confessed`, `yusuf_heard_didit`, `jaya_saw_bima`, and the remembered `knows_crossing_log` and
`knows_bima_email`.
