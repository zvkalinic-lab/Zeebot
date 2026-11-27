-- Zeebot online: class player list, card gifts and card swaps (Supabase / Postgres)
-- Paste this whole file into Supabase > SQL Editor > New query, then press RUN.
-- It is safe to run again later (it replaces the functions and keeps the data).
--
-- How it is protected:
--  * The tables are closed (row level security on, no policies). The game can only call the zb_ functions below.
--  * A player proves who they are with a secret that only their device knows.
--  * Only nicknames, scores, card ids, weapon ids, robot parts and best times are stored. No names, emails or chat.
--  * zb_new_class can only be run here in the SQL Editor, not from the game.

create table if not exists zb_classes (
  code       text primary key,
  admin_pin  text not null,
  created    timestamptz not null default now()
);

create table if not exists zb_players (
  id         uuid primary key default gen_random_uuid(),
  class_code text not null references zb_classes(code) on delete cascade on update cascade,
  nick       text not null,
  secret     uuid not null default gen_random_uuid(),
  score      int  not null default 0,
  stars      int  not null default 0,
  cards      text[] not null default '{}',
  bests      jsonb not null default '{}',
  created    timestamptz not null default now(),
  updated    timestamptz not null default now()
);
create unique index if not exists zb_players_nick on zb_players (class_code, lower(nick));

create table if not exists zb_trades (
  id         bigint generated always as identity primary key,
  class_code text not null references zb_classes(code) on delete cascade on update cascade,
  from_id    uuid not null references zb_players(id) on delete cascade,
  to_id      uuid not null references zb_players(id) on delete cascade,
  give       text not null,          -- card the sender gives
  want       text not null,          -- card the sender wants back
  status     text not null default 'open' check (status in ('open','accepted','declined','cancelled')),
  from_done  boolean not null default false,  -- sender's device has applied the swap
  to_done    boolean not null default false,  -- receiver's device has applied the swap
  created    timestamptz not null default now(),
  decided    timestamptz
);
create index if not exists zb_trades_to on zb_trades (to_id, status);

alter table zb_players add column if not exists weapons text[] not null default '{}';
alter table zb_players add column if not exists look jsonb not null default '{}';   -- Zeebot's workshop look (part ids)

create table if not exists zb_gifts (
  id         bigint generated always as identity primary key,
  class_code text not null references zb_classes(code) on delete cascade on update cascade,
  from_id    uuid not null references zb_players(id) on delete cascade,
  to_id      uuid not null references zb_players(id) on delete cascade,
  kind       text not null check (kind in ('card','weapon')),
  item       text not null,
  from_done  boolean not null default false,  -- giver's device has removed it
  to_done    boolean not null default false,  -- receiver's device has added it
  created    timestamptz not null default now()
);
create index if not exists zb_gifts_to on zb_gifts (to_id);
create index if not exists zb_gifts_from on zb_gifts (from_id);
create index if not exists zb_trades_from on zb_trades (from_id, status);

alter table zb_classes enable row level security;
alter table zb_players enable row level security;
alter table zb_trades  enable row level security;
alter table zb_gifts   enable row level security;
revoke all on zb_classes, zb_players, zb_trades, zb_gifts from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on zb_classes, zb_players, zb_trades, zb_gifts from anon, authenticated';
  end if;
end $$;

-- ---------- helpers ----------
create or replace function zb_clean_nick(p_nick text) returns text
language plpgsql immutable as $$
declare n text := regexp_replace(btrim(coalesce(p_nick,'')), '\s+', ' ', 'g');
begin
  if char_length(n) < 2 or char_length(n) > 14 or n !~ '^[[:alnum:] _.-]+$' then
    raise exception 'BAD_NICK';
  end if;
  return n;
end $$;

create or replace function zb_me(p_id uuid, p_secret uuid) returns zb_players
language plpgsql security definer set search_path = public as $$
declare me zb_players;
begin
  select * into me from zb_players where id = p_id and secret = p_secret;
  if not found then raise exception 'NO_PLAYER'; end if;
  return me;
end $$;

