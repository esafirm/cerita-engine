# Last Seen M2: Days 2 to 4

The beat plan for M2 (spec [`last-seen.md`](last-seen.md) §9). It fixes what each scene does, which clues, puzzles,
evidence questions and timed choices it holds, and what it needs from the art, voice and engine work. The prose comes
after the M1 playtest: the word targets below are shares of each day's budget, and the budgets are set from the timed
run (§6).

## 1. What Day 1 leaves open

| Thread | State after Day 1 | Picked up |
| :--- | :--- | :--- |
| Sekar's spare phone | Unlocked (`phone_unlocked`). The group, Tasya, Bima and unnamed numbers are unread | Day 2 |
| The threat | "Stop looking. For her sister's sake." Raka may have a screenshot (`threat_screenshot`) | Day 2 morning, Day 4 |
| "...don't trust T..." | Found if the notebook was rubbed (`clue_sekar_notebook`). Points at Tasya | Day 2, paid off Day 4 |
| Ipda Yusuf | Asked for CCTV (`yusuf_cctv`), or was lied to (`lied_to_yusuf`) | Day 3 call |
| Bima | Keeps asking for the spare phone. Works for a consultancy with property clients (`knows_bima_job`) | Day 2, Day 4 |
| The sponsor | "Some PT company guy" wanted positive coastal content. Sekar refused, Tasya wanted it (`knows_sponsor_offer`) | Day 2, Day 3 |
| The unsent voice note | Heard (`heard_unsent_01`) or left for later | Day 4 |
| Dinda | Trust built through Day 1. `told_dinda_truth` | Every day |

## 2. The hidden truth so far

Only the true route says all of this. M2 has to stay consistent with it without stating it.

- **PT Bentang Pesisir Makmur** ("PT. B" on the stake map) is the reclamation developer. Its permit rests on a faked
  environmental review. Sekar has the proof: a recording of a permit official and a copy of the real review.
- **Didit** (Aditya Nugraha) runs community relations for PT Bentang. He made the sponsor offer, sent the threat from a
  burner and wants the spare phone, because its backup holds the recording.
- **Bima** told his consultancy, whose client is PT Bentang, that Sekar had "something about the permit". He meant
  to protect her. He drove her to Muara Angke on Monday night and has lied about it since.
- **Tasya** got a call from Didit a week before Sekar vanished: take the sponsor money and talk Sekar down. She
  passed the warning on and never told anyone. The full notebook line is "jangan percaya Tasya soal sponsor, dia
  bukan jahat, dia butuh uang" ("don't trust Tasya on the sponsor, she isn't bad, she needs the money").
- **Pak Hendra** is Pak Karta's younger brother and took over his boat, the *Sri Rejeki*. He took Sekar to Pulau
  Pari on the 5:30 crossing on Tuesday morning and is hiding her there.

## 3. Day 2: Grup Chat

