# Hanumaan — Sundara Kanda (Design Document v0.1)

> Status: **DRAFT — awaiting approval.** Written by the design and orchestration agent (Opus).
> This is the single source of truth for every agent that works on the game. The module contracts in §9 are
> binding for the coding agents (Haiku). The review agents (Sonnet) check the code against §9 and §10.

---

## 1. Vision

An isometric 3D action RPG in which you play **Hanuman** during the *Sundara Kanda* of the
**Valmiki Ramayana**: the leap across the ocean, the night search of Lanka, the meeting with Sita,
the battle in the Ashoka grove, and the burning of Lanka.

**Pillars**
1. **Devotion as strength.** Hanuman's power comes from remembering Rama. The core resource, *Smarana*,
   fills when you act with purpose and drives his divine abilities.
2. **The power to change size.** Growing and shrinking is the signature mechanic. You become huge for
   combat and the leap, and tiny for stealth and slipping through gaps.
3. **Respectful spectacle.** Big, readable action with no gore. Hanuman never dies, and defeated
   rakshasas dissolve into smoke and embers.

**Target:** a 20–40 minute vertical slice, 5 chapters, Windows and Linux, keyboard and mouse or gamepad.

## 2. Source fidelity and depiction rules

The story follows the Valmiki Ramayana, *Sundara Kanda*. Where the game takes liberties for gameplay, they are
listed here so the reviewers can tell them apart from mistakes.

| Rule | Detail |
|---|---|
| Hanuman never dies | At 0 Vitality he enters **Exhausted**: he kneels and meditates, the screen goes saffron, and he recovers at the last **Shrine** with full Vitality. No game-over screen and no death animation. |
| No gore | Defeated enemies dissolve into smoke and embers. There is no blood. Bosses kneel, then dissolve. |
| Respectful portrayal | Hanuman is never shown as comic, clumsy or mocked. He speaks with humility and devotion. Rama and Sita are **never playable** and **never in combat**. |
| Rama's name | Shown in Devanagari "राम" on the HUD Smarana meter. The name is never used as a joke or a pickup. |
| Sita | Shown with dignity under the shimshapa tree. Ravana's threats are delivered in text, without menace animations aimed at her. |
| Gameplay liberties | (a) The kinkaras' numbers are shown as waves, not 80,000. (b) The leap is an on-rails flight sequence. (c) Shrines are a game device. |
| Brahmastra | Hanuman **chooses** to submit out of respect for Brahma. This is a cutscene, not a fight you lose. |

## 3. Story (chapter beats)

### Prologue — Mahendra Mountain (tutorial, ~3 min)
- The vanara search party stands on the southern shore. Jambavan reminds Hanuman of his forgotten powers
  (this is the end of the Kishkindha Kanda, used as the framing).
- **Teaches:** movement, camera, interacting, the light attack on training rocks, **Grow** (unlocked by Jambavan's words).
- **End:** Hanuman grows huge and leaps.

### Chapter 1 — The Leap (~6 min)
On-rails flight over the ocean. You steer within a corridor and dodge.
1. **Mainaka.** The golden mountain rises from the sea and offers him rest. Hanuman touches it in thanks and flies on.
   *Gameplay:* a healing ring and a Smarana refill. You pass straight through.
2. **Surasa**, mother of the nagas, sent by the gods to test him. She opens her mouth wider each time he grows.
   *Gameplay:* a size puzzle. Grow three times to match her, then **Shrink** at the right moment (shown on screen)
   to slip in and out. **Shrink unlocks here.**
3. **Simhika**, the shadow-seizing demoness, grabs his shadow on the water.
   *Gameplay:* the first boss. Dodge the shadow-grabs on the water, and when her mouth opens, Shrink and dive in. Then 3 hit phases.
- **End:** he lands on Trikuta mountain and Lanka glows golden at dusk.

### Chapter 2 — Night in Lanka (~8 min)
- Hanuman shrinks to the size of a cat to enter unseen.
- **Lankini**, guardian of the city's gate. A mini-boss duel. When she is defeated she yields and recalls Brahma's
  prophecy that Lanka will fall when a vanara strikes her down.
- **The search.** Stealth through the moonlit streets with guards' patrol cones. You must stay small, and guards
  who spot you raise an alarm. Search 3 places: the mansions, Ravana's palace (where he glimpses Mandodari and
  realises she cannot be Sita), and the Pushpaka vimana courtyard.
