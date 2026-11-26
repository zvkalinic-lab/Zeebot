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

- **Player name**: asked on the title screen (saved as `player`).
- **REWARD**: session reward formula (minutes per level, per star, boss bonus, 90%-accuracy bonus, daily cap 60). REWARD.games: Minecraft, Roblox, Mom or Dad. "I'M DONE" on the map shows the report; "CLAIM MY REWARD" saves it and shows a reward ticket to show a parent. No email is sent.
- **SQUAD**: before a level the child picks up to 3 crew cards. Speed: +1 s per 4 points (max +6). Battery: +1 bar at 8, +2 at 20. Strength: chance of a 2-part power hit on bosses (strength/40, max 50%).
- **CARD_SETS**: completing a set gives a one-time bonus of minutes on top of the daily cap.

- **Intro** (INTRO_LINES, Intro, Voice): opening gate with ▶ and SKIP, then a ~20 s story. Zeebot speaks the English lines with a device voice (high pitch) and shows captions. Without such a voice it plays robot beeps. The title screen has ▶ INTRO to replay it.

- **ARCADE** (bonus level): after levels 3, 6 and 9 the NEXT button opens a surprise shooter. Duck Wing follows the pointer/finger on the left; tap enemies before they touch it. Waves: 3, 6, then a 12-ship swarm. Winning gives bonus cards (m1: zipzap, nova, comet; m2: glim, sonar, abyss), or +2 min if already owned. A touch ends the bonus with no card.

## Save data
Stored in the browser's localStorage under `bleep-star-math-v1`: unlocked levels, stars, crew cards, chosen co-pilot, sound setting.
It lives on that one device/browser only.
