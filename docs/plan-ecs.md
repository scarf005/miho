# ECS migration plan

Base: main at 6e2f8c1. The migration changes no rule, text, balance or name. `SaveGame.VERSION` stays 79.

## What this removes

The rules already live in static modules, and `World.act` already runs them in a fixed order. These faults remain:

1. A creature and a shot are two unrelated classes, so a rule about "whatever enters a tile" exists once per class.
2. `world.gd` (998 lines) holds flight, walking, noise, harm and the round as well as the state.
3. Each new tile table goes into three lists: the `World` field, `World.clone` and `Storeys.FIELDS`.
4. Actor holds 42 fields of six unrelated groups.

Rules written once per path, and where each one is now:

| Rule | Written in on the base | Now |
| --- | --- | --- |
| A plate goes off | `Traps.step`, `Traps.fly` | one rule: `Traps.enter` |
| A wisp rides its host | `World.move`, `Cheat._carry`, `Storeys.carry` | one rule: `Walk.riders` |
| A creature dies and gives its tail | `World.hurt`, `Fall._gone`, `Bunsin.cap` | reward only: `Harm.reward`. Three death paths remain. Their event keys and orders differ, and the oracle hashes them. |
| Fire on the ground harms, unless absorbed | `Terrain.burn`, `Compounds.tick`, `Veil` | one rule: `Harm.fire` |
| A shot starts from its caster | `World._spawn`, `Spray.cast`, `Guise` | one rule: `Shot.of` |
| A spell reaches tiles (react, relight, wash) | `Terrain.touch`, `Spray.cast`, `Terrain.smash` | not merged. The tile set, the sight check, the wash coverage and the order differ. A merge changes play. |

## Target

### Entities

`Entity` is a new base class with `id`, `faction` and `pos`. `Actor` and `Shot` extend it. `World.new_id` already gives both one id space. A rule about anything on a tile takes an `Entity`.

`w.actors` and `w.shots` stay as ordered lists. They are the only queries. Their order is the order of play, so it does not change: Miho is `actors[0]`, new rows go last, `_prune` keeps the order.

### Components

| Component | Fields | Storage |
| --- | --- | --- |
| Place, Side | `pos`, `faction` | inline on `Entity` |
| Body | `kind`, `hp`, `max_hp`, `rank` | inline on `Actor` |
| Flight | every other `Shot` field | inline on `Shot` |
| `Ailments` | `rooted`, `stunned`, `blind`, `wet`, `alight`, `frozen` | slot `a.ailments` |
| `Magic` | `cooldown`, `intent`, `casts`, `mana`, `regrow`, `imprint` | slot `a.magic` |
| `Brain` | `acted`, `alert`, `target`, `lost`, `wary`, `marked`, `sees_me`, `guard`, `drum`, `home`, `post` | slot `a.brain` |
| `Ties` | `rival`, `grudge`, `rival_at`, `leader` | slot `a.ties` |
| `Buffs` | `prey`, `form`, `guise`, `beside`, `talon`, `cloak`, `flame`, `raise` | slot `a.buffs` |

A component stays inline when `actor_at` and every list scan read it, or when it is the only thing its class adds. All others are slots. Each slot class holds data and one `copy()`. It has no rule.

### Tile state

Tile state does not become entities. Each table is already a sparse component store with the tile as its key: `traps`, `burning`, `wild`, `gas`, `vents`, `wet`, `hot`, `secrets`, `seals`, `jars`, `strong`, `bodies`. `tiles` and `scent` are dense columns. These stay on `World` with their names:

- Dictionary insertion order is the processing order that saved runs depend on.
- A gas tile as an object adds one allocation per tile per clone.
- `w.burning` has 26 uses in core and 113 in tests. Moving it gives no rule.

One list, `World.STOREY`, replaces the three lists. `World.clone` and `Storeys` read it.

### Systems

Each system is a static module over `World`. `World` keeps the state, the queries (`tile`, `actor_at`, `sees` and so on), `emit`, `set_tile`, `_changed`, `clone` and `act`.

