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
- **UNLOCK_ALL**: `true` opens every level for testing; set `false` for normal one-by-one unlocking.
- **Boss levels** (`boss:true`): the level is a boss fight (Boss object). Right answer burns one of 8 boss parts, a miss repairs one; all parts burnt = win.
- **TIME_LIMIT**: seconds per problem (8). Running out counts as a miss.
- **SHIP_ART**: add new ship designs (SVG drawn facing right). Wrap pieces that can be shot off in `<g class="spart">`.

The map screen currently shows `MISSIONS[0]`; a mission picker is the next step when Mission 2 exists.

## Save data
Stored in the browser's localStorage under `bleep-star-math-v1`: unlocked levels, stars, crew cards, chosen co-pilot, sound setting.
It lives on that one device/browser only.