- **Despair beat.** Hanuman doubts himself, then resolves to keep searching, and finds the **Ashoka Vatika**.

### Chapter 3 — The Ashoka Grove (~5 min, mostly story)
- Hanuman hides in the shimshapa tree. Ravana arrives, threatens Sita and gives her a two-month deadline.
  Trijata tells her dream of Lanka's ruin.
- **Gameplay:** a short "sing softly" sequence in which you choose verses of Rama's story to win Sita's trust
  (a dialogue choice: the right choices are true to the text, and the wrong ones only cause a gentle retry).
- He gives **Rama's signet ring** and receives the **Chudamani**. Sita declines to be carried away, saying Rama himself must come.

### Chapter 4 — The Battle of the Grove (~8 min)
- Hanuman decides to test Lanka's strength and **uproots the grove** (destructible trees).
- **Wave arena:** kinkaras (brutes) → soldiers and archers → **Jambumali** (archer boss) → **Akshaya Kumara**
  (Ravana's son, chariot boss).
- **End:** **Indrajit** releases the Brahmastra. Hanuman submits willingly (cutscene).

### Chapter 5 — Lanka Dahan (~6 min)
- **Ravana's court** (dialogue): Hanuman counsels Ravana to return Sita. Vibhishana objects to killing an envoy,
  so Ravana orders Hanuman's tail set on fire instead.
- **Gameplay:** a timed rooftop chase. Grow, leap between rooftops and spread fire with your burning tail to the
  **marked rakshasa armouries and palaces**. Fire spreads between flammable props. Homes of the innocent and
  **Vibhishana's house are never flammable**, and the Ashoka grove where Sita sits is not either.
- A moment of fear for Sita, then relief when you reach the grove and see her safe.
- He cools his tail in the ocean and leaps back.
- **Epilogue:** "दृष्टा सीता — *I have seen Sita.*" Credits.

## 4. Core gameplay

### 4.1 Controls

| Action | KB/M | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Light attack (gada) | LMB | X / □ |
| Heavy attack (charged) | Hold LMB | Hold X / □ |
| Leap (dodge or jump) | Space | A / ✕ |
| Grow / Shrink (toggle cycle) | E / Q | RB / LB |
| Interact | F | Y / △ |
| Smarana surge (ultimate) | R | RT + LT |
| Pause | Esc | Start |

The camera is a fixed isometric 3D camera: orthographic, yaw 45°, pitch −35.264° (a true isometric view). It follows
the player smoothly, and you can rotate it in 90° steps with Z/C or the right stick (to be decided; it may be locked per level).

### 4.2 Stats and resources
- **Vitality** (HP): 100 at the start, and +25 per **Vow** upgrade. Restored at Shrines and by Mainaka.
- **Smarana** (devotion meter, 0–100): filled by landing hits (+2), protecting the innocent (+10), dialogue choices
  true to the text (+15), and meditating at a Shrine (fills it completely). Spent on: holding Grow (6/s), and the Smarana
  surge (100: a shockwave that dissolves weak enemies and stuns bosses).
- **Size state:** `SMALL` (0.35×), `NORMAL` (1×), `LARGE` (2.5×), and `GIANT` (6×, only in scripted moments such as the leap and Surasa).

| Size | Speed | Damage | Damage taken | Special |
|---|---|---|---|---|
| SMALL | 0.8× | 0.3× | 1.0× | Seen by guards at 25% of the usual distance. Fits through gaps marked `small_passage`. |
| NORMAL | 1.0× | 1.0× | 1.0× | — |
| LARGE | 0.75× | 2.0× | 0.6× | Heavy attacks knock enemies back. Can't use doors. Smashes props marked `breakable_large`. Drains Smarana. |

### 4.3 Combat
- Gada combo: 3-hit light chain (12 / 12 / 20 damage) and a heavy attack (35, knocks back, 0.6 s windup).
- **Leap-dodge**: 0.35 s of invulnerability, 1.2 s cooldown.
- Enemies telegraph their attacks with a red ground decal at least 0.4 s before the hit.
- Hit-stop of 60 ms on a heavy hit and 120 ms on a boss hit. The camera shakes in proportion to the damage.

### 4.4 Progression
- 3 **Vow** upgrades found as story rewards (+25 Vitality each).
- Abilities unlock in story order: Grow (Prologue), Shrink (Ch1), Smarana surge (Ch4), Tail Fire (Ch5).
- Save points are Shrines. The game auto-saves at chapter boundaries.

### 4.5 Enemies

| Id | Name | HP | Behaviour |
|---|---|---|---|
| `guard_spear` | Rakshasa spear-guard | 40 | Patrols, has a vision cone, poke and lunge |
| `guard_archer` | Rakshasa archer | 30 | Keeps its distance, 3-arrow volley, flees when you get close |
| `kinkara` | Kinkara brute | 90 | Slow, ground-slam with an area attack, staggers only from heavy hits |
| `boss_simhika` | Simhika | 400 | Ocean boss, 3 phases (shadow grab, wave, swallow) |
| `boss_lankini` | Lankini | 250 | Fast duel, combo strings, parry window |
| `boss_jambumali` | Jambumali | 350 | Arrow storms, moves between pillars |
| `boss_akshaya` | Akshaya Kumara | 500 | Chariot charges and mounted volleys, then fights on foot in phase 2 |

## 5. Levels

Levels are built **from data**: each level is a `levels/<id>.json` file that lists tiles, props, spawns, triggers and the
navmesh area. The level builder (module `level_builder`) turns it into a scene at load time. This keeps the level content
simple enough for Haiku to write, and easy to test.

| Id | Chapter | Size (tiles) | Key set pieces |
|---|---|---|---|
| `mahendra` | Prologue | 24×24 | Cliff, training rocks, Jambavan, the leap-off point |
| `ocean_leap` | 1 | Rail 900 m | Mainaka, Surasa, Simhika arena |
| `lanka_gate` | 2 | 20×20 | Lankini duel arena |
| `lanka_streets` | 2 | 48×48 | Stealth search, 3 search points, small passages |
| `ashoka_vatika` | 3–4 | 32×32 | Shimshapa tree, Sita, destructible grove, wave arena |
| `ravana_court` | 5 | 16×24 | Dialogue set |
| `lanka_rooftops` | 5 | 64×64 | Fire chase, flammable targets, the ocean edge |

The grid is 1 tile = 2 m, and heights go in 0.5 m steps.

## 6. Art direction (procedural, low-poly)

**All meshes and textures are generated in code** (`ArrayMesh` and `SurfaceTool` built from primitives, with flat shading).
There are no imported images or models.

**Look:** "temple-sculpture low-poly". Chunky, faceted forms, flat-shaded with a soft toon ramp, strong rim lights,
and gold trim lines on architecture. It should feel like painted stone and bronze.

### 6.1 Palette (hex, the single source of truth is `res://core/palette.gd`)

| Token | Hex | Use |
|---|---|---|
| `SAFFRON` | `#F28C28` | Hanuman's dhoti, UI accent, Smarana |
| `SINDOOR` | `#D7263D` | Hanuman's face tint, important markers |
| `GOLD` | `#E9B949` | Gada, crown, Lanka trim, Mainaka |
| `HANUMAN_FUR` | `#C98B3B` | Hanuman's body |
| `DEEP_OCEAN` | `#0E3B5C` | Sea |
| `NIGHT_INDIGO` | `#1B1B3A` | Night ambient light, Lanka shadows |
| `MOON` | `#DDE6F2` | Moonlight |
| `GROVE_GREEN` | `#2E7D4F` | Ashoka trees |
| `ASHOKA_RED` | `#E04E39` | Ashoka blossoms |
| `RAKSHASA_SKIN` | `#4B3F72` | Base colour for rakshasas |
| `RAKSHASA_ARMOR` | `#7A1F2B` | Rakshasa armour |
| `STONE` | `#B8A88A` | Architecture |
| `FIRE_CORE` | `#FFD166` | Fire |
| `FIRE_EDGE` | `#EF476F` | Fire |
| `UI_DARK` | `#14110F` | UI background |

### 6.2 Character construction (meshes built from primitives)
- **Hanuman** (about 1.8 m at NORMAL size): a capsule torso with a broad chest, an elongated sphere head with a
  sindoor-tinted muzzle, a tapered gold crown with 5 points, a saffron dhoti (a cone frustum), arms and legs made
  of tapered cylinders with joints, a tail as a chain of 8 cylinder segments animated by a simple spring
  (it curls up behind him), and a gada (a sphere on a cylinder handle, in gold).
- **Rakshasas**: bulkier and hunched, with horn cones, `RAKSHASA_SKIN` colouring, and armour plates in `RAKSHASA_ARMOR`.
  Their silhouettes must differ by role (spear, archer, brute).
- **Animation**: procedural animation on a skeleton (`Skeleton3D` built in code), with walk and attack poses as keyframes
  defined in code, and some motion computed from physics (tail, cloth sway).

### 6.3 Environment
- Lanka: tiered stepped buildings (stacked boxes with gold cornices), pillars and gopuram-like towers made of
  stacked tapering boxes. At night: indigo ambient light, moonlight from the top left, and warm lamp points.
- Fire: GPU particles plus an emissive flicker shader. Burned props become charred (their colours darken).

## 7. Audio (procedural)
- **SFX**: synthesised at runtime with `AudioStreamGenerator` (gada whoosh, impacts, footsteps, fire crackle, UI ticks).
- **Music**: a small sequencer that plays a drone (tanpura-like: a sawtooth wave through a filter, with fifths) and
  modal melodies in the **Raga Bhairav**-like scale (S r G m P d N), with tabla-like percussion (filtered noise and a
  sine pitch drop). Separate tracks for calm, stealth, combat, boss, and the climactic Dahan scene.
- All audio settings are on three buses: master, music and SFX.

## 8. Technical architecture

- **Engine:** Godot 4.7.2 (stable), GDScript with **static typing required** (warnings treated as errors, see §10).
- **Renderer:** Forward+ (desktop). Target 60 fps at 1080p on a mid-range GPU.

```
res://
  project.godot
  core/           # autoloads and shared foundations
  gen/            # procedural mesh, texture and audio generators
  gameplay/       # player, combat, abilities, enemies, AI
  world/          # level builder, triggers, shrines, fire
  narrative/      # dialogue, cutscenes, objectives
  ui/             # HUD, menus
  levels/         # *.json level data
  data/           # *.json dialogue and enemy tables
  tests/unit/     # gdUnit4 tests
  tests/playtest/ # scripted autoplay scenarios
```

**Communication:** systems talk only through the `EventBus` signals and the public APIs in §9. No module may
reach into another module's child nodes.

## 9. Module contracts (work units for the coding agents)

Each module is one coding task. The coding agent gets the module's section, §6.1 and §8, and nothing else.
The **acceptance tests** must be written first, and they must pass.

> Notation: `func name(args) -> Ret` is the public API. Anything else is private and must start with `_`.

### Wave 0 — Foundations (they depend on nothing)

**M01 `core/palette.gd`** (`class_name Palette`). Constants for every token in §6.1 as `Color`.
*Tests:* each constant matches its hex value.

**M02 `core/event_bus.gd`** (autoload `EventBus`). Signals:
`player_damaged(amount:int, source:Node)`, `player_exhausted()`, `player_recovered()`,
`enemy_defeated(enemy_id:StringName, pos:Vector3)`, `size_changed(new_size:int)`,
`smarana_changed(value:float)`, `vitality_changed(value:int, max:int)`,
`objective_updated(id:StringName, text:String, done:bool)`, `dialogue_started(id:StringName)`,
`dialogue_finished(id:StringName, flags:Dictionary)`, `level_loaded(id:StringName)`,
`chapter_completed(id:StringName)`, `fire_ignited(target_id:StringName)`, `alarm_raised(pos:Vector3)`.
*Tests:* each signal exists with the right number of arguments.

**M03 `core/game_state.gd`** (autoload `GameState`). Fields: `chapter:StringName`, `flags:Dictionary`,
`vows:int`, `unlocked:Array[StringName]`, `last_shrine:Dictionary`. API: `set_flag(k,v)`, `get_flag(k, default)`,
`unlock(ability:StringName)`, `is_unlocked(ability) -> bool`, `save_game(slot:int) -> Error`,
`load_game(slot:int) -> Error` (JSON in `user://save_<slot>.json`), `reset()`.
*Tests:* save, reset and load gives back identical state; loading a missing slot returns `ERR_FILE_NOT_FOUND`.

**M04 `core/input_setup.gd`** registers every action in §4.1 in the `InputMap` at startup (keyboard and joypad).
*Tests:* every action exists and has at least one key event and one joypad event.

**M05 `gen/mesh_kit.gd`** (`class_name MeshKit`, static functions returning `ArrayMesh`, flat-shaded):
`box(size:Vector3, color:Color)`, `cylinder(r_top, r_bottom, h, sides:int, color)`, `cone(r, h, sides, color)`,
`sphere(r, rings:int, segments:int, color)`, `capsule(r, h, color)`, `merge(parts:Array[Dictionary]) -> ArrayMesh`
(each part is `{mesh, transform}`). Colours are stored as vertex colours. A shared material, `MeshKit.flat_material()`,
uses vertex colours and a toon ramp.
*Tests:* vertex counts match the expected formulas, the bounding boxes match the sizes, and the normals are flat
(each triangle's three normals are equal).

**M06 `gen/synth.gd`** (`class_name Synth`): `tone(freq, dur, wave:int, env:Dictionary) -> PackedVector2Array`,
`noise(dur, env, filter_hz) -> PackedVector2Array`, `mix(buffers:Array) -> PackedVector2Array`,
`to_stream(buf) -> AudioStreamWAV`. Samples are 44100 Hz stereo.
*Tests:* the length equals dur×44100, no sample goes above 1.0, and silence comes out as zeros.

### Wave 1 — Generators and systems (depend on Wave 0)

**M07 `gen/hanuman_model.gd`** builds Hanuman (§6.2) as a `Node3D` with a `Skeleton3D` (bones: root, hips, spine,
chest, head, upper/lower arm and leg on each side, tail_0..7, gada_socket). `build() -> Node3D`.
*Tests:* the bone names exist, the height is 1.7–1.9 m, and the colours come from the palette.

**M08 `gen/rakshasa_model.gd`** with `build(variant:StringName) -> Node3D`, for the variants spear, archer, brute and lankini.
*Tests:* the silhouettes differ (the bounding box width/height ratios differ by more than 15% between variants).

**M09 `gen/architecture_kit.gd`** with `wall`, `tier_house`, `pillar`, `gopuram`, `stairs` and `rooftop`, each taking a size and
`rng_seed` and returning a `Node3D` with collision.
*Tests:* the same seed gives the same result, and collision shapes exist.

**M10 `gen/nature_kit.gd`** with `ashoka_tree`, `shimshapa_tree`, `rock`, `cliff`, `ocean_plane` (with a shader) and `grass_patch`.
*Tests:* the same seed gives the same result, and the triangle counts stay within budget (each tree has fewer than 1500 triangles).

**M11 `gen/sfx_library.gd`** with `get(id:StringName) -> AudioStreamWAV`, built lazily and cached. The ids are `whoosh`,
`impact_light`, `impact_heavy`, `step`, `fire_loop`, `ui_tick`, `grow`, `shrink`, `chant_bell`.
*Tests:* every id returns a stream that isn't empty, and the second call returns the cached object.

**M12 `gen/music_player.gd`** (autoload `Music`) with `play(track:StringName, fade:float)`, `stop(fade)`. Implements §7.
*Tests:* the scale degrees produced match Bhairav, and crossfading doesn't produce samples above 1.0.

**M13 `gameplay/components/health.gd`** (`class_name Health`, a Node). Exports `max_value`. API `damage(n, source)`,
`heal(n)`, and a `value` property. Signals `changed`, `depleted`. It supports a damage multiplier and an invulnerability flag.
*Tests:* it clamps at 0 and at max; `depleted` is emitted exactly once; damage is ignored while invulnerable.

**M14 `gameplay/components/hitbox.gd` and `hurtbox.gd`.** These are `Area3D`s on the collision layers defined in
`core/layers.gd`. A hitbox has `damage`, `knockback` and `team`, and a hurtbox forwards hits from the other team to `Health`.
*Tests:* friendly fire is ignored, and each activation of an attack applies its hit only once.

**M15 `world/level_builder.gd`** with `build(level_json:Dictionary) -> Node3D`. It turns tiles, props (through the kits),
spawns, triggers and shrines into nodes, and bakes the navigation region. The JSON schema is in `levels/SCHEMA.md` (written by the same agent).
*Tests:* a tiny sample level builds with the expected number of nodes, and the navmesh is not empty.

**M16 `narrative/dialogue_runner.gd`** loads `data/dialogue/<id>.json` (nodes with speaker, text, choices
`{text, next, flags, smarana}`) with `start(id)`, `choose(i)`, and the signals `line_shown` and `finished`.
*Tests:* walking through the branches reaches the expected end, and flags are applied.

**M17 `narrative/objectives.gd`** with `add(id, text)`, `complete(id)`, `is_done(id)`, and it emits through the EventBus.
*Tests:* adding, completing and checking state behave as expected, and adding the same objective twice does nothing.

### Wave 2 — The player and enemies (depend on Waves 0–1)

**M18 `gameplay/player/player.gd`**, a CharacterBody3D. It handles movement, the 3-hit light combo, the heavy attack,
the leap-dodge (with invulnerability frames), interaction, and combines M07, M13 and M14. All the numbers come from §4.3.
*Tests (headless):* simulated input moves the player at the expected speed; the combo timing windows work; there is no damage during a dodge.

**M19 `gameplay/abilities/size_shift.gd`** implements the §4.2 table: a 0.4 s tween, the Smarana drain while LARGE,
and it refuses to grow if the space above is blocked (ShapeCast). It emits `size_changed`.
*Tests:* every row of the table, the forced shrink when Smarana runs out, and the block check.

**M20 `gameplay/player/devotion.gd`** handles Smarana gains and spending, the surge ability, and the Exhausted state and
recovery flow (§2). It talks to `GameState.last_shrine`.
*Tests:* at 0 Vitality it goes Exhausted, the player respawns at the shrine with full Vitality, and no game-over state exists.

**M21 `gameplay/enemies/enemy_base.gd`** is a state machine (idle, patrol, alert, chase, attack, stagger, dissolve)
with a vision cone and telegraph decals (§4.3). The data comes from `data/enemies.json`.
*Tests:* state transitions on given inputs; the cone detects a SMALL player at 25% range; the telegraph appears at least 0.4 s before the hit.

**M22 `gameplay/enemies/guard_spear.gd`, `guard_archer.gd` and `kinkara.gd`**, which extend M21.

**M23–M26 bosses:** `boss_simhika.gd`, `boss_lankini.gd`, `boss_jambumali.gd`, `boss_akshaya.gd`. Each has its own
phase table. These are assigned to **Sonnet**, not Haiku, because they are complex.

### Wave 3 — World systems, UI and sequences

**M27 `world/shrine.gd`**: interacting with a shrine meditates, sets `last_shrine`, refills everything and saves.

**M28 `world/fire.gd`**: flammable props catch fire from the tail hitbox (team `fire`) and spread to flammable neighbours
within 3 m after 1.5 s. The `protected` tag prevents ignition (§3 Ch5).
*Tests:* fire spreads, and protected props never ignite even when surrounded by fire.

**M29 `world/stealth_director.gd`**: alarm levels, escalation and the guard response.

**M30 `gameplay/flight/leap_controller.gd`**: the on-rails path (Path3D), steering within the corridor, and gates for
Mainaka, Surasa and Simhika.

**M31 `narrative/cutscene_player.gd`**: plays cutscenes made from steps (camera moves, actor moves, dialogue, waits) defined in JSON.

**M32 `ui/hud.gd`**: Vitality, the Smarana meter with "राम", the size indicator, objectives, and the boss bar.
**M33 `ui/menus.gd`**: title, pause, settings (volume, fullscreen, key remapping), and chapter select once unlocked.
**M34 `ui/dialogue_box.gd`**: typewriter text, choices, speaker portrait (rendered model).

### Wave 4 — Content (data, written by Opus and Haiku, reviewed by Sonnet)
- **C1** the 7 level JSON files (§5) · **C2** dialogue JSON for all chapters (written by Opus, for text fidelity) ·
  **C3** `data/enemies.json` · **C4** cutscene JSON · **C5** music cue sheets.

### Wave 5 — Integration and polish (Sonnet)
- Chapter flow (`core/chapter_flow.gd`), scene transitions, balance passes, performance.

## 10. Quality gates (the factory runs these on every change)

1. **Script check:** run `godot --headless --check-only` on every script. Static typing is required: these project
   settings are set to *Error*: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`,
   `unsafe_call_argument`, `inferred_declaration` is *Warn*.
2. **Unit tests:** gdUnit4 run headless, with 0 failures and every module's acceptance tests present.
3. **Review (Sonnet):** checks the change against its contract in §9, the depiction rules in §2, that the module
   only uses public APIs, the numbers against §4, and readability. Its verdict is approve or request changes, with specific line comments.
4. **Playtest (from Wave 2 on):** `tests/playtest/*.gd` scenarios run with `--write-movie` at a fixed frame rate.
   The bot plays fixed inputs (for example "walk to the shrine, meditate, grow, hit the rock"). Its assertions check
   game state, and Opus inspects sampled frames for visual problems.
5. **Rework limit:** if a module fails review twice, Opus takes it over.

## 11. Build and release
- Export presets: `Windows Desktop` (x86_64, a single .exe with the game data embedded) and `Linux` (x86_64).
- GitHub Actions: on each push it runs the script check and unit tests. On a `v*` tag it exports both builds, zips them, and
  attaches them to a GitHub release.
- The version is in `project.godot` (`application/config/version`).

## 12. Risks

| Risk | Mitigation |
|---|---|
| Procedural art looks crude | A strict palette and toon shading, a silhouette review pass by Opus after Wave 1, and a camera that hides a lot of detail. |
| Haiku is weak at GDScript | Small modules, strict typing, tests first, Sonnet review, and Opus takes over after 2 failed reviews. |
| Animations are hard to do in code | A small set of keyframed poses with blending, and physics-driven secondary motion. |
| Exhausted mechanic lacks tension | Exhaustion resets the boss phase and costs your Smarana. |
| Getting the source material wrong | Opus writes all the dialogue, and the reviewers check §2 and §3 as a gate. |

## 13. Open questions for the owner
1. Should the in-game text include a few Sanskrit or Hindi lines (in Devanagari, with English translations), or be English only?
2. Should camera rotation be allowed (90° steps), or fixed per level?
3. Should the game include an epilogue preview teasing the next game (for example the Setu bandhan, building the bridge)?