| New module | From `world.gd` |
| --- | --- |
| `Round` | `act` body, `_regrow`, `_end_round`, `_prune`, `_ascend` |
| `Flight` | `_shots_phase`, `_spawn`, `_step`, `_fly`, `_land`, `_burst`, `_effects`, `_strike`, `rides` |
| `Walk` | `move`, `arrive` |
| `Hearing` | `noise` |
| `Harm` | `hurt`, `_claw`, `claw_harm`, `caught_unawares` |
| `Cast` | `cast` |
| `Mind`, `Terrain` | `hunt_from` to `Mind`, `ignite` to `Terrain` |

`World.act` stays as a one-line entry point, because every caller and test uses it.

### Fixed system order

`Round.run` lists the order as plain statements, the same order as `World.act` on the base:

1. `Cheat.handled`, which ends the call when it takes the action
2. `Round._regrow`, then a snapshot of `burning.keys()`, then the lapse of Miho's stun
3. Miho's action: `Harm`, `Terrain`, `Walk`, `Guise.dispel` or `Cast`. The stairs or the elixir end the round here.
4. `Flight.phase`
5. `Mind.heaven_phase`
6. `Terrain.burn`, with the snapshot
7. `Compounds.tick`
8. `Gas.tick`
9. `Status.tick`
10. `Vault.tick`
11. `EventRooms.tick`
12. `Statues.tick`
13. `Guise.tick`
14. `Lure.tick`
15. `Round.end`: `Drums.dry`, flares, creature timers, `pungent`, `Jars.arrive`, shot life, `_prune`, `round_no`, `Curse.tick`
16. `World.sense`: `Sight.sensed`, `Traps.find`, `Notice.remember`, `Cheat.reveal`
17. `Raise.tick`

## Storage choice

No library is used. Target storage is typed slots on RefCounted rows in ordered lists, with no registry, query engine or scheduler to replace.