-- ---------- admin (SQL Editor only) ----------
create or replace function zb_new_class(p_code text, p_pin text) returns text
language plpgsql security definer set search_path = public as $$
declare c text := upper(btrim(p_code));
begin
  if c !~ '^[A-Z0-9-]{4,20}$' then raise exception 'Class code: 4-20 letters, digits or -'; end if;
  if char_length(coalesce(p_pin,'')) < 4 then raise exception 'PIN: at least 4 characters'; end if;
  insert into zb_classes(code, admin_pin) values (c, p_pin)
    on conflict (code) do update set admin_pin = excluded.admin_pin;
  return 'Class ' || c || ' is ready';
end $$;

-- ---------- game functions ----------
-- Join a class with a nickname. Returns the player's id and secret (kept on the device).
create or replace function zb_join(p_code text, p_nick text) returns json
language plpgsql security definer set search_path = public as $$
declare c text := upper(btrim(coalesce(p_code,''))); n text := zb_clean_nick(p_nick); p zb_players;
begin
  if not exists (select 1 from zb_classes where code = c) then raise exception 'NO_CLASS'; end if;
  if (select count(*) from zb_players where class_code = c) >= 80 then raise exception 'CLASS_FULL'; end if;
  if exists (select 1 from zb_players where class_code = c and lower(nick) = lower(n)) then raise exception 'NICK_TAKEN'; end if;
  insert into zb_players(class_code, nick) values (c, n) returning * into p;
  return json_build_object('id', p.id, 'secret', p.secret, 'nick', p.nick, 'code', p.class_code);
end $$;

-- Upload progress. p_applied = accepted trades this device has already swapped.
-- Returns accepted trades the device still has to swap, plus open offers.
drop function if exists zb_sync(uuid, uuid, int, int, text[], jsonb, bigint[]);
drop function if exists zb_sync(uuid, uuid, int, int, text[], jsonb, bigint[], text[], bigint[]);
create or replace function zb_sync(p_id uuid, p_secret uuid, p_score int, p_stars int, p_cards text[], p_bests jsonb,
  p_applied bigint[] default '{}', p_weapons text[] default '{}', p_gifted bigint[] default '{}', p_look jsonb default '{}')
returns json
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret); t record; v_cards text[]; v_weap text[]; todo json; gtodo json;
begin
  if coalesce(array_length(p_cards,1),0) > 400 or coalesce(array_length(p_weapons,1),0) > 60 or octet_length(coalesce(p_bests,'{}')::text) > 30000
     or octet_length(coalesce(p_look,'{}')::text) > 600 then raise exception 'TOO_BIG'; end if;
  v_cards := (select coalesce(array_agg(distinct x), '{}') from unnest(coalesce(p_cards,'{}')) x where char_length(x) between 1 and 24);
  v_weap  := (select coalesce(array_agg(distinct x), '{}') from unnest(coalesce(p_weapons,'{}')) x where char_length(x) between 1 and 24);
  -- mark swaps and gifts the device reports as done
  update zb_trades set from_done = true where status = 'accepted' and from_id = me.id and id = any(coalesce(p_applied,'{}'));
  update zb_trades set to_done   = true where status = 'accepted' and to_id   = me.id and id = any(coalesce(p_applied,'{}'));
  update zb_gifts  set from_done = true where from_id = me.id and id = any(coalesce(p_gifted,'{}'));
  update zb_gifts  set to_done   = true where to_id   = me.id and id = any(coalesce(p_gifted,'{}'));
  -- ones the device has not done yet: apply them to the uploaded lists too, so nothing is lost
  for t in select * from zb_trades where status = 'accepted'
        and ((from_id = me.id and not from_done) or (to_id = me.id and not to_done)) loop
    if t.from_id = me.id then v_cards := array_remove(v_cards, t.give); if not t.want = any(v_cards) then v_cards := v_cards || t.want; end if;
    else v_cards := array_remove(v_cards, t.want); if not t.give = any(v_cards) then v_cards := v_cards || t.give; end if; end if;
  end loop;
  for t in select * from zb_gifts where (from_id = me.id and not from_done) or (to_id = me.id and not to_done) loop
    if t.kind = 'card' then
      if t.from_id = me.id then v_cards := array_remove(v_cards, t.item); elsif not t.item = any(v_cards) then v_cards := v_cards || t.item; end if;
    else
      if t.from_id = me.id then v_weap := array_remove(v_weap, t.item); elsif not t.item = any(v_weap) then v_weap := v_weap || t.item; end if;
    end if;
  end loop;
  update zb_players set score = greatest(0, coalesce(p_score,0)), stars = greatest(0, coalesce(p_stars,0)), cards = v_cards, weapons = v_weap,
    look = case when jsonb_typeof(p_look) = 'object' then p_look else '{}' end, bests = coalesce(p_bests,'{}'), updated = now() where id = me.id;
  select coalesce(json_agg(json_build_object('id', x.id, 'gave', case when x.from_id = me.id then x.give else x.want end,
      'got', case when x.from_id = me.id then x.want else x.give end) order by x.id), '[]')
    into todo from zb_trades x where x.status = 'accepted'
      and ((x.from_id = me.id and not x.from_done) or (x.to_id = me.id and not x.to_done));
  select coalesce(json_agg(json_build_object('id', g.id, 'dir', case when g.from_id = me.id then 'out' else 'in' end,
      'kind', g.kind, 'item', g.item, 'other', o.nick) order by g.id), '[]')
    into gtodo from zb_gifts g join zb_players o on o.id = case when g.from_id = me.id then g.to_id else g.from_id end
      where (g.from_id = me.id and not g.from_done) or (g.to_id = me.id and not g.to_done);
  return json_build_object('nick', me.nick, 'code', me.class_code, 'swaps', todo, 'trades', zb_trades_of(me.id),
    'gifts', gtodo, 'giftLog', zb_gifts_of(me.id));
