# Credits screen (CE-08)

| | |
| :--- | :--- |
| **Status** | Backlog |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | User stories only (small, low-risk) |
| **Priority** | Should, needed by Last Seen M5 |
| **Related features** | Title screen, Endings, Bilingual stories (CE-01), skins |

## Why

Last Seen uses third-party music and sound under open licenses, generated voices and art, and open-source
software. A store-ready app has to credit them, and players expect to see who made the game. Today stories
have nowhere to show credits.

## User stories

- As a player, I want a Credits entry on the title screen, so that I can see who made the game.
- As a player, I want credits shown in my language, so that section names read naturally (depends on CE-01).
- As a story author, I want to list people and roles by section (story, art, music, voice, engine), so
  that everyone is credited properly.
- As a story author, I want every third-party asset listed with its source and license, so that the game
  meets its license terms.
- As a story author, I want the open-source software licenses reachable from the credits, so that I don't
  build a separate screen.
- As a story author, I want credits optionally to roll after a chosen ending, so that the true ending feels
  like a finale.
- As an integrating developer, I want the credits screen to follow my skin, so that it matches the game.

## Acceptance criteria

- Given a story with credits, when the player opens Credits from the title screen, then sections, names and
  roles appear in the active language.
- Given an asset credited with a license, then its title, author, source and license name are all visible.
- Given a story without credits, then no Credits entry appears.
- Given an ending marked to roll credits, when the player reaches it, then credits play after the ending
  summary and can be skipped with a tap.

## Out of scope

- ❌ Automatically detecting which assets need credits. Authors list them, and the CE-02 missing-asset
  list helps.
- ❌ Links that open external websites from inside the game.