| Library | Entity | Query order | Clone | Web | Result |
| --- | --- | --- | --- | --- | --- |
| [GECS](https://github.com/csprance/gecs) (CC0) | `Node`, components `Resource` | archetype order, swap-remove | no API; Nodes per clone | not verified | rejected: order, clone |
| [godot-ecs](https://github.com/godothub/godot-ecs) (MIT) | RefCounted over int | cache order, swap-back-pop | no API | not verified | rejected: order, clone |
| [Godex](https://github.com/GodotECS/godex) (MIT) | C++ module | not read | not read | needs a custom engine; pinned to one Godot commit; last push 2023-09-18 | rejected: engine, web |
| bevy_ecs through godot-rust | Rust | not verified | not verified | no Emscripten evidence | rejected: each of the many GDScript field reads would cross the extension |

Swap-removal changes who acts first, so these libraries fail the replay rule. Neither GDScript addon has a world copy, so the game would still write its own. Clone cost of the addons was not measured.

Costs from `just bench-storage`, on a machine under load:

| Shape | Read | Clone of 40 creatures |
| --- | --- | --- |
| Flat field, as now | 0.041 us | 559 us |
| Slot: `a.status.rooted` | 0.104 us | 699 us (7 slots, default objects built and then replaced) |
| Column: `column[slot]` | 0.042 us | 4 us (42 int columns) |
| Getter over a column, so `a.rooted` still works | 0.110 us | not measured |
| Table: `table[id].rooted` | 0.132 us | not measured |

Columns are rejected although they clone fastest. Detached rows are normal here: `Term` keeps clones, `Storeys` keeps clones, and 96 test files call `Actor.new()`. Columns also need ints in place of `a` at every use. A getter over a column costs as much as a slot and keeps the column's detached-row fault.

Slots add 0.063 us per read. `Place`, `Side` and `Body` stay inline for that reason: they have the hottest reads and about 2,100 uses in tests. `Actor.clone` builds no default slots and drops `get`/`set`, which pays for the extra allocations. Package C1 measures this first.

## What keeps working

`World.clone` copies each `STOREY` table, each row and each slot. A kept storey is still shared, as now. `known_clone` filters as now. A forecast and a preview run on clones, so the oracle replays each action on a clone and compares.

A save holds the seed and the actions, and no entity data, so no format changes. `SaveGame.VERSION` stays 79.

`Observation` and `Forecast` read fields from a `known_clone`. A field move updates their reads. The oracle hashes `Observation.text`.

The web build gets no new native code or engine change. All new code is GDScript.

## Oracle

`just oracle` runs `tools/oracle.gd` and compares its output with `tools/oracle.expected`. It exits 1 on any difference. `just oracle-record` writes both the saves and the expected file, and only a change of rules on purpose may run it.

Saves: `tools/oracle/*.cfg`, written by a bot with seeded dice on the base. These are real `SaveGame` files of version 79, read with `SaveGame.load_from`. The set uses `cheat` actions to reach every card and storey, plus plain walks up the stairs, falls and returns to kept storeys, so a replay has all it needs inside the save.

Each save replays through `SaveGame.step`. For each action the hash takes:

- the events, with each key in its order and a `Spell` as its cards
- the whole world, with tables in their iteration order: tiles, every `STOREY` table, every row and field, `rng.state`
- the log text that `Messages` makes
- `Sfx.sound_of` of each event
- at intervals: `Forecast.of` for the action, `Observation.text`, and `Info.at` on sample tiles

A clone check runs at intervals: the action on `clone()` must give the same hash as on the world. A failed step or a clone mismatch exits 1.

The hash reads fields through one function in `tools/oracle.gd`. A field move changes that function only, and it must not change the output.

## Order of work

Each commit leaves the game playable and the suite green. A merge needs identical oracle hashes. A hash change is a defect until the cause is found.

| Package | Scope | Depends on |
| --- | --- | --- |
| O | `tools/oracle.gd`, `tools/oracle/`, `tools/oracle.expected`, `justfile` | |
| A1 | `World.STOREY`: `world.gd` clone, `storeys.gd` | O |
| A2 | `Flight`, `Cast`: `world.gd`, `flight.gd`, `cast.gd`, call sites | A1 |
| A3 | `Round`, `Walk`, `Hearing`, `Harm`, moves to `Mind` and `Terrain`: `world.gd`, new modules, call sites | A2 |
| B1 | `Entity`, `Traps.enter`, one rider rule, `Shot.of`: `entity.gd`, `actor.gd`, `shot.gd`, `traps.gd`, `walk.gd`, `flight.gd`, `cheat.gd`, `storeys.gd`, `guise.gd` | A3 |
| B2 | One death path: `harm.gd`, `fall.gd`, `bunsin.gd` | A3 |
| B3 | Ground harm and spell reach: `terrain.gd`, `compounds.gd`, `veil.gd`, `spray.gd` | B1 |
| C1 | `Ailments` | B3, B2 |
| C2 | `Magic` | C1 |
| C3 | `Ties` | C2 |
| C4 | `Buffs` | C3 |
| C5 | `Brain` | C4 |

B1 and B2 run at the same time. All other packages run one at a time. The C packages touch the same test files, so they are not file-disjoint and they do not run together. A unified rule keeps each path's event keys and order, even where the paths differ.

Stop rule for speed: compare the lowest of three runs of `50 x act(wait)`, `8 step forecasts` and `replay 300 rounds`. Past 10% over the base, find the cause before the merge. If slots cause it, stop the C packages and report the number.

## Out of scope

- New rules, text, sounds, tiles or creatures. A bug found goes into the report.
- `src/view` beyond the field and call names that move. `Term`, `Info` and `Messages` keep their shape.
- Merging `Actor` and `Shot` into one class.
- A rename of `Fall.push` behind `World.push`.
- `FloorGen` and storey building, beyond the same names.
- Rust and the native extension.