end $$;

create or replace function zb_trades_of(p_me uuid) returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('id', t.id, 'dir', case when t.from_id = p_me then 'out' else 'in' end,
    'other', case when t.from_id = p_me then pt.nick else pf.nick end,
    'otherId', case when t.from_id = p_me then t.to_id else t.from_id end,
    'give', t.give, 'want', t.want, 'status', t.status, 'at', t.created) order by t.id desc), '[]')
  from zb_trades t join zb_players pf on pf.id = t.from_id join zb_players pt on pt.id = t.to_id
  where (t.from_id = p_me or t.to_id = p_me)
    and (t.status = 'open' or t.decided > now() - interval '3 days');
$$;
revoke all on function zb_trades_of(uuid) from public;

create or replace function zb_gifts_of(p_me uuid) returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(q.j order by q.id desc), '[]') from (
    select g.id, json_build_object('id', g.id, 'dir', case when g.from_id = p_me then 'out' else 'in' end,
      'other', o.nick, 'kind', g.kind, 'item', g.item, 'at', g.created) as j
    from zb_gifts g join zb_players o on o.id = case when g.from_id = p_me then g.to_id else g.from_id end
    where (g.from_id = p_me or g.to_id = p_me) and g.created > now() - interval '30 days'
    order by g.id desc limit 30) q;
$$;
revoke all on function zb_gifts_of(uuid) from public;

-- Give one of my cards or weapons to a classmate. It moves at once; both devices catch up on their next sync.
create or replace function zb_gift(p_id uuid, p_secret uuid, p_to uuid, p_kind text, p_item text) returns json
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret); other zb_players; g zb_gifts;
begin
  select * into other from zb_players where id = p_to and class_code = me.class_code for update;
  if not found or other.id = me.id then raise exception 'NO_PLAYER_TO'; end if;
  perform 1 from zb_players where id = me.id for update;
  select * into me from zb_players where id = me.id;
  if (select count(*) from zb_gifts where from_id = me.id and created > now() - interval '1 hour') >= 20 then raise exception 'TOO_MANY_GIFTS'; end if;
  if p_kind = 'card' then
    if not p_item = any(me.cards) or p_item = any(other.cards) then raise exception 'BAD_GIFT'; end if;
    update zb_players set cards = array_remove(cards, p_item) where id = me.id;
    update zb_players set cards = array_append(cards, p_item) where id = other.id;
    update zb_trades set status = 'cancelled', decided = now() where status = 'open' and (
         (from_id = me.id and give = p_item) or (to_id = me.id and want = p_item)
      or (to_id = other.id and give = p_item) or (from_id = other.id and want = p_item));
  elsif p_kind = 'weapon' then
    if p_item = 'blaster' or not p_item = any(me.weapons) or p_item = any(other.weapons) then raise exception 'BAD_GIFT'; end if;
    update zb_players set weapons = array_remove(weapons, p_item) where id = me.id;
    update zb_players set weapons = array_append(weapons, p_item) where id = other.id;
  else raise exception 'BAD_GIFT'; end if;
  insert into zb_gifts(class_code, from_id, to_id, kind, item) values (me.class_code, me.id, other.id, p_kind, p_item) returning * into g;
  return json_build_object('gift', json_build_object('id', g.id, 'dir', 'out', 'kind', g.kind, 'item', g.item, 'other', other.nick),
    'giftLog', zb_gifts_of(me.id));
