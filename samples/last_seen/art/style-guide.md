# Last Seen: art and voice style guide

Every generated asset follows this page. Prompts live in `art/prompts/<asset name>.txt`, one per asset, and are
committed so any image can be regenerated with `tools/codex-image.sh <asset>`.

## Look

- **House style: 1990s TV anime cel look.** Flat colors, two-tone cel shading with hard shadow edges, clean line
  art with varied line weight, a limited muted palette, simplified shapes. No gradients, glow, bloom, rim light or
  lens effects. Leave things out rather than render every surface. This keeps the art from reading as default AI
  output (style test, M1).
- Backgrounds look like hand-painted anime backdrops: gouache texture, broad shapes, little clutter. Flat light by
  day. Night and dusk scenes keep one or two warm practical lights (a street lamp, a warung bulb) for mood.
- Characters are specific people, not idealized ones. Women stay clearly feminine and youthful: soft face, slim
  build, the hairstyle from the cast sheet. Spell the hairstyle out in every prompt, or it drifts.
- North Jakarta coast, present day: Pluit seawall, Muara Angke fish market and pier, kampung alleys, ferries to
  Kepulauan Seribu.
- Chat photos and screenshots are the exception: they look like real phone photos.
- No readable real brand names or logos. Signs use invented names.
- Every background gets the shared grade in `tools/finish-image.sh` (a little less saturation, a soft blur, grain).

## Framing

| Kind | Size | Rules |
| :--- | :--- | :--- |
| Background | Portrait 9:16 (Codex gives about 940x1670) | Eye level, empty of people, interesting detail in the lower third where the text box doesn't cover it |
| Sprite | Portrait, full height, about 1:2.1 | Knees up, facing slightly toward center, flat pure green (#00FF00) background for keying, no cast shadow |
| Avatar | Square, 512x512 | Head and shoulders, same outfit as the sprite, simple tinted background |
| CG | Portrait 9:16 | A key moment with two or more characters, cinematic |
| Chat photo | 4:5 or 9:16 | Looks like a phone photo or screenshot: slight blur, bad light, UI chrome allowed |

## Prompt templates

Background:

```text
Anime visual novel background, portrait 9:16, no people. <place>, <time of day>.
<three or four concrete details, not too many>. <light: flat by day, one or two warm practical lights at night>.
Style: 1990s TV anime cel look. Flat colors with two-tone cel shading and hard shadow edges, no gradients, no glow,
no bloom, no rim light. Clean line art with varied line weight. Limited muted palette. Simplified shapes. Painted
flat background like a hand-painted anime backdrop, gouache texture, broad simple shapes.
Leave the lower third calm enough for a text box.
```

Sprite (after the character's reference sheet is approved, pass it with `-i`):

```text
Anime visual novel character sprite, knees-up, portrait 1:2, centered, flat pure green #00FF00 background, no shadow,
no green in the clothes or hair.
<name>, <age>, <face, build and hairstyle from the cast sheet>, <outfit>. Expression: <expression>, <one physical cue>.
Same character, face, hairstyle, outfit and line weight as the attached reference.
Style: 1990s TV anime cel look. Flat colors with two-tone cel shading and hard shadow edges, no gradients, no glow,
no bloom, no rim light. Clean line art with varied line weight. Limited muted palette. Simplified shapes.
```

## Cast sheet

| Character | Look | Voice (Gemini) |
| :--- | :--- | :--- |
| Raka, 22 | Lean, messy black hair, tired eyes, faded black hoodie over a grey tee, canvas sneakers | Puck |
| Sekar, 22 | Soft oval face, slim. Shoulder-length wavy dark brown hair tied half up with a claw clip, small gold hoops, big over-ear headphones round her neck, oversized olive field jacket, cream tee, dark jeans, canvas tote with a recorder. Reference: `art/refs/sekar.png` | Aoede |
| Dinda, 19 | Short straight bob, oversized campus sweater, eyes red from not sleeping | Leda |
| Tasya, 23 | Long dyed-brown hair, gold hoops, cropped blazer, always holding an iced coffee | Zephyr |
| Bima, 24 | Neat undercut, linen shirt sleeves rolled, expensive watch, easy smile | Fenrir |
| Pak Hendra, 56 | Weathered skin, grey stubble, faded batik shirt open over a singlet, rubber boots, cap | Algenib |
| Ipda Yusuf, 34 | Neat police uniform or plain batik on duty, short hair, tired but kind eyes | Orus |

Voice notes: `tools/voices.json` holds each voice and its base style, the same voice for both languages. A line's
`delivery:` in the script says how it's said and never becomes spoken text.
