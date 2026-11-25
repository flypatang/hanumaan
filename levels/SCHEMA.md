# Level JSON schema (binding for level writers)

Each level is `levels/<id>.json`, built at load time by `world/level_builder.gd`
(`LevelBuilder.build(level_json: Dictionary) -> Node3D`). Read `docs/DESIGN.md` §5 for the level list.

## Grid and units

- World units are metres. The grid is 2 m tiles (`TILE_SIZE = 2.0`).
- Tile `(x, z)` covers world x in `[2x, 2x+2]` and z in `[2z, 2z+2]`. Its centre is `(2x+1, 2z+1)`.
- Heights are integer steps of 0.5 m. A tile with `step: n` has its walking surface at `y = 0.5 * n`.
- All positions in this file are given as `[x, z]` in metres (y is derived from the tile height under the point),
  except triggers `size`, which is `[x, y, z]` in metres, and props `size`, which is `[x, y, z]` in metres.
- Angles are whole degrees.

## Top-level keys

| Key | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Level id, equal to the file name (e.g. `mahendra`). |
| `nav` | bool | no (default `true`) | `false` means no navmesh is baked. |
| `tiles` | array of tile | yes | Walkable and solid ground. Cells not listed are void (empty space). |
| `props` | array of prop | no | Architecture and nature props. |
| `spawns` | array of spawn | no | Player, enemy and NPC start points. |
| `triggers` | array of trigger | no | Box areas that emit an event when Hanuman enters them. |
| `shrines` | array of shrine | no | Meditation shrines. |

## Tile

```json
{ "x": 0, "z": 0, "type": "ground", "step": 0 }
```

- `x`, `z`: integer grid coordinates, `>= 0`. Each `(x, z)` pair may appear once.
- `type`: one of
  - `ground` (walkable, stone-grey earth)
  - `stone_floor` (walkable, temple stone)
  - `grass` (walkable, green)
  - `sand` (walkable, pale)
  - `water` (not walkable, deep blue, its surface is at its step height)
  - `wall` (not walkable, a solid block from the floor up to `step * 0.5 + 2.0` metres)
- `step`: integer `>= 0`, the height step described above. Default `0`.

Only `ground`, `stone_floor`, `grass` and `sand` are walkable for the navmesh. Every tile has a box collider, so
`water` is solid to bodies and gameplay must treat it as a hazard. Neighbouring walkable tiles link only when they
are at the same height, so keep height changes gradual (one step at a time) between tiles meant to be walked across.

## Prop

```json
{ "kind": "rock", "pos": [4.0, 4.0], "rot": 90, "seed": 7, "size": [2.0, 1.5, 2.0], "opts": { "flammable": false, "protected": false } }
```

- `kind` (required) selects the generator. Unknown kinds are skipped with a warning.
  - From `ArchitectureKit`: `wall`, `tier_house`, `pillar`, `gopuram`, `stairs`, `rooftop`.
  - From `NatureKit`: `ashoka_tree`, `shimshapa_tree`, `rock`, `cliff`, `grass_patch`.
- `pos`: `[x, z]`, the prop's footprint centre. Its y is the tile height under that point.
- `rot`: degrees, a multiple of 90 (`0`, `90`, `180`, `270`). Other values are rounded to the nearest multiple of 90.
- `seed`: integer, passed as the kit's seed. The same seed gives the same geometry. Default `0`.
- `size`: `[x, y, z]` in metres. Architecture kinds and `rock` are centred on their size box and lifted so their base
  sits on the tile surface. Trees use `size.y` as their height. `cliff` and `grass_patch` set their own placement
  (`grass_patch` radius is half of the larger of `size.x` and `size.z`). Default `[2.0, 3.0, 2.0]`.
- `opts.flammable`, `opts.protected`: booleans, default `false`. Stored as metadata on the prop root.

## Spawn

```json
{ "id": "hanuman_start", "kind": "player", "pos": [1.0, 1.0], "facing": 0 }
```

- `id`: unique string within the level.
- `kind`: `player`, an enemy variant id (for example `rakshasa_spear`, `rakshasa_archer`, `rakshasa_brute`), or an npc id.
- `pos`: `[x, z]`. y is the tile height under the point.
- `facing`: degrees around the y axis (0 is facing -Z).

## Trigger

```json
{ "id": "intro_trigger", "shape": "box", "size": [2.0, 2.0, 2.0], "pos": [3.0, 5.0], "on_enter": "intro_seen", "once": true }
```

- `id`: unique string.
- `shape`: must be `box`.
- `size`: `[x, y, z]` metres.
- `pos`: `[x, z]`. The area is centred `size.y * 0.5` above the tile height at `pos`.
- `on_enter`: event name, stored as metadata. The owning gameplay system connects to the Area3D and acts on it.
- `once`: if `true`, the trigger fires only once. Default `false`.

## Shrine

```json
{ "id": "shrine_1", "pos": [7.0, 7.0] }
```

- `id`: unique string. `pos`: `[x, z]`. y is the tile height under the point.

## Built node layout

`LevelBuilder.build` returns one `Node3D` root (`name` = level id) with these children:

| Child | Contents |
|---|---|
| `Tiles` | One `MeshInstance3D` per tile type (`Tiles_<type>`), merged, plus one `StaticBody3D` (`Floor`) holding the box colliders. |
| `Props` | One `Node3D` per prop, with metadata `kind`, `flammable`, `protected`. |
| `Spawns` | One `Marker3D` per spawn, with metadata `id`, `kind`, `facing`. |
| `Triggers` | One `Area3D` per trigger, with metadata `id`, `on_enter`, `once`. |
| `Shrines` | One `Marker3D` per shrine, with metadata `id`. |
| `NavigationRegion3D` | Navmesh built from the walkable tile quads (absent polygons when `nav` is `false`). |

## Example

See `levels/test_tiny.json`.