end $$;

-- The class board: every player (score, stars, cards) and the fastest time on each level.
create or replace function zb_board(p_code text) returns json
language plpgsql stable security definer set search_path = public as $$
declare c text := upper(btrim(coalesce(p_code,'')));
begin
  if not exists (select 1 from zb_classes where code = c) then raise exception 'NO_CLASS'; end if;
  return json_build_object('code', c,
    'players', (select coalesce(json_agg(json_build_object('id', id, 'nick', nick, 'score', score, 'stars', stars, 'cards', cards, 'weapons', weapons, 'look', look)
                 order by lower(nick)), '[]') from zb_players where class_code = c),
    'bests', (select coalesce(json_object_agg(k, json_build_object('nick', nick, 'secs', secs)), '{}') from (
                 select distinct on (b.key) b.key as k, p.nick, (b.value)::text::numeric as secs
                 from zb_players p, jsonb_each(p.bests) b
                 where p.class_code = c and jsonb_typeof(b.value) = 'number' and (b.value)::text::numeric > 0
                 order by b.key, (b.value)::text::numeric, p.updated) q));
end $$;

-- Offer a swap: my card p_give for their card p_want.
create or replace function zb_offer(p_id uuid, p_secret uuid, p_to uuid, p_give text, p_want text) returns json
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret); other zb_players;
begin
  select * into other from zb_players where id = p_to and class_code = me.class_code;
  if not found or other.id = me.id then raise exception 'NO_PLAYER_TO'; end if;
  if not p_give = any(me.cards) or p_want = any(me.cards) then raise exception 'BAD_CARDS'; end if;
  if not p_want = any(other.cards) or p_give = any(other.cards) then raise exception 'BAD_CARDS'; end if;
  if (select count(*) from zb_trades where from_id = me.id and status = 'open') >= 10 then raise exception 'TOO_MANY'; end if;
  if exists (select 1 from zb_trades where status = 'open' and from_id = me.id and to_id = other.id and give = p_give and want = p_want) then
    raise exception 'ALREADY'; end if;
  insert into zb_trades(class_code, from_id, to_id, give, want) values (me.class_code, me.id, other.id, p_give, p_want);
  return zb_trades_of(me.id);
end $$;

-- Accept or decline an offer that was sent to me. On accept both card lists are swapped at once.
create or replace function zb_answer(p_id uuid, p_secret uuid, p_trade bigint, p_accept boolean) returns json
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret); t zb_trades; f zb_players;
begin
  select * into t from zb_trades where id = p_trade and to_id = me.id and status = 'open' for update;
  if not found then raise exception 'NO_TRADE'; end if;
  if not p_accept then
    update zb_trades set status = 'declined', decided = now() where id = t.id;
    return json_build_object('ok', true, 'trades', zb_trades_of(me.id));
  end if;
  select * into f from zb_players where id = t.from_id for update;
  perform 1 from zb_players where id = me.id for update;
  select * into me from zb_players where id = me.id;
  if not t.give = any(f.cards) or t.want = any(f.cards) or not t.want = any(me.cards) or t.give = any(me.cards) then
    update zb_trades set status = 'cancelled', decided = now() where id = t.id;
    raise exception 'GONE';
  end if;
  update zb_players set cards = array_append(array_remove(cards, t.give), t.want) where id = f.id;
  update zb_players set cards = array_append(array_remove(cards, t.want), t.give) where id = me.id;
  update zb_trades set status = 'accepted', decided = now() where id = t.id;
  -- other open offers that used one of these cards can no longer work
  update zb_trades set status = 'cancelled', decided = now() where status = 'open' and id <> t.id and (
       (from_id = f.id  and give = t.give) or (to_id = f.id  and want = t.give)
    or (from_id = me.id and give = t.want) or (to_id = me.id and want = t.want)
    or (from_id = f.id  and want = t.want) or (from_id = me.id and want = t.give)
    or (to_id = f.id    and give = t.want) or (to_id = me.id   and give = t.give));
  return json_build_object('ok', true, 'swap', json_build_object('id', t.id, 'gave', t.want, 'got', t.give), 'trades', zb_trades_of(me.id));
