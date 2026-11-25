# Automated playthrough report (DESIGN §10 gate 4)

Bot: `tests/playtest/playthrough_bot.gd`. Test: `tests/unit/test_p1_playthrough.gd`.
The bot starts the real `main.tscn` (real `ChapterFlow`, `LevelRuntime`, `Player`, enemies, bosses, dialogue box,
cutscene player and credits), presses New Game on the title menu and plays to the credits screen.
It runs headless at a fixed 1/60 s physics step (physics rate and time scale are raised together, 8x real time) and
finishes in about 40 s of real time (the test fails above 300 s).

## Result of the last run

| Chapter | Reached | Completed | Blocking bugs |
|---|---|---|---|
| prologue | yes | yes | 0 |
| ch1 (the leap) | yes | yes | 0 |
| ch2 (night in Lanka) | yes | yes | 0 |
| ch3 (the grove) | yes | yes | 0 |
| ch4 (the battle) | yes | yes | 0 |
| ch5 (Lanka Dahan) | yes | yes | 0 |
| epilogue | yes | yes | 0 |
| teaser_setu | yes | yes | 0 |

The credits screen is reached. No step had to be forced with a direct state change (`forced_steps` = 0).

## What is real and what is a shortcut

Real (keyboard actions, real input events, real game objects):
- New Game from the title menu, the opening cutscene and its shloka card.
- Prologue: walking to Jambavan with the move keys (camera-relative), pressing Grow after his words (size becomes LARGE),
  three light attacks at the training rocks.
- Chapter 1: steering the on-rails leap with the move keys (steering away from obstacles, collecting the Mainaka ring), the
  Surasa size puzzle (3 x Grow, then Shrink inside the 1.5 s window), the Simhika fight (light attacks, and Shrink in
  the 3 s window to dive in).
- One Kinkara fight (chapter 4, wave 0) with the player's own light attacks (the player is made invulnerable for it, so
  the fight cannot depend on luck).
- All dialogue lines are advanced with the interact key; the Ch3 story choices are answered through the choice
  buttons, with one wrong answer on purpose (the gentle retry), then the three true ones; shloka cards are dismissed with a key.
- The street search (the three search triggers), the grove waves and both bosses, the court, the rooftop fire, the
  epilogue, the teaser and the credits.

Shortcuts (allowed by the brief):
- Long walks are teleports to the trigger (the physics must route the trigger; if it did not, the bot fires it
  directly and notes it; this never happened).
- Enemies other than the one real fight, and Lankini, Jambumali and Akshaya, are finished with `apply_hit`.
- The player is invulnerable in Ch2 to Ch5 so nothing depends on luck.
- Rooftop fire: the bot stands next to each of the 22 flammable props, so the player's tail fire (`burn_near` in the
  physics process) sets it alight; all 22 caught without help. It then calls `ignite()` and `burn_near()` on the 39
  protected props and waits 8 s: none ignited.

## Numbers from the last run

realtime 36.7 s, 7390 physics steps; 204 dialogue lines advanced; 4 right and 1 wrong story choices; 3 Surasa grows
and 1 shrink; 34 Simhika hits; 7 real attack hits on the Kinkara; 3 searches; 5 waves seen; 22 of 22 flammable props
burnt; 0 of 39 protected props ignited.

## Blocking bugs

None. The bot was never stopped by a game bug.

## Non-blocking defects found (not fixed here: the files belong to other modules)

These print Godot `ERROR` lines during a normal playthrough but do not stop the game.

1. **Level swapped inside a physics callback.** `game/level_runtime.gd:922` (`_on_trigger_body`) routes `level:<id>`
   and `chapter_complete:` synchronously from `body_entered`; the flow then asks main to load the next level in the
   same call (`game/chapter_flow.gd:480` -> `main.gd:138-153`).
   - `main.gd:153` (`_clear_runtime`): "Removing a CollisionObject node during a physics callback is not allowed"
     (2 times: every level exit triggered by walking into a trigger).
   - `world/shrine.gd:32` (`_ready`, `monitorable = true`): "Function blocked during in/out signal. Use
     set_deferred" (22 times, once per shrine of the level that is built inside that callback).
   - Repro: stand in `t_gate_open` of `lanka_gate` (or any `level:` / final trigger) with `gate_open` set.
   - Suggested fix: defer the level request (`call_deferred`) in `main.gd`, and use `set_deferred("monitorable", true)`.
2. **Duplicate connection of `game_event`.** `main.gd:147` connects `_runtime.game_event` to `_flow.handle_event`, and
   `game/chapter_flow.gd:728` (`bind_leap`) connects the same signal to the same method again when the leap level
   loads: "Signal 'game_event' is already connected" (once per game). Harmless (the second connect is refused), but
   a second connection would double every event, so it should be guarded.
3. **Hurtbox polls a monitoring-off area.** `gameplay/enemies/enemy_base.gd:266` sets `hurtbox.monitoring = false` on
   dissolve, while `gameplay/components/hurtbox.gd:28` (`_physics_process`) keeps calling `get_overlapping_areas()`:
   "Can't find overlapping areas when monitoring is off" on every physics step of every dissolving enemy
   (about 580 lines in one run). Repro: defeat any enemy.
   Suggested fix: `if not monitoring: return` at the top of `Hurtbox._physics_process`.
