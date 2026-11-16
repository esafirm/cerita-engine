# Last Seen: art and voice style guide

Every generated asset follows this page. Prompts live in `art/prompts/<asset name>.txt`, one per asset, and are
committed so any image can be regenerated with `tools/codex-image.sh <asset>`.

## Look

- Painted anime visual-novel style: clean line art, soft cel shading, painterly backgrounds. Not photoreal.
- North Jakarta coast, present day: Pluit seawall, Muara Angke fish market and pier, kampung alleys, ferries to
  Kepulauan Seribu. Real-feeling clutter: plastic chairs, motorbikes, tarps, warung signs, power lines.
- Palette: sea teal and rust as the base, sodium-orange street light at night, washed-out haze by day.
  Storm scenes go desaturated blue-grey.
- No readable real brand names or logos. Signs use invented names or stay out of focus.

## Framing

| Kind | Size | Rules |
| :--- | :--- | :--- |
| Background | Portrait, 1080x1920 or larger at 9:16 | Eye level, empty of people, interesting detail in the lower third where the text box doesn't cover it |
| Sprite | Portrait, full height, about 1:2.1 | Knees up, facing slightly toward center, flat pure green (#00FF00) background for keying, no cast shadow |
| Avatar | Square, 512x512 | Head and shoulders, same outfit as the sprite, simple tinted background |
| CG | Portrait 9:16 | A key moment with two or more characters, cinematic |
| Chat photo | 4:5 or 9:16 | Looks like a phone photo or screenshot: slight blur, bad light, UI chrome allowed |

## Prompt templates

Background:

```text
Anime visual novel background, painted, portrait 9:16, no people. <place>, <time of day and weather>.
<three or four concrete details>. <light>. Mood: <mood>. Palette: sea teal, rust, <accent>.
Leave the lower third calm enough for a text box.
```

Sprite (after the character's reference sheet is approved, pass it with `-i`):

```text
Anime visual novel character sprite, knees-up, portrait, flat pure green #00FF00 background, no shadow.
<name>, <age>, <look and outfit from the cast sheet>. Expression: <expression>, <one physical cue>.
Same character, outfit and line weight as the reference.
```

## Cast sheet

| Character | Look | Voice (Gemini) |
| :--- | :--- | :--- |
| Raka, 22 | Lean, messy black hair, tired eyes, faded black hoodie over a grey tee, canvas sneakers | Puck |
| Sekar, 22 | Shoulder-length wavy hair tied half up, big over-ear headphones round her neck, olive field jacket, tote with a recorder | Aoede |
| Dinda, 19 | Short straight bob, oversized campus sweater, eyes red from not sleeping | Leda |
| Tasya, 23 | Long dyed-brown hair, gold hoops, cropped blazer, always holding an iced coffee | Zephyr |
| Bima, 24 | Neat undercut, linen shirt sleeves rolled, expensive watch, easy smile | Fenrir |
| Pak Hendra, 56 | Weathered skin, grey stubble, faded batik shirt open over a singlet, rubber boots, cap | Algenib |
| Ipda Yusuf, 34 | Neat police uniform or plain batik on duty, short hair, tired but kind eyes | Orus |

Voice notes: `tools/voices.json` holds each voice and its base style, the same voice for both languages. A line's
`delivery:` in the script says how it's said and never becomes spoken text.