end $$;

-- The sender takes back an open offer.
create or replace function zb_cancel(p_id uuid, p_secret uuid, p_trade bigint) returns json
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret);
begin
  update zb_trades set status = 'cancelled', decided = now() where id = p_trade and from_id = me.id and status = 'open';
  return zb_trades_of(me.id);
end $$;

-- A player leaves the class (their offers go too).
create or replace function zb_leave(p_id uuid, p_secret uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare me zb_players := zb_me(p_id, p_secret);
begin
  delete from zb_players where id = me.id; return true;
end $$;

-- ---------- teacher / parent tools (need the class PIN) ----------
create or replace function zb_admin_ok(p_code text, p_pin text) returns text
language plpgsql security definer set search_path = public as $$
declare c text := upper(btrim(coalesce(p_code,'')));
begin
  perform pg_sleep(0.4); -- slows down PIN guessing
  if not exists (select 1 from zb_classes where code = c and admin_pin = p_pin) then raise exception 'BAD_PIN'; end if;
  return c;
end $$;
revoke all on function zb_admin_ok(text, text) from public;

create or replace function zb_admin_list(p_code text, p_pin text) returns json
language plpgsql security definer set search_path = public as $$
declare c text := zb_admin_ok(p_code, p_pin);
begin
  return (select coalesce(json_agg(json_build_object('id', id, 'nick', nick, 'score', score, 'cards', cardinality(cards), 'updated', updated)
          order by lower(nick)), '[]') from zb_players where class_code = c);
end $$;

create or replace function zb_admin_rename(p_code text, p_pin text, p_player uuid, p_nick text) returns json
language plpgsql security definer set search_path = public as $$
declare c text := zb_admin_ok(p_code, p_pin); n text := zb_clean_nick(p_nick);
begin
  if exists (select 1 from zb_players where class_code = c and lower(nick) = lower(n) and id <> p_player) then raise exception 'NICK_TAKEN'; end if;
  update zb_players set nick = n where id = p_player and class_code = c;
  return zb_admin_list(p_code, p_pin);
end $$;

create or replace function zb_admin_delete(p_code text, p_pin text, p_player uuid) returns json
language plpgsql security definer set search_path = public as $$
declare c text := zb_admin_ok(p_code, p_pin);
begin
  delete from zb_players where id = p_player and class_code = c;
  return zb_admin_list(p_code, p_pin);
end $$;

-- Only the game functions may be called from the internet; everything else stays in the SQL Editor.
revoke all on function zb_new_class(text, text) from public;
revoke all on function zb_me(uuid, uuid) from public;
revoke all on function zb_clean_nick(text) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on function zb_new_class(text, text), zb_me(uuid, uuid), zb_clean_nick(text), zb_trades_of(uuid), zb_gifts_of(uuid), zb_admin_ok(text, text) from anon, authenticated';
    execute 'grant execute on function zb_join(text, text), zb_sync(uuid, uuid, int, int, text[], jsonb, bigint[], text[], bigint[], jsonb), zb_board(text), zb_gift(uuid, uuid, uuid, text, text),
      zb_offer(uuid, uuid, uuid, text, text), zb_answer(uuid, uuid, bigint, boolean), zb_cancel(uuid, uuid, bigint), zb_leave(uuid, uuid),
      zb_admin_list(text, text), zb_admin_rename(text, text, uuid, text), zb_admin_delete(text, text, uuid) to anon';
  end if;
end $$;
notify pgrst, 'reload schema';