CHAT-heavy, Raka reading Sekar's phone with Dinda. Theme: everyone around Sekar knew a piece and kept it.
Budget share: 4.5k words, about 30 min in the M0 plan.

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d2_morning` | VN, living room, morning | Breakfast with Dinda. Raka tells her about the threat or hides it. Wulan comes out of her room for the first time | Choice: tell Dinda. Telling, with the screenshot, is `+trust_dinda`. Hiding sets `hid_threat`, which Day 4 calls out |
| 2 | `d2_group` | CHAT on Sekar's phone, "Pendengar Ep. 12" | The listener group. Theories, jokes, a fan account. On Monday at 21:47 the listener "pesisir_77" posted a blurry photo of the fish auction: "kak sekar lagi liputan malem2?? 👀". A wooden boat is in the background | Clue `listener_photo`. Choice: reply in the group as Sekar or stay quiet. Replying makes the group panic and Didit's side learns the phone is live (`group_alerted`) |
| 3 | `d2_tasya_thread` | CHAT on Sekar's phone, Tasya | A month of the duo falling apart over the sponsor. A week before, Tasya: "mereka nelpon gue. lo beneran mau publish?" Sekar: "siapa yang nelpon lo". No answer after that | Clue `tasya_warning` |
| 4 | `d2_bima_thread` | CHAT on Sekar's phone, Bima | Sweet, then strained. Monday 20:40: *This message was deleted*. Monday 23:10, Bima: "kamu udah sampe?" | Clue `bima_deleted` (key) |
| 5 | `d2_podcast` | VN, Sekar's room, afternoon | Sekar's laptop and the podcast host dashboard. Episode 12 sits there as an unpublished draft | INPUT puzzle: the dashboard password, a text answer built from her habit (a time with a story) and the boat's name from the prologue: `karta0530`. Wrong answers lead to hints. Clue `ep12_draft`: a 40-second voiced intro from Sekar |
| 6 | `d2_tasya_call` | CALL, Tasya | Raka calls Tasya. She's bright, then defensive: she "doesn't know anything" | Evidence question: present `tasya_warning` (right), `sekar_notebook` (half right: she gets defensive, `-trust_tasya`) or anything else (fallback). Right: she admits the call from "some PR guy" and that Sekar said she was meeting "a source at the pier". `trust_tasya` starts here |
| 7 | `d2_bima_visit` | VN, the house gate, night | Bima's first appearance. Charming with Dinda, careful with Raka. He wants the phone "to hand to the police" | Timed choice (10s): keep the phone, give it to Bima or ask him where he was on Monday. Giving it isn't a bad end: Dinda stops him (`-trust_dinda`, `-trust_bima`). Asking sets him on edge for Day 4 |

Day 2 ends at the gate: Bima drives off, and Raka sees the car is silver.

## 4. Day 3: Dermaga

VN and CALL at Muara Angke. Theme: the coast as Sekar saw it. The early bad end lives here.
Budget share: 4.5k words, about 28 min.

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d3_angke` | VN, fish auction, early morning | Raka (Dinda stays home with Wulan) walks the fish auction with Sekar's photo. Women shelling mussels know her from the episode. They point him to the boats | Short ask-around choice, `[once]` options like the room search |
| 2 | `d3_hull` | VN, the pier | The boat in `listener_photo` has a hull number half hidden by a tire. The harbor board lists registrations | INPUT puzzle: read the hull number from the photo and the board (`keyboard=digits`). Hints point back to the photo. Clue `boat_registration`: KM *Sri Rejeki*, owner Hendra |
| 3 | `d3_hendra` | VN, the pier at noon | Pak Hendra, gruff, mending a net. He denies knowing Sekar. Karta's name changes his face | Evidence question: `ferry_schedule` or `listener_photo` (right: he says "saya nggak tahu dia di mana" in a way that means he does, and warns Raka not to carry the phone everywhere), `unsent_message` (he goes quiet, `-trust_hendra`), fallback. `trust_hendra` starts here |
| 4 | `d3_yusuf_call` | CALL, Ipda Yusuf | Yusuf calls back. If `yusuf_cctv`: footage from Monday 21:52, Sekar getting out of a silver car near the auction. If `lied_to_yusuf`: he knows about the spare phone and is cold. If both are missing, he only says the case stays a runaway | Clue `cctv_still` with `yusuf_cctv`. Without it, `d3_angke` gives the same clue another way (a stall owner's son filmed the car on his phone), so no path loses it |
| 5 | `d3_didit` | CHAT, new thread, Didit | "Aditya, Bentang Pesisir community relations. Mas Bima gave me your number." Sympathy, a lawyer, a "digital forensics lab" for the spare phone. A courier can come tonight | Clue `didit_card`. The handover: timed choice (15s). Options: send the phone, stall, or present evidence. Presenting `threat_message` makes him slip ("demi keluarganya") and he goes quiet. Sending the phone leads to `end_07_handed_over` |
| 6 | `d3_handed_over` | VN | Bad end #7 *Handed Over*. The courier leaves. By morning the phone's cloud backup is wiped, the group goes silent, and Yusuf closes the case | Ending `end_07_handed_over` BAD |
| 7 | `d3_silent_call` | CALL, unknown number, night | A call with no voice. Waves, a generator, a recorder button clicking twice. Raka says her name. The line drops | No choices. Sets `heard_silent_call` |

The handover is a trap the story warns about: Hendra's warning, the threat naming "her sister" and Didit knowing
Dinda's name. Low `trust_dinda` removes Dinda's "jangan" before the timer runs.

## 5. Day 4: Malam Itu

CALL and CHAT. Theme: rebuilding Monday night minute by minute. Budget share: 4.5k words, about 28 min.

| # | Conversation | Mode | Beat | Systems |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `d4_timeline` | VN, Sekar's room, morning | Raka and Dinda lay out Monday on the corkboard: 20:40 the deleted message, 20:50 the unsent message, 21:00 the pickup, 21:47 the listener photo, 21:52 the car, 22:40 the main phone dies, 05:30 the ferry | Evidence question "Who picked her up?": `bima_deleted` or `cctv_still` (right), anything else (fallback with a retry). If `hid_threat`, Dinda finds the threat on the phone here and it costs trust |
| 2 | `d4_unsent_replay` | VN | Only if `heard_unsent_01` isn't set: Raka finally plays the voice note | Sets `heard_unsent_01` |
| 3 | `d4_bima_call` | CALL, Bima | The confrontation. Bima admits he drove her to Muara Angke, she sent him home, and his firm told him to stay out of it. He doesn't yet say he told them about the documents | Timed choice (10s): push, threaten to tell Yusuf, or let him talk. Letting him talk is `+trust_bima` and plants the leak for Day 5 |
| 4 | `d4_didit_call` | CALL, Didit | Didit's first voice. Friendly, then not: he knows Raka refused, knows Dinda's campus | Choice: record the call on Sekar's recorder app. Recording gives clue `didit_call` (key): "demi adiknya" in his own voice, the phrase from the threat |
| 5 | `d4_notebook` | CHAT, Sekar's notes app | The cloud backup has a photo of the torn page. The full line: "don't trust Tasya on the sponsor, she isn't bad, she needs the money" | Clue `notebook_page`. Only if `clue_sekar_notebook`, otherwise a shorter version from Dinda |
| 6 | `d4_choice` | VN, the roof, night | Raka and Dinda decide where to push next: the harbor (Hendra) or the people (Tasya and Bima) | Sets `route_lean` for the Day 5 split (M3) |
| 7 | `d4_sunrise` | CHAT, unknown number | 04:58. A photo of a pier at dawn, the same as the lock screen. "Masih di sana." | Clue `sunrise_photo`. Day 4 ends |

## 6. Systems totals after M2

| System | Spec target | After M1 | M2 adds | After M2 |
| :--- | ---: | ---: | ---: | ---: |
| Clues | 24 | 7 | 10 (`listener_photo`, `tasya_warning`, `bima_deleted`, `ep12_draft`, `boat_registration`, `cctv_still`, `didit_card`, `didit_call`, `notebook_page`, `sunrise_photo`) | 17 |
| Key clues | 8 | 4 | 2 (`bima_deleted`, `didit_call`) | 6 |
| Evidence questions | ~8 | 1 | 4 (Tasya, Hendra, Didit, the timeline) | 5 |
| INPUT puzzles | ~6 | 1 | 2 (the dashboard password, the hull number) | 3 |
| Timed choices | ~10 | 2 | 3 (Bima's visit, the handover, the Bima call) | 5 |
| Endings | 10 | 0 (+ the preview) | 1 (`end_07_handed_over`) | 1 |

Trust variables added: `trust_tasya`, `trust_bima`, `trust_hendra`.

Word budgets wait on the M1 timed run. Day 1 came in at 2.7k words against its 4.0k budget, and the estimator
reads it as 16.4 minutes. If the real run is close to the estimate, M2 is written to the budgets above. If it runs
long, the budgets shrink so the critical path still lands near 3 hours.

## 7. Production list

**Engine (spec first, then code):**

- **Someone else's phone in CHAT.** Day 2 shows Sekar's threads. Her own messages must sit on the outgoing side,
  but outgoing today means the player profile. A scene field such as `owner: sekar` would put that profile on the
  outgoing side for the scene, and show the owner's contacts in the header. Needs data-schema and
  presentation-modes changes, the compiler's `@scene owner=` and tests.
- **Deleted messages** need nothing new: an italic `{i}` line in the sender's bubble.

**Art:**

- Real sprites for Tasya, Bima and Hendra (still placeholders), from reference sheets first (spec §10).
- Backgrounds: `bg_muara_angke_dawn`, `bg_pier_day`, `bg_sekar_house_gate_night`, `bg_sekar_room_night`.
- Chat photos: `photo_listener_auction`, `photo_cctv_still`, `photo_didit_card`, `photo_notebook_page`,
  `photo_sunrise_pier`.
- Avatars: the listener group and a few listeners.
- A CG for the handover ending.

**Voice:** the Tasya call, Sekar's Episode 12 intro, the Yusuf call, the Bima call and the Didit call. About 80
lines a locale. At about $0.0015 a take, a little over $0.20 for both locales.

**Music and sound:** a harbor ambience, a tense call loop and the generator hum for the silent call, all CC0.

**Channels:** `group_ep12`, `sekar_tasya`, `sekar_bima`, `sekar_notes`, `thread_didit`, `thread_yusuf`, plus
`thread_tasya` and `thread_bima` for Raka's calls.

## 8. Changes to the main plan

- **Didit's first contact moves to Day 3.** The main plan has it on Day 4, but the Day 3 bad end needs Didit to ask
  for the phone. Day 3 is his chat, Day 4 his first call.
- **The early bad end is a handover by courier.** Didit is chat and call only, so he never comes to the house.
