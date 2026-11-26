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

- **Studio opening** (Studio, STUDIO_FONT): a black screen with ▶ / SKIP, then "ZEE PRODUCTIONS" assembles from robot-part plates (with a little catamaran in the Z), a metal smash and the robot voice "Zee Productions… presenting", then a giggling ring of all the robots that slows, spins fast and opens the Zeebot intro. SKIP goes straight to the title. ▶ INTRO on the title replays both.

- **Mission 3 "Sunny Shore"** (theme 'beach', max:1000): beach background (drawBeach), smiling sun top-left, red starfish, sweat drops (.sweat, visible only on .beach), water jets instead of lasers (fireBolt adds .water and a splash on the beach). Helpers: turtle (shield), medic (+1 bar), whale (+8 s). Raiders: hornet (−4 s), magnet (swap + and −), drill (swap digits), toad (snatches the problem, −1 bar). Boss: the robot crab Clawtron (bossKind 'crabboss'). genAddSub1000 handles tiers 1–5 up to 1000.

## Save data
Stored in the browser's localStorage under `bleep-star-math-v1`: unlocked levels, stars, crew cards, chosen co-pilot, sound setting.
It lives on that one device/browser only.

## Mission 4 "Bat Cave Echoes"
- Theme `cave` (canvas `drawCave`, DOM `.cave-decor` with hanging bats whose eyes blink, a flying bat and glowing crystals).
- `big:true` missions use `genBig(op, tier)`: multi-digit × one digit (tiers 1–5) and ÷ one digit with remainders (tiers 3–4).
- Answers are string keys: `ansKey(p)` gives `"39 r 2"` when there is a remainder. Buttons with long keys get `.ans.long`.
- `opProblem(op,a,b,ref)` rebuilds a problem for raids (sign swap × ↔ ÷, digit swap).
- Helpers teapot (STEAM dims two wrong answers), balloon (+10 s), snail (Timer.rate = .5 for one problem).
- Raiders bat (time), echo (digits), snore (sign), stalag (boom). Boss `mole` "Burrowbot".

## Measure missions and word problems (Missions 5–9)
- A level with `gen:[...]` uses the unit engine instead of tables. Each spec is `fn:args`, e.g. `down:m:cm:9`, `compUp:km:m:5:5`, `arith:m:cm:5`, `clockAdd:55`. Functions live in `G` (down, up, compDown, compUp, arith, clockAdd, clockDiff, plus story generators).
- Problems with `u:true` carry `ta`, `sy`, `tb`, `key` (the answer text) and premade `choices`. `story` problems show a text panel instead of number crates.
- Themes in `THEMES` get the `.xt` class (and `.bright` for light skies); a canvas painter goes in `THEME_DRAW[theme]` and decor in `.theme-decor.td-<theme>`.
- New helpers borrow an old power through `HELPER_ALIAS` (e.g. eagle → owl). Raid act `shuffle` mixes up the answer buttons.
- Mission 5 "Snowy Summit": lengths, snow theme, helpers eagle/sled/yeti, raiders brrbird/goat/snowbot, boss `frost`.
- Mission 6 "Sailing Seas": mass (g, dag, kg, t), sail theme, helpers gull/buoy/dolphin, raiders parrot/octo/mine, boss `ironclad`.
- Mission 7 "City Rush": liquids (l, dl, cl, ml), city theme, helpers tilly/taxi/tow, raiders honk/cone/pothole, boss `truck`.
- Mission 8 "Express Time": time (h, min, s, clock times, durations), rail theme, helpers conductor/stclock/signal, raiders smoke/switch/coal, boss `loco`.
- Mission 9 "Space Station Stories": word problems from `STORY_T[lang]` templates (generators stAdd, stSub, stMul, stDiv, stRem, stUnit, stTime, stTwo, stMix), station theme, helpers astro/drone/sat, raiders ufo/alien/meteor, boss `core`.

## Languages
After the intro (or SKIP) a picker offers Croatian, English, Italian, German, Spanish, French, Greek, Serbian and Slovenian; the 🌐 button on the name screen opens it again. The choice is saved as `Save.d.lang`.
- The game code stays in English. `I18N` watches the page and swaps each text node for its translation: exact phrases are in `I18N_DATA.exact` (one row: en, hr, it, de, es, fr, el, sr, sl), phrases with numbers or names are regex patterns in `I18N_DATA.pat`, and raid messages are built per raid type from `I18N_DATA.raid`.
- Word problems (Mission 9) have their own templates per language in `STORY_T`. Croatian and Serbian templates use `slN(n, one, few, many)` so nouns agree with the number (1 brod, 3 broda, 5 brodova).
- The voice reads the translated line with a speech voice for that language if the device has one (Serbian falls back to Croatian/Bosnian, Slovenian to Croatian); otherwise robot beeps.
- Hints are numbers and symbols only, so they work in every language. Remainders show as "ost." in hr/sr/sl.
- New text: add a row to the exact list (or a pattern) when you add a new mission. Card names, card descriptions, level names and the fleet lines are not translated.

## Bonus levels
Every bonus level (after levels 3, 6 and 9) lasts 4 minutes (`ARCADE.duration`) and Duck Wing has 3 lives (`ARCADE.lives`). A new, slightly faster wave starts every 30 seconds (`ARCADE.waveLen`). A bonk costs a life and gives a short blink with no damage. Reaching the end wins the bonus card; lives left give stars and extra minutes (3 lives: +2 min, 2 lives: +1 min, 1 life: card only). Losing all 3 lives ends the level with no card.

## Pilots and saved minutes
- The name screen lists every pilot on this device; tap one to continue, or type a new name for a new pilot (typing an existing name opens that pilot). Each pilot has a separate save (levels, cards, minutes). The list and the language are in `zeebot-profiles-v1`; the first pilot keeps the old save key, so old progress carries over.
- CLAIM MY REWARD (after I'M DONE) adds the minutes to `Save.d.bank`, so they add up across days. The 👤 button on the map shows the saved total and a short log.
- From that screen, RESET MINUTES TO 0 (with a YES/NO check) sets only the saved minutes back to 0; levels, stars and cards stay. SWITCH PILOT goes back to the name screen.

## Points and weapons (bonus levels)
- Every hit scores the weapon's power in ⭐ points. Points are saved per pilot (`Save.d.pts`) and carry over between bonus levels.
- From wave 2 some enemies are tough (glow, health bar) and need 2 hits; from wave 3 some need 3.
- After each bonus level the weapon shop opens (also from the 👤 screen on the map): the starter Duck Blaster, 3 cheaper weapons and 3 stronger ones. Edit `WEAPONS` for names, power (`dmg`), time between shots (`cd`, ms) and price. Bought weapons stay owned (`Save.d.weapons`); the equipped one (`Save.d.weapon`) is used in every bonus level after that.

## Display notes
- The display font (Bungee) draws ÷ almost like +, so the operator ball uses the body font and boss questions wrap ÷ in `<span class="dv">` (`setQ`).
- Answer buttons pick their size class from the translated text, so "292 ost. 2" still fits five buttons on a small phone.
