# Zeebot's Star Math

Single-file browser game (`index.html`). No build step; open it in a browser or publish it as an artifact.

## How to extend
All content lives at the top of the `<script>` in `index.html`:

- **MISSIONS**: add a mission object `{ id, name, title, intro, levels:[...] }`. Each level is
  `{ name, op:'mul'|'div'|'mix', tables:[...], count, card, boss? }`.
  `tables` are the times tables used (other factor is always 1–10). For `div`, the table is the divisor.
- **CREW**: collectible cards. `kind` picks the art template (`box`, `orb`, `dome`, `tall`, `pilot`, `crystal`),
  `colors` = [main, accent, eyes/skin], `stats` = strength / battery / speed (1–10).
  Link a card to a level with that level's `card` field.
- **OPEN_LEVELS**: how many levels are open from the start (2). Others unlock by clearing the previous level; set to 10 to open all for testing.
- **Boss levels** (`boss:true`): the level is a boss fight (Boss object). Right answer burns one of 8 boss parts, a miss repairs one; all parts burnt = win.
- **TIME_LIMIT**: seconds per problem (8). Running out counts as a miss. A level can override with `time:` (Mission 2: 14s levels 1–6, 18s levels 7–10).
- **RAIDS** (missions with `raids:true`): enemies from the level's `enemies` list sometimes fly in mid-problem (RAID_CHANCE). Tap to stop them; otherwise crab steals 4s, squid swaps +/−, shark swaps digits, spike explodes (new problem, −1 power).
- **SHIP_ART**: add new ship designs (SVG drawn facing right). Wrap pieces that can be shot off in `<g class="spart">`.

The map screen currently shows `MISSIONS[0]`; a mission picker is the next step when Mission 2 exists.

## Save data
Stored in the browser's localStorage under `bleep-star-math-v1`: unlocked levels, stars, crew cards, chosen co-pilot, sound setting.
It lives on that one device/browser only.
