# Zeebot online: My Class

Class player list, card and weapon gifts, and card swaps for Zeebot's Star Math, on a free Supabase project.

1. Create a Supabase project (free plan).
2. SQL Editor > New query: paste `zeebot-online.sql`, press Run.
3. New query: `select zb_new_class('3B-ZEE', 'your-pin');` (class code: 4–20 letters, digits or `-`; the PIN opens the TEACHER screen in the game).
4. Put the Project URL and the publishable (anon) key into `CLOUD` in the game. Both are meant to be public: the tables are closed and the game can only call the `zb_` functions.

More classes: run step 3 again with another code. Change a PIN: run it again with the same code and a new PIN.

Stored per player: nickname, score, total stars, card ids, weapon ids, robot look (workshop part ids), best time per level. No real names, emails or chat.
