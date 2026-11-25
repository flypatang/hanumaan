# Cutscene files (`data/cutscenes/<id>.json`)

Read by `narrative/cutscene_player.gd` (`CutscenePlayer`, DESIGN §9 M31). One file per cutscene. The file id is the
file name without `.json`.

## Top level

```json
{
  "steps": [
    { "type": "wait", "duration": 1.0 }
  ]
}
```

A bare JSON array of steps is also accepted. Steps run one after another, in array order. A file with an unknown
step type, or a malformed step, fails to load (`ERR_PARSE_ERROR`) and nothing plays.

## Step types

| type | fields | behaviour |
|---|---|---|
| `camera_move` | `to: [x, y, z]`, `look_at?: [x, y, z]`, `duration` | Moves the camera from where it is to `to` over `duration` seconds. With `look_at`, the camera keeps facing that point. |
| `actor_move` | `actor: "name"`, `to: [x, z]`, `duration` | Moves the named actor on the ground plane to (x, z). Its height is kept. |
| `actor_pose` | `actor: "name"`, `pose: "name"` | Instant. Calls `set_pose(pose)` on the actor if it has that method. |
| `dialogue` | `id: "dialogue_id"`, `node?: "node_id"` | Emits `dialogue_requested`, then pauses until `continue_after_ui()`. |
| `shloka` | `id: "shloka_id"` | Emits `shloka_requested`, then pauses until `continue_after_ui()`. |
| `wait` | `duration` | Holds for `duration` seconds. |
| `fade` | `color: "TOKEN"`, `duration`, `out: true/false` | Emits `fade_requested(color, duration, out)`. Waits for `duration`. `color` is a `Palette` constant name (for example `"NIGHT_INDIGO"`, `"SAFFRON"`). Unknown names fall back to `UI_DARK`. |
| `set_flag` | `k: "flag_name"`, `v: value` | Instant. Emits `flag_set(k, v)`. The caller stores the flag (for example in `GameState`). |

`duration` is in seconds and defaults to 0. A zero-duration step completes in the same tick. Negative values are
treated as 0.

Actors are resolved by name through the dictionary passed to `play(id, actors, camera)`. An unknown actor name is
a warning, not an error: the step still runs for its duration and nothing moves.

## Playback rules

- Timed steps advance on the `delta` passed to `tick()`. Leftover time carries into the next step. Outcomes do not
  depend on frame rate (DESIGN §8).
- `dialogue` and `shloka` steps pause the sequence. Call `continue_after_ui()` to resume. Calls made while nothing is
  waiting are ignored.
- `finished(id)` is emitted once, after the last step completes. `stop()` cancels without emitting it.

## Example

```json
{
  "steps": [
    { "type": "fade", "color": "NIGHT_INDIGO", "duration": 1.0, "out": false },
    { "type": "camera_move", "to": [12, 14, 12], "look_at": [0, 2, 0], "duration": 4.0 },
    { "type": "actor_move", "actor": "hanuman", "to": [0, 0], "duration": 2.0 },
    { "type": "actor_pose", "actor": "hanuman", "pose": "kneel" },
    { "type": "shloka", "id": "leap_39" },
    { "type": "dialogue", "id": "pro_leap", "node": "start" },
    { "type": "set_flag", "k": "leap_done", "v": true },
    { "type": "fade", "color": "SAFFRON", "duration": 0.5, "out": true }
  ]
}
```
