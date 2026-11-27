class_name LevelBuilder
extends RefCounted
## Builds a level scene from levels/<id>.json (DESIGN §5, §9 M15). The format is in levels/SCHEMA.md.
## Stateless: every function is static, so `LevelBuilder.build(data)` is the whole API.
## Tiles are merged into one mesh per tile type ("Tiles_<type>"). Every walkable tile becomes one navmesh quad.
##
## Terrain look (docs/ART.md "Geometry", module B6). Everything below is VISUAL ONLY: the colliders stay flat boxes
## and the navmesh stays one flat quad per walkable tile.
##  - grass, ground and sand tops are a subdivided surface with gentle height noise (HEIGHT_AMPLITUDE) and smooth
##    normals; the noise fades to zero next to walls, paving, height changes and the level edge, so nothing cracks;
##  - vertex colours come from world-space colour fields per tile type and are blended softly, along a wobbling
##    line, between neighbouring tile types at the same height, so there is no visible grid;
##  - stone_floor (and the tops of walls) is laid with bevelled paving slabs in a pattern that runs across tile
##    borders; its drops are ashlar faces with a kerb or cornice;
##  - walls are bevelled ashlar stone with a plinth and a layered cornice, mitred round corners;
##  - natural drops are rocky cliff faces;
##  - water tiles become a sloping bed, and one WaterKit ocean surface per water level ("Water_<step>") is laid
##    WATER_DROP below the tile height.
## Each "Tiles_<type>" mesh is one surface with the painterly Materials kind TILE_MATERIAL. Every tile type shares
## that one material on purpose: the borders between types are blended in the vertex colours, and a change of
## material along the tile edge would draw the grid back in. Grass is ground tinted with a varied foliage green.
## Systems talk through the built nodes' metadata and signals; this module never touches other modules' children.

const TILE_SIZE: float = 2.0
const STEP_HEIGHT: float = 0.5
const SLAB_DEPTH: float = 1.0
const WALL_EXTRA_HEIGHT: float = 2.0
const DEFAULT_PROP_SIZE: Vector3 = Vector3(2.0, 3.0, 2.0)
const DEFAULT_TRIGGER_SIZE: Vector3 = Vector3(2.0, 2.0, 2.0)

## Largest visual rise or dip of a natural tile top around its tile height, in metres.
const HEIGHT_AMPLITUDE: float = 0.06
## Subdivisions of a natural tile top along each side.
const TOP_SUBDIVISIONS: int = 4
## Depth of the joints between paving slabs and between wall blocks, in metres.
const JOINT_DEPTH: float = 0.02
## How far the cornice of a wall overhangs its face, in metres.
const CORNICE_OVERHANG: float = 0.15
## The water surface lies this far below the height of its tiles; the bed sinks to WATER_DEPTH.
const WATER_DROP: float = 0.2
const WATER_DEPTH: float = 0.8
const WATER_WAVE_SCALE: float = 0.18
## Where water reaches the edge of the level, the surface runs on this far so the sea has no visible end.
const WATER_OVERRUN: float = 48.0
## The Materials kind of every tile surface.
## Collider sizes of the nature props (FX1): how much of the prop's size box the solid part fills, and trunk radii.
const ROCK_FILL: float = 0.85
const CLIFF_FILL: float = 0.8
const TRUNK_RADIUS_PER_HEIGHT: float = 0.06
const TRUNK_RADIUS_MIN: float = 0.3
const TRUNK_RADIUS_MAX: float = 1.0
const TILE_MATERIAL: StringName = &"stone"

const TILE_TYPES: Array[String] = ["ground", "water", "stone_floor", "grass", "sand", "wall"]
const WALKABLE_TYPES: Array[String] = ["ground", "stone_floor", "grass", "sand"]
const ARCHITECTURE_KINDS: Array[String] = ["wall", "tier_house", "pillar", "gopuram", "stairs", "rooftop"]
const NATURE_KINDS: Array[String] = ["ashoka_tree", "shimshapa_tree", "rock", "cliff", "grass_patch"]


## Builds the level. Returns a Node3D root named after the level id, with the child groups
## Tiles, Props, Spawns, Triggers, Shrines and NavigationRegion3D (see levels/SCHEMA.md).
static func build(level_json: Dictionary) -> Node3D:
	var level_id: String = str(level_json.get("id", "level"))
	var root: Node3D = Node3D.new()
	root.name = level_id
	root.set_meta("level_id", level_id)
	var tiles: Array[Dictionary] = _parse_tiles(_dicts_of(level_json.get("tiles", [])))
	var heights: Dictionary = _height_map(tiles)
	root.add_child(_build_tiles(tiles, level_id))
	root.add_child(_build_props(_dicts_of(level_json.get("props", [])), heights))
	root.add_child(_build_spawns(_dicts_of(level_json.get("spawns", [])), heights))
	root.add_child(_build_triggers(_dicts_of(level_json.get("triggers", [])), heights))
	root.add_child(_build_shrines(_dicts_of(level_json.get("shrines", [])), heights))
	root.add_child(_build_navigation(tiles, (level_json.get("nav", true) as bool)))
	return root


# --- parsing -----------------------------------------------------------------------------------------------

static func _dicts_of(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				out.append(entry as Dictionary)
	return out


static func _vec2_of(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		var pair: Array = value as Array
		return Vector2((pair[0] as float), (pair[1] as float))
	return Vector2.ZERO


static func _vec3_of(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		var triple: Array = value as Array
		return Vector3((triple[0] as float), (triple[1] as float), (triple[2] as float))
	return fallback


static func _flag(opts: Dictionary, key: String) -> bool:
	var value: Variant = opts.get(key, false)
	return value is bool and (value as bool)


## Normalises tile records to {cell: Vector2i, type: String, step: int}. Unknown types are dropped with a warning.
static func _parse_tiles(raw: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in raw:
		var tile_type: String = str(entry.get("type", "ground"))
		if not TILE_TYPES.has(tile_type):
			push_warning("LevelBuilder: unknown tile type '%s', tile skipped" % tile_type)
			continue
		var cell: Vector2i = Vector2i((entry.get("x", 0) as int), (entry.get("z", 0) as int))
		out.append({"cell": cell, "type": tile_type, "step": maxi(0, (entry.get("step", 0) as int))})
	return out


## Maps each occupied cell to its integer step, so height queries are O(1).
static func _height_map(tiles: Array[Dictionary]) -> Dictionary:
	var heights: Dictionary = {}
	for tile: Dictionary in tiles:
		heights[tile["cell"] as Vector2i] = (tile["step"] as int)
	return heights


## Surface height at a world-space [x, z] point: the step of its tile times 0.5 m, or 0 for void.
static func _height_at(point: Vector2, heights: Dictionary) -> float:
	var cell: Vector2i = Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))
	if heights.has(cell):
		return (heights[cell] as int) * STEP_HEIGHT
	return 0.0


static func _snap_right_angle(degrees: int) -> int:
	return posmod(roundi(float(degrees) / 90.0) * 90, 360)


# --- tiles -------------------------------------------------------------------------------------------------

const _NATURAL_TYPES: Array[String] = ["ground", "grass", "sand"]
const _BLEND_TYPES: Array[String] = ["ground", "grass", "sand", "stone_floor", "water"]
const _DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _HEIGHT_FREQUENCY: float = 0.42
const _FADE_WIDTH: float = 0.55
const _BLEND_RADIUS: float = 0.75
const _BLEND_WOBBLE: float = 0.3
const _SHORE_WIDTH: float = 1.9
const _SLAB_INSET: float = 0.045
const _BLOCK_INSET: float = 0.03
const _BLOCK_LENGTH: float = 1.0
const _COURSE_HEIGHT: float = 0.5
const _CLIFF_BULGE: float = 0.16
const _CLIFF_ROW: float = 0.25
const _CLIFF_COLUMNS: int = 4
## The paving pattern repeats every 4 m: slabs as (origin x, origin z, width, depth) in 1 m cells. Two 2 x 2 slabs
## sit on alternate tile corners with pairs of 1 x 2 slabs between them, so every slab crosses a tile border.
const _SLABS: Array[Rect2i] = [
	Rect2i(1, 1, 2, 2), Rect2i(3, 3, 2, 2), Rect2i(1, 3, 1, 2), Rect2i(2, 3, 1, 2), Rect2i(3, 1, 2, 1), Rect2i(3, 2, 2, 1),
]

static var _noise: FastNoiseLite = null


## Triangle soup of one mesh surface. Triangles are stored clockwise seen from outside (Godot's front face).
class _Surf extends RefCounted:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()

	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var geometric: Vector3 = (b - a).cross(c - a)
		if geometric.length_squared() < 1.0e-12:
			return
		if geometric.dot(na + nb + nc) > 0.0:
			verts.append(a)
			verts.append(c)
			verts.append(b)
			normals.append(na)
			normals.append(nc)
			normals.append(nb)
			colours.append(ca)
			colours.append(cc)
			colours.append(cb)
		else:
			verts.append(a)
			verts.append(b)
			verts.append(c)
			normals.append(na)
			normals.append(nb)
			normals.append(nc)
			colours.append(ca)
			colours.append(cb)
			colours.append(cc)

	## A quad a-b-c-d (corners in order round the quad) with one normal and colour per corner.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		tri(a, b, c, na, nb, nc, ca, cb, cc)
		tri(a, c, d, na, nc, nd, ca, cc, cd)

	## A flat quad with one normal.
	func flat(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		quad(a, b, c, d, normal, normal, normal, normal, ca, cb, cc, cd)


## What a tile knows about itself and its eight neighbours while its geometry is emitted.
class _Ctx extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var type: String = ""
	var roof: float = 0.0
	var x0: float = 0.0
	var z0: float = 0.0
	var by_cell: Dictionary = {}
	## Cells the height noise must fade out against.
	var hard: Array[Rect2] = []
	## Land cells next to a water tile (the bed rises toward them).
	var shore: Array[Rect2] = []
	## Cells whose colours blend into this tile, with their types (this tile included).
	var blend_rects: Array[Rect2] = []
	var blend_types: Array[String] = []
	var mixed: bool = false


static func _tile_colour(tile_type: String) -> Color:
	match tile_type:
		"ground":
			return Palette.BARK.lerp(Palette.STONE, 0.55)
		"stone_floor":
			return Palette.STONE
		"grass":
			return Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.12)
		"sand":
			return Palette.STONE.lerp(Palette.GOLD, 0.35)
		"water":
			return Palette.STONE.lerp(Palette.GOLD, 0.25).lerp(Palette.DEEP_OCEAN, 0.3)
		"wall":
			return Palette.STONE.lerp(Palette.MOON, 0.22)
		_:
			return Palette.STONE


## Roof height of a tile: its surface, or the top of the solid block for walls.
static func _roof_of(tile: Dictionary) -> float:
	var top: float = (tile["step"] as int) * STEP_HEIGHT
	if str(tile["type"]) == "wall":
		return top + WALL_EXTRA_HEIGHT
	return top


## Roof height of the tile at `cell`, or 0 for a void cell.
static func _roof_at(cell: Vector2i, by_cell: Dictionary) -> float:
	if by_cell.has(cell):
		return _roof_of(by_cell[cell] as Dictionary)
	return 0.0


static func _type_at(cell: Vector2i, by_cell: Dictionary) -> String:
	if by_cell.has(cell):
		return str((by_cell[cell] as Dictionary)["type"])
	return ""


static func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(float(cell.x) * TILE_SIZE, float(cell.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)


## Shared simplex noise in [-1, 1]; `offset` picks an independent layer.
static func _n2(x: float, z: float, frequency: float, offset: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = 1008
		_noise.frequency = 1.0
		_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return _noise.get_noise_3d(x * frequency, offset, z * frequency)


## Deterministic value in [0, 1) from three integers.
static func _hash01(a: int, b: int, c: int) -> float:
	var h: int = posmod(a * 374761393 + b * 668265263 + c * 2147483647, 1000003)
	h = posmod(h * h + a * 31 + b * 17 + c * 101, 1000003)
	h = posmod(h * 7919 + 104729, 1000003)
	return float(h) / 1000003.0


static func _scaled(colour: Color, factor: float) -> Color:
	return Color(clampf(colour.r * factor, 0.0, 1.0), clampf(colour.g * factor, 0.0, 1.0), clampf(colour.b * factor, 0.0, 1.0), colour.a)


static func _rect_distance(rect: Rect2, x: float, z: float) -> float:
	var dx: float = maxf(maxf(rect.position.x - x, x - rect.end.x), 0.0)
	var dz: float = maxf(maxf(rect.position.y - z, z - rect.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


static func _nearest(rects: Array[Rect2], x: float, z: float, limit: float) -> float:
	var best: float = limit
	for rect: Rect2 in rects:
		best = minf(best, _rect_distance(rect, x, z))
	return best


## The colour field of a tile type at a world point: the type's colour with broad painted variation (lighter and
## darker drifts, and for grass sunlit yellow-green and deep cool patches). Continuous across tiles.
static func _type_colour_at(tile_type: String, x: float, z: float) -> Color:
	var base: Color = _tile_colour(tile_type)
	var broad: float = _n2(x, z, 0.11, 11.0)
	var fine: float = _n2(x, z, 0.45, 23.0)
	match tile_type:
		"grass":
			var patch: float = _n2(x, z, 0.19, 37.0)
			base = base.lerp(Palette.LEAF_DARK, clampf(-patch * 0.75, 0.0, 0.55))
			base = base.lerp(Palette.GROVE_GREEN.lerp(Palette.GOLD, 0.5), clampf(patch * 0.6, 0.0, 0.4))
			return _scaled(base, 1.0 + broad * 0.1 + fine * 0.07)
		"ground":
			base = base.lerp(Palette.BARK, clampf(broad * 0.5, 0.0, 0.35))
			base = base.lerp(Palette.STONE, clampf(-broad * 0.45, 0.0, 0.3))
			return _scaled(base, 1.0 + fine * 0.08)
		"sand":
			base = base.lerp(Palette.STONE.lerp(Palette.MOON, 0.35), clampf(broad * 0.6, 0.0, 0.35))
			return _scaled(base, 1.0 + fine * 0.06 - maxf(-broad, 0.0) * 0.08)
		"stone_floor", "wall":
			base = base.lerp(Palette.STONE.lerp(Palette.NIGHT_INDIGO, 0.3), clampf(broad * 0.5, 0.0, 0.3))
			base = base.lerp(Palette.STONE.lerp(Palette.GOLD, 0.25), clampf(-broad * 0.4, 0.0, 0.25))
			return _scaled(base, 1.0 + fine * 0.05)
		_:
			return _scaled(base, 1.0 + fine * 0.05)


## The colour of a tile's top at a world point: its type's colour field, softly blended with the fields of the
## neighbouring tile types at the same height. The blend line wobbles, so the border does not follow the grid.
static func _colour_at(ctx: _Ctx, x: float, z: float) -> Color:
	if not ctx.mixed:
		return _type_colour_at(ctx.type, x, z)
	var px: float = x + _n2(x, z, 0.8, 51.0) * _BLEND_WOBBLE
	var pz: float = z + _n2(x, z, 0.8, 67.0) * _BLEND_WOBBLE
	var total: float = 0.0
	var weights: Dictionary[String, float] = {}
	for i: int in range(ctx.blend_rects.size()):
		var w: float = 1.0 - _rect_distance(ctx.blend_rects[i], px, pz) / _BLEND_RADIUS
		if w <= 0.0:
			continue
		w = w * w
		total += w
		weights[ctx.blend_types[i]] = (weights.get(ctx.blend_types[i], 0.0) as float) + w
	if total <= 0.0:
		return _type_colour_at(ctx.type, x, z)
	var out: Color = Color(0.0, 0.0, 0.0, 1.0)
	for tile_type: String in weights:
		var colour: Color = _type_colour_at(tile_type, x, z)
		var share: float = weights[tile_type] / total
		out.r += colour.r * share
		out.g += colour.g * share
		out.b += colour.b * share
	return out


## How deep the bed of a water tile lies below its tile height at a world point (0 at the shore). The distances
## to the land cells are combined softly, which rounds the corners of a pond, and the slope's start wanders, so
## the waterline is not a straight copy of the tile edges.
static func _bed_depth(ctx: _Ctx, x: float, z: float) -> float:
	if ctx.shore.is_empty():
		return WATER_DEPTH
	var floor_term: float = 1.0 / (_SHORE_WIDTH * _SHORE_WIDTH)
	var sum: float = floor_term
	for rect: Rect2 in ctx.shore:
		var d: float = maxf(_rect_distance(rect, x, z), 0.001)
		sum += maxf(1.0 / (d * d) - floor_term, 0.0)
	var shore: float = 1.0 / sqrt(sum)
	var shelf: float = 0.12 + 0.3 * (0.5 + 0.5 * _n2(x, z, 0.3, 121.0))
	return WATER_DEPTH * smoothstep(shelf, _SHORE_WIDTH, shore)


## Visual height of a natural or water tile top at a world point.
static func _top_height(ctx: _Ctx, x: float, z: float) -> float:
	var h: float = clampf(_n2(x, z, _HEIGHT_FREQUENCY, 3.0) * HEIGHT_AMPLITUDE * 1.7, -HEIGHT_AMPLITUDE, HEIGHT_AMPLITUDE * 0.8)
	if ctx.type == "water":
		h -= _bed_depth(ctx, x, z)
	if not ctx.hard.is_empty():
		h *= smoothstep(0.0, _FADE_WIDTH, _nearest(ctx.hard, x, z, _FADE_WIDTH))
	return ctx.roof + h


static func _make_ctx(tile: Dictionary, by_cell: Dictionary) -> _Ctx:
	var ctx: _Ctx = _Ctx.new()
	ctx.cell = tile["cell"] as Vector2i
	ctx.type = str(tile["type"])
	ctx.roof = _roof_of(tile)
	ctx.x0 = float(ctx.cell.x) * TILE_SIZE
	ctx.z0 = float(ctx.cell.y) * TILE_SIZE
	ctx.by_cell = by_cell
	var is_water: bool = ctx.type == "water"
	var blends: bool = _BLEND_TYPES.has(ctx.type)
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var other: Vector2i = ctx.cell + Vector2i(dx, dz)
			var own: bool = dx == 0 and dz == 0
			var rect: Rect2 = _cell_rect(other)
			if not by_cell.has(other):
				# The sea runs on past the edge of the level; land flattens toward it.
				if not is_water:
					ctx.hard.append(rect)
				continue
			var other_type: String = _type_at(other, by_cell)
			var level: bool = is_equal_approx(_roof_at(other, by_cell), ctx.roof)
			var soft: bool = level and (other_type == "water" or _NATURAL_TYPES.has(other_type))
			if not own and not soft:
				ctx.hard.append(rect)
			if is_water and other_type != "water":
				ctx.shore.append(rect)
			if blends and level and _BLEND_TYPES.has(other_type):
				ctx.blend_rects.append(rect)
				ctx.blend_types.append(other_type)
				if other_type != ctx.type:
					ctx.mixed = true
	return ctx


## A natural (grass, ground, sand) or water-bed top: a grid with height noise, smooth normals and blended colours.
static func _emit_soft_top(surf: _Surf, ctx: _Ctx) -> void:
	var n: int = TOP_SUBDIVISIONS
	var s: float = TILE_SIZE / float(n)
	var side: int = n + 3
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(side * side)
	for j: int in range(side):
		for i: int in range(side):
			heights[j * side + i] = _top_height(ctx, ctx.x0 + float(i - 1) * s, ctx.z0 + float(j - 1) * s)
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colours: Array[Color] = []
	for j: int in range(n + 1):
		for i: int in range(n + 1):
			var at: int = (j + 1) * side + (i + 1)
			var x: float = ctx.x0 + float(i) * s
			var z: float = ctx.z0 + float(j) * s
			points.append(Vector3(x, heights[at], z))
			normals.append(Vector3(heights[at - 1] - heights[at + 1], 2.0 * s, heights[at - side] - heights[at + side]).normalized())
			var colour: Color = _colour_at(ctx, x, z)
			if ctx.type == "water":
				colour = colour.lerp(Palette.DEEP_OCEAN, 0.75 * _bed_depth(ctx, x, z) / WATER_DEPTH)
			colour.a = 1.0
			colours.append(colour)
	var row: int = n + 1
	for j: int in range(n):
		for i: int in range(n):
			var a: int = j * row + i
			var b: int = a + row
			var c: int = b + 1
			var d: int = a + 1
			# Alternate the diagonal so the triangulation has no grain.
			if (i + j) % 2 == 0:
				surf.tri(points[a], points[b], points[c], normals[a], normals[b], normals[c], colours[a], colours[b], colours[c])
				surf.tri(points[a], points[c], points[d], normals[a], normals[c], normals[d], colours[a], colours[c], colours[d])
			else:
				surf.tri(points[a], points[b], points[d], normals[a], normals[b], normals[d], colours[a], colours[b], colours[d])
				surf.tri(points[b], points[c], points[d], normals[b], normals[c], normals[d], colours[b], colours[c], colours[d])


## True when the tile at `other` carries on the paving of `ctx` (same kind of stone top at the same height).
static func _paving_continues(ctx: _Ctx, other: Vector2i) -> bool:
	return _type_at(other, ctx.by_cell) == ctx.type and is_equal_approx(_roof_at(other, ctx.by_cell), ctx.roof)


## The paving slab that covers the 1 m cell (i, j): its rectangle in 1 m cells.
static func _slab_of(i: int, j: int) -> Rect2i:
	var pi: int = posmod(i, 4)
	var pj: int = posmod(j, 4)
	for slab: Rect2i in _SLABS:
		for dz: int in range(slab.size.y):
			for dx: int in range(slab.size.x):
				if posmod(slab.position.x + dx, 4) == pi and posmod(slab.position.y + dz, 4) == pj:
					return Rect2i(i - dx, j - dz, slab.size.x, slab.size.y)
	return Rect2i(i, j, 1, 1)


## A stone top (stone_floor, or the roof of a wall): bevelled paving slabs. Slabs run across tile borders where
## the paving continues; elsewhere they are cut at the border and bevelled there.
static func _emit_paved_top(surf: _Surf, ctx: _Ctx) -> void:
	var slabs: Array[Rect2i] = []
	for dj: int in range(2):
		for di: int in range(2):
			var slab: Rect2i = _slab_of(ctx.cell.x * 2 + di, ctx.cell.y * 2 + dj)
			if not slabs.has(slab):
				slabs.append(slab)
	var x1: float = ctx.x0 + TILE_SIZE
	var z1: float = ctx.z0 + TILE_SIZE
	var cont_w: bool = _paving_continues(ctx, ctx.cell + Vector2i(-1, 0))
	var cont_e: bool = _paving_continues(ctx, ctx.cell + Vector2i(1, 0))
	var cont_n: bool = _paving_continues(ctx, ctx.cell + Vector2i(0, -1))
	var cont_s: bool = _paving_continues(ctx, ctx.cell + Vector2i(0, 1))
	var low: float = ctx.roof - JOINT_DEPTH
	for slab: Rect2i in slabs:
		var sx0: float = float(slab.position.x)
		var sz0: float = float(slab.position.y)
		var sx1: float = float(slab.end.x)
		var sz1: float = float(slab.end.y)
		var ax: float = maxf(sx0, ctx.x0)
		var az: float = maxf(sz0, ctx.z0)
		var bx: float = minf(sx1, x1)
		var bz: float = minf(sz1, z1)
		# A side is bevelled when it is a real edge of the slab, or a cut where the paving stops.
		var ia: float = 0.0 if sx0 < ctx.x0 and cont_w else _SLAB_INSET
		var ib: float = 0.0 if sx1 > x1 and cont_e else _SLAB_INSET
		var ja: float = 0.0 if sz0 < ctx.z0 and cont_n else _SLAB_INSET
		var jb: float = 0.0 if sz1 > z1 and cont_s else _SLAB_INSET
		var tone: float = 0.93 + 0.14 * _hash01(slab.position.x, slab.position.y, 7)
		var p00: Vector3 = Vector3(ax + ia, ctx.roof, az + ja)
		var p01: Vector3 = Vector3(ax + ia, ctx.roof, bz - jb)
		var p11: Vector3 = Vector3(bx - ib, ctx.roof, bz - jb)
		var p10: Vector3 = Vector3(bx - ib, ctx.roof, az + ja)
		var c00: Color = _scaled(_colour_at(ctx, p00.x, p00.z), tone)
		var c01: Color = _scaled(_colour_at(ctx, p01.x, p01.z), tone)
		var c11: Color = _scaled(_colour_at(ctx, p11.x, p11.z), tone)
		var c10: Color = _scaled(_colour_at(ctx, p10.x, p10.z), tone)
		surf.flat(p00, p01, p11, p10, Vector3.UP, c00, c01, c11, c10)
		var slope: float = JOINT_DEPTH / _SLAB_INSET
		if ia > 0.0:
			var nw: Vector3 = Vector3(-slope, 1.0, 0.0).normalized()
			surf.flat(Vector3(ax, low, az), Vector3(ax, low, bz), p01, p00, nw, _scaled(c00, 0.72), _scaled(c01, 0.72), c01, c00)
		if ib > 0.0:
			var ne: Vector3 = Vector3(slope, 1.0, 0.0).normalized()
			surf.flat(Vector3(bx, low, az), Vector3(bx, low, bz), p11, p10, ne, _scaled(c10, 0.72), _scaled(c11, 0.72), c11, c10)
		if ja > 0.0:
			var nn: Vector3 = Vector3(0.0, 1.0, -slope).normalized()
			surf.flat(Vector3(ax, low, az), Vector3(bx, low, az), p10, p00, nn, _scaled(c00, 0.72), _scaled(c10, 0.72), c10, c00)
		if jb > 0.0:
			var ns: Vector3 = Vector3(0.0, 1.0, slope).normalized()
			surf.flat(Vector3(ax, low, bz), Vector3(bx, low, bz), p11, p01, ns, _scaled(c01, 0.72), _scaled(c11, 0.72), c11, c01)


## The moulding profile of a built face as [lower, upper]: points (offset out of the face, height) from the
## bottom up. Between the two runs the ashlar. Walls get a plinth and a layered cornice; low drops get a kerb.
static func _face_profile(low: float, roof: float, grand: bool) -> Array[PackedVector2Array]:
	var lower: PackedVector2Array = PackedVector2Array()
	var upper: PackedVector2Array = PackedVector2Array()
	var h: float = roof - low
	var g: float = JOINT_DEPTH
	if h < 0.75:
		lower.append(Vector2(0.0, low))
		if h >= 0.45:
			lower.append(Vector2(0.0, low + 0.04))
			lower.append(Vector2(-g, low + 0.04))
			upper.append(Vector2(-g, roof - 0.17))
		upper.append(Vector2(0.0, roof - 0.17))
		upper.append(Vector2(0.05, roof - 0.13))
		upper.append(Vector2(0.05, roof - 0.035))
		upper.append(Vector2(0.02, roof))
		upper.append(Vector2(0.0, roof - g))
		return [lower, upper]
	var s: float = 1.0 if grand and h >= 1.4 else 0.7
	var out: float = CORNICE_OVERHANG * s
	lower.append(Vector2(0.1 * s, low))
	lower.append(Vector2(0.1 * s, low + 0.28 * s))
	lower.append(Vector2(0.0, low + 0.4 * s))
	lower.append(Vector2(-g, low + 0.4 * s))
	upper.append(Vector2(-g, roof - 0.46 * s))
	upper.append(Vector2(0.0, roof - 0.46 * s))
	upper.append(Vector2(0.05 * s, roof - 0.4 * s))
	upper.append(Vector2(0.05 * s, roof - 0.3 * s))
	upper.append(Vector2(out, roof - 0.2 * s))
	upper.append(Vector2(out, roof - 0.045))
	upper.append(Vector2(out - 0.035, roof))
	upper.append(Vector2(0.0, roof - g))
	return [lower, upper]


## Extrudes a moulding profile along a tile edge. Where the edge ends at an outward corner (`rise` is the height
## the corner is exposed above) the moulding is mitred round it.
static func _emit_moulding(surf: _Surf, profile: PackedVector2Array, p0: Vector3, t: Vector3, out: Vector3, rise_start: float, rise_end: float, tile_type: String) -> void:
	var p1: Vector3 = p0 + t * TILE_SIZE
	for k: int in range(profile.size() - 1):
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		var mid: float = (a.y + b.y) * 0.5
		var ms: float = 1.0 if mid > rise_start else 0.0
		var me: float = 1.0 if mid > rise_end else 0.0
		var normal: Vector3 = (out * (b.y - a.y) - Vector3.UP * (b.x - a.x)).normalized()
		var sa: Vector3 = p0 + out * a.x - t * (a.x * ms) + Vector3.UP * a.y
		var sb: Vector3 = p0 + out * b.x - t * (b.x * ms) + Vector3.UP * b.y
		var ea: Vector3 = p1 + out * a.x + t * (a.x * me) + Vector3.UP * a.y
		var eb: Vector3 = p1 + out * b.x + t * (b.x * me) + Vector3.UP * b.y
		# Mouldings are a touch lighter than the wall so the cornice reads; recesses are darker.
		var tone_a: float = 1.06 if a.x > 0.0 else (0.72 if a.x < 0.0 else 1.0)
		var tone_b: float = 1.06 if b.x > 0.0 else (0.72 if b.x < 0.0 else 1.0)
		surf.flat(sa, ea, eb, sb, normal,
				_scaled(_type_colour_at(tile_type, sa.x + sa.y, sa.z), tone_a), _scaled(_type_colour_at(tile_type, ea.x + ea.y, ea.z), tone_a),
				_scaled(_type_colour_at(tile_type, eb.x + eb.y, eb.z), tone_b), _scaled(_type_colour_at(tile_type, sb.x + sb.y, sb.z), tone_b))


## Ashlar between heights ya and yb of a built face: staggered courses of bevelled blocks whose joints line up
## with the neighbouring tiles' faces. `rise_start` / `rise_end` are the roof heights of the tiles beyond each end:
## an equal roof means the wall runs on (a joint may sit on the border), a lower one an outward corner (mitred).
static func _emit_ashlar(surf: _Surf, ya: float, yb: float, roof: float, p0: Vector3, t: Vector3, out: Vector3, rise_start: float, rise_end: float, tile_type: String) -> void:
	var joint_start: bool = is_equal_approx(rise_start, roof)
	var joint_end: bool = is_equal_approx(rise_end, roof)
	if yb - ya < 0.05:
		return
	var levels: PackedFloat32Array = PackedFloat32Array([ya])
	var course: int = ceili((ya + 0.2) / _COURSE_HEIGHT)
	while float(course) * _COURSE_HEIGHT < yb - 0.2:
		levels.append(float(course) * _COURSE_HEIGHT)
		course += 1
	levels.append(yb)
	var w0: float = p0.x * t.x + p0.z * t.z
	var axis: int = 0 if t.x > 0.5 else 1
	for row: int in range(levels.size() - 1):
		var y0: float = levels[row]
		var y1: float = levels[row + 1]
		var index: int = floori((y0 + y1) * 0.5 / _COURSE_HEIGHT)
		var shift: float = _BLOCK_LENGTH * 0.5 * float(posmod(index, 2))
		var cuts: PackedFloat32Array = PackedFloat32Array([0.0])
		var joint: float = ceilf((w0 - shift) / _BLOCK_LENGTH + 0.001) * _BLOCK_LENGTH + shift
		while joint < w0 + TILE_SIZE - 0.001:
			cuts.append(joint - w0)
			joint += _BLOCK_LENGTH
		cuts.append(TILE_SIZE)
		var on_joint: bool = is_zero_approx(fposmod(w0 - shift, _BLOCK_LENGTH))
		for k: int in range(cuts.size() - 1):
			var u0: float = cuts[k]
			var u1: float = cuts[k + 1]
			var bevel0: bool = k > 0 or (on_joint and joint_start)
			var bevel1: bool = k < cuts.size() - 2 or (on_joint and joint_end)
			var i0: float = _BLOCK_INSET if bevel0 else 0.0
			var i1: float = _BLOCK_INSET if bevel1 else 0.0
			var block: int = floori((w0 + (u0 + u1) * 0.5 - shift) / _BLOCK_LENGTH)
			var tone: float = 0.91 + 0.16 * _hash01(block, index, 13 + axis + roundi(p0.x * (1.0 - t.x) + p0.z * (1.0 - t.z)))
			var a: Vector3 = p0 + t * (u0 + i0) + Vector3.UP * (y0 + _BLOCK_INSET)
			var b: Vector3 = p0 + t * (u1 - i1) + Vector3.UP * (y0 + _BLOCK_INSET)
			var c: Vector3 = p0 + t * (u1 - i1) + Vector3.UP * (y1 - _BLOCK_INSET)
			var d: Vector3 = p0 + t * (u0 + i0) + Vector3.UP * (y1 - _BLOCK_INSET)
			var ca: Color = _scaled(_type_colour_at(tile_type, a.x + a.y, a.z), tone)
			var cb: Color = _scaled(_type_colour_at(tile_type, b.x + b.y, b.z), tone)
			var cc: Color = _scaled(_type_colour_at(tile_type, c.x + c.y, c.z), tone)
			var cd: Color = _scaled(_type_colour_at(tile_type, d.x + d.y, d.z), tone)
			surf.flat(a, b, c, d, out, ca, cb, cc, cd)
			# The joint: four strips falling back from the block's face to the bottom of the groove.
			var oa: Vector3 = p0 + t * u0 + Vector3.UP * y0 - out * JOINT_DEPTH
			var ob: Vector3 = p0 + t * u1 + Vector3.UP * y0 - out * JOINT_DEPTH
			var oc: Vector3 = p0 + t * u1 + Vector3.UP * y1 - out * JOINT_DEPTH
			var od: Vector3 = p0 + t * u0 + Vector3.UP * y1 - out * JOINT_DEPTH
			var shade: float = 0.68
			var slope: float = JOINT_DEPTH / _BLOCK_INSET
			# At an outward corner the bottom of the groove is mitred with the face round the corner.
			if k == 0 and not bevel0 and (y0 + y1) * 0.5 > rise_start:
				oa += t * JOINT_DEPTH
				od += t * JOINT_DEPTH
			if k == cuts.size() - 2 and not bevel1 and (y0 + y1) * 0.5 > rise_end:
				ob -= t * JOINT_DEPTH
				oc -= t * JOINT_DEPTH
			surf.flat(oa, ob, b, a, (out - Vector3.UP * slope).normalized(), _scaled(ca, shade), _scaled(cb, shade), cb, ca)
			surf.flat(od, oc, c, d, (out + Vector3.UP * slope).normalized(), _scaled(cd, shade), _scaled(cc, shade), cc, cd)
			if bevel0:
				surf.flat(oa, od, d, a, (out - t * slope).normalized(), _scaled(ca, shade), _scaled(cd, shade), cd, ca)
			if bevel1:
				surf.flat(ob, oc, c, b, (out + t * slope).normalized(), _scaled(cb, shade), _scaled(cc, shade), cc, cb)


## How far a rocky face bulges out of its plane at (u along the edge, height y).
static func _cliff_bulge(p0: Vector3, t: Vector3, u: float, y: float, roof: float, fade_start: bool, fade_end: bool) -> float:
	var at: Vector3 = p0 + t * u
	var n: float = 0.5 + 0.5 * _n2(at.x + y * 0.6, at.z - y * 0.4, 0.85, 81.0 + y * 1.1)
	var bulge: float = _CLIFF_BULGE * n * smoothstep(0.0, 0.3, roof - y)
	if fade_start:
		bulge *= smoothstep(0.0, 0.45, u)
	if fade_end:
		bulge *= smoothstep(0.0, 0.45, TILE_SIZE - u)
	return bulge


## A natural drop: a rock face that bulges below the lip, with the colour of the top running a little way down.
static func _emit_cliff(surf: _Surf, ctx: _Ctx, low: float, p0: Vector3, t: Vector3, out: Vector3, fade_start: bool, fade_end: bool) -> void:
	var rows: int = maxi(1, roundi((ctx.roof - low) / _CLIFF_ROW))
	var cols: int = _CLIFF_COLUMNS
	var du: float = TILE_SIZE / float(cols)
	var dy: float = (ctx.roof - low) / float(rows)
	var rock: Color = Palette.BARK.lerp(Palette.STONE, 0.72)
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colours: Array[Color] = []
	var e: float = 0.08
	for r: int in range(rows + 1):
		for c: int in range(cols + 1):
			var u: float = float(c) * du
			var y: float = low + float(r) * dy
			var bulge: float = _cliff_bulge(p0, t, u, y, ctx.roof, fade_start, fade_end)
			var point: Vector3 = p0 + t * u + Vector3.UP * y + out * bulge
			var slope_u: float = (_cliff_bulge(p0, t, u + e, y, ctx.roof, fade_start, fade_end) - _cliff_bulge(p0, t, u - e, y, ctx.roof, fade_start, fade_end)) / (2.0 * e)
			var slope_y: float = (_cliff_bulge(p0, t, u, minf(y + e, ctx.roof), ctx.roof, fade_start, fade_end) - _cliff_bulge(p0, t, u, y - e, ctx.roof, fade_start, fade_end)) / (2.0 * e)
			points.append(point)
			normals.append((out - t * slope_u - Vector3.UP * slope_y).normalized())
			var strata: float = _n2(point.x * 0.3 + point.z * 0.3, y, 2.2, 95.0)
			var stone: Color = _scaled(rock, 0.84 + 0.16 * strata + 0.1 * _n2(point.x, point.z, 0.5, 99.0))
			var top: Color = _type_colour_at(ctx.type, point.x, point.z)
			var colour: Color = top.lerp(stone, smoothstep(0.02, 0.22, ctx.roof - y + 0.05 * strata))
			colour.a = 1.0
			colours.append(colour)
	var row: int = cols + 1
	for r: int in range(rows):
		for c: int in range(cols):
			var a: int = r * row + c
			var b: int = a + 1
			var d: int = a + row
			var cc: int = d + 1
			surf.quad(points[a], points[b], points[cc], points[d], normals[a], normals[b], normals[cc], normals[d], colours[a], colours[b], colours[cc], colours[d])


## The side faces of a tile: one toward every neighbour whose roof is lower (a void neighbour counts as height
## 0). Higher or equal neighbours hide the face. Walls and stone floors get built stone, natural tiles a cliff.
static func _emit_faces(surf: _Surf, ctx: _Ctx) -> void:
	var x1: float = ctx.x0 + TILE_SIZE
	var z1: float = ctx.z0 + TILE_SIZE
	var built: bool = ctx.type == "wall" or ctx.type == "stone_floor"
	for dir: Vector2i in _DIRECTIONS:
		var low: float = _roof_at(ctx.cell + dir, ctx.by_cell)
		if ctx.roof <= low:
			continue
		var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
		var along: Vector2i = Vector2i(0, 1) if dir.x != 0 else Vector2i(1, 0)
		var t: Vector3 = Vector3(float(along.x), 0.0, float(along.y))
		var p0: Vector3 = Vector3(x1 if dir.x == 1 else ctx.x0, 0.0, z1 if dir.y == 1 else ctx.z0)
		var before: Vector2i = ctx.cell - along
		var after: Vector2i = ctx.cell + along
		var roof_before: float = _roof_at(before, ctx.by_cell)
		var roof_after: float = _roof_at(after, ctx.by_cell)
		if built:
			var profile: Array[PackedVector2Array] = _face_profile(low, ctx.roof, ctx.type == "wall")
			_emit_moulding(surf, profile[0], p0, t, out, roof_before, roof_after, ctx.type)
			_emit_moulding(surf, profile[1], p0, t, out, roof_before, roof_after, ctx.type)
			var ya: float = profile[0][profile[0].size() - 1].y
			var yb: float = profile[1][0].y
			_emit_ashlar(surf, ya, yb, ctx.roof, p0, t, out, roof_before, roof_after, ctx.type)
		else:
			var same_before: bool = is_equal_approx(roof_before, ctx.roof) and _NATURAL_TYPES.has(_type_at(before, ctx.by_cell))
			var same_after: bool = is_equal_approx(roof_after, ctx.roof) and _NATURAL_TYPES.has(_type_at(after, ctx.by_cell))
			_emit_cliff(surf, ctx, low, p0, t, out, not same_before, not same_after)


static func _surf_for(surfaces: Dictionary, tile_type: String) -> _Surf:
	if not surfaces.has(tile_type):
		surfaces[tile_type] = _Surf.new()
	return surfaces[tile_type] as _Surf


## The deep floor under a water surface: one dark sheet just below the lowest point of the tile beds, so the sea
## beyond the level's edge has a bottom to tint and fade against.
static func _emit_deep_floor(surf: _Surf, from: Vector2, to: Vector2, y: float) -> void:
	var deep: Color = _tile_colour("water").lerp(Palette.DEEP_OCEAN, 0.75)
	surf.flat(Vector3(from.x, y, from.y), Vector3(from.x, y, to.y), Vector3(to.x, y, to.y), Vector3(to.x, y, from.y), Vector3.UP, deep, deep, deep, deep)


## One WaterKit surface per water level: over the box round that level's water tiles, lowered by WATER_DROP, and
## run on past the level's edge wherever the water reaches it.
static func _build_water(tiles: Array[Dictionary], level_id: String, bed: _Surf) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var boxes: Dictionary[int, Rect2i] = {}
	var all: Rect2i = Rect2i()
	var first: bool = true
	for tile: Dictionary in tiles:
		var cell_box: Rect2i = Rect2i(tile["cell"] as Vector2i, Vector2i.ONE)
		all = cell_box if first else all.merge(cell_box)
		first = false
		if str(tile["type"]) != "water":
			continue
		var step: int = tile["step"] as int
		boxes[step] = (boxes[step] as Rect2i).merge(cell_box) if boxes.has(step) else cell_box
	var mood: StringName = Look.mood_for_level(StringName(level_id))
	var depth_effects: bool = Look.resolve_preset() != &"low"
	var steps: Array[int] = boxes.keys()
	steps.sort()
	for step: int in steps:
		var box: Rect2i = boxes[step]
		var from: Vector2 = Vector2(box.position) * TILE_SIZE
		var to: Vector2 = Vector2(box.end) * TILE_SIZE
		if box.position.x == all.position.x:
			from.x -= WATER_OVERRUN
		if box.position.y == all.position.y:
			from.y -= WATER_OVERRUN
		if box.end.x == all.end.x:
			to.x += WATER_OVERRUN
		if box.end.y == all.end.y:
			to.y += WATER_OVERRUN
		var water: MeshInstance3D = WaterKit.ocean(to - from, mood, WATER_WAVE_SCALE, depth_effects)
		water.name = "Water_%d" % step
		water.position = Vector3((from.x + to.x) * 0.5, float(step) * STEP_HEIGHT - WATER_DROP, (from.y + to.y) * 0.5)
		water.set_meta("step", step)
		_emit_deep_floor(bed, from, to, float(step) * STEP_HEIGHT - WATER_DEPTH - HEIGHT_AMPLITUDE - 0.05)
		out.append(water)
	return out


## One mesh per tile type (tops, plus faces only where the ground drops), the water surfaces, and per-tile colliders.
static func _build_tiles(tiles: Array[Dictionary], level_id: String = "") -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Tiles"
	var by_cell: Dictionary = {}
	for tile: Dictionary in tiles:
		by_cell[tile["cell"] as Vector2i] = tile
	var surfaces: Dictionary = {}
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	for tile: Dictionary in tiles:
		var tile_type: String = str(tile["type"])
		var cell: Vector2i = tile["cell"] as Vector2i
		var top: float = (tile["step"] as int) * STEP_HEIGHT
		var centre_x: float = float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5
		var centre_z: float = float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5
		var size: Vector3 = Vector3(TILE_SIZE, SLAB_DEPTH, TILE_SIZE)
		var centre_y: float = top - SLAB_DEPTH * 0.5
		if tile_type == "wall":
			var height: float = _roof_of(tile)
			size = Vector3(TILE_SIZE, height, TILE_SIZE)
			centre_y = height * 0.5
		var ctx: _Ctx = _make_ctx(tile, by_cell)
		var surf: _Surf = _surf_for(surfaces, tile_type)
		if tile_type == "wall" or tile_type == "stone_floor":
			_emit_paved_top(surf, ctx)
		else:
			_emit_soft_top(surf, ctx)
		_emit_faces(surf, ctx)
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.name = "Tile_%d_%d" % [cell.x, cell.y]
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape_node.shape = box
		shape_node.position = Vector3(centre_x, centre_y, centre_z)
		floor_body.add_child(shape_node)
	var waters: Array[MeshInstance3D] = []
	if surfaces.has("water"):
		waters = _build_water(tiles, level_id, surfaces["water"] as _Surf)
	for tile_type: String in TILE_TYPES:
		if not surfaces.has(tile_type):
			continue
		var surf: _Surf = surfaces[tile_type] as _Surf
		var mesh: ArrayMesh = ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surf.verts
		arrays[Mesh.ARRAY_NORMAL] = surf.normals
		arrays[Mesh.ARRAY_COLOR] = surf.colours
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(0, String(TILE_MATERIAL))
		mesh.surface_set_material(0, Materials.get_material(TILE_MATERIAL))
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = "Tiles_%s" % tile_type
		mesh_node.mesh = mesh
		group.add_child(mesh_node)
	for water: MeshInstance3D in waters:
		group.add_child(water)
	group.add_child(floor_body)
	return group


# --- props -------------------------------------------------------------------------------------------------

static func _architecture_node(kind: String, size: Vector3, seed_value: int, opts: Dictionary) -> Node3D:
	match kind:
		"wall":
			return ArchitectureKit.wall(size, seed_value, opts)
		"tier_house":
			return ArchitectureKit.tier_house(size, seed_value, opts)
		"pillar":
			return ArchitectureKit.pillar(size, seed_value, opts)
		"gopuram":
			return ArchitectureKit.gopuram(size, seed_value, opts)
		"stairs":
			return ArchitectureKit.stairs(size, seed_value, opts)
		_:
			return ArchitectureKit.rooftop(size, seed_value, opts)


static func _nature_node(kind: String, size: Vector3, seed_value: int) -> Node3D:
	var holder: Node3D = Node3D.new()
	var mesh_node: MeshInstance3D
	match kind:
		"ashoka_tree":
			mesh_node = NatureKit.ashoka_tree(seed_value, size.y)
		"shimshapa_tree":
			mesh_node = NatureKit.shimshapa_tree(seed_value, size.y)
		"rock":
			mesh_node = NatureKit.rock(size, seed_value)
		"cliff":
			mesh_node = NatureKit.cliff(size, seed_value)
		_:
			mesh_node = NatureKit.grass_patch(seed_value, maxf(size.x, size.z) * 0.5)
	holder.add_child(mesh_node)
	var body: StaticBody3D = _nature_collider(kind, size)
	if body != null:
		holder.add_child(body)
	return holder


## Solid shapes for the nature props, which are meshes only: a trunk cylinder for trees, a box for rocks and cliffs.
## Grass patches stay walk-through. Rocks sit centred on the prop origin, trees and cliffs stand on it.
static func _nature_collider(kind: String, size: Vector3) -> StaticBody3D:
	var shape: Shape3D = null
	var centre: Vector3 = Vector3.ZERO
	match kind:
		"rock":
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(size.x * ROCK_FILL, size.y * ROCK_FILL, size.z * ROCK_FILL)
			shape = box
		"cliff":
			var cliff_box: BoxShape3D = BoxShape3D.new()
			cliff_box.size = Vector3(size.x * CLIFF_FILL, size.y, size.z * CLIFF_FILL)
			shape = cliff_box
			centre = Vector3(0.0, size.y * 0.5, 0.0)
		"ashoka_tree", "shimshapa_tree":
			var trunk: CylinderShape3D = CylinderShape3D.new()
			trunk.radius = clampf(size.y * TRUNK_RADIUS_PER_HEIGHT, TRUNK_RADIUS_MIN, TRUNK_RADIUS_MAX)
			trunk.height = maxf(size.y, 1.0)
			shape = trunk
			centre = Vector3(0.0, trunk.height * 0.5, 0.0)
		_:
			return null
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collider"
	body.collision_layer = Layers.mask([Layers.WORLD])
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.shape = shape
	shape_node.position = centre
	body.add_child(shape_node)
	return body


static func _build_props(props: Array[Dictionary], heights: Dictionary) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Props"
	for index: int in range(props.size()):
		var prop: Dictionary = props[index]
		var kind: String = str(prop.get("kind", ""))
		var is_architecture: bool = ARCHITECTURE_KINDS.has(kind)
		if not is_architecture and not NATURE_KINDS.has(kind):
			push_warning("LevelBuilder: unknown prop kind '%s', prop skipped" % kind)
			continue
		var size: Vector3 = _vec3_of(prop.get("size", null), DEFAULT_PROP_SIZE)
		var opts: Dictionary = {}
		var raw_opts: Variant = prop.get("opts", null)
		if raw_opts is Dictionary:
			opts = raw_opts as Dictionary
		var seed_value: int = (prop.get("seed", 0) as int)
		var node: Node3D
		if is_architecture:
			node = _architecture_node(kind, size, seed_value, opts)
		else:
			node = _nature_node(kind, size, seed_value)
		var footprint: Vector2 = _vec2_of(prop.get("pos", null))
		var base_y: float = _height_at(footprint, heights)
		# Props are centred on their size box, so lift them to stand on the tile surface.
		var lift: float = size.y * 0.5 if is_architecture or kind == "rock" else 0.0
		node.name = "Prop_%d_%s" % [index, kind]
		node.position = Vector3(footprint.x, base_y + lift, footprint.y)
		node.rotation.y = deg_to_rad(float(_snap_right_angle(prop.get("rot", 0) as int)))
		node.set_meta("kind", kind)
		node.set_meta("flammable", _flag(opts, "flammable"))
		node.set_meta("protected", _flag(opts, "protected"))
		group.add_child(node)
	return group


# --- spawns, triggers, shrines ----------------------------------------------------------------------------

static func _build_spawns(spawns: Array[Dictionary], heights: Dictionary) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Spawns"
	for index: int in range(spawns.size()):
		var spawn: Dictionary = spawns[index]
		var spawn_id: String = str(spawn.get("id", "spawn_%d" % index))
		var marker: Marker3D = Marker3D.new()
		marker.name = spawn_id
		var footprint: Vector2 = _vec2_of(spawn.get("pos", null))
		marker.position = Vector3(footprint.x, _height_at(footprint, heights), footprint.y)
		var facing: int = (spawn.get("facing", 0) as int)
		marker.rotation.y = deg_to_rad(float(facing))
		marker.set_meta("id", spawn_id)
		marker.set_meta("kind", str(spawn.get("kind", "player")))
		marker.set_meta("facing", facing)
		group.add_child(marker)
	return group


static func _build_triggers(triggers: Array[Dictionary], heights: Dictionary) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Triggers"
	for index: int in range(triggers.size()):
		var trigger: Dictionary = triggers[index]
		var trigger_id: String = str(trigger.get("id", "trigger_%d" % index))
		var size: Vector3 = _vec3_of(trigger.get("size", null), DEFAULT_TRIGGER_SIZE)
		var footprint: Vector2 = _vec2_of(trigger.get("pos", null))
		var area: Area3D = Area3D.new()
		area.name = trigger_id
		area.monitoring = true
		area.position = Vector3(footprint.x, _height_at(footprint, heights) + size.y * 0.5, footprint.y)
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape_node.shape = box
		area.add_child(shape_node)
		area.set_meta("id", trigger_id)
		area.set_meta("shape", "box")
		area.set_meta("on_enter", str(trigger.get("on_enter", "")))
		area.set_meta("once", (trigger.get("once", false) as bool))
		group.add_child(area)
	return group


static func _build_shrines(shrines: Array[Dictionary], heights: Dictionary) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Shrines"
	for index: int in range(shrines.size()):
		var shrine: Dictionary = shrines[index]
		var shrine_id: String = str(shrine.get("id", "shrine_%d" % index))
		var marker: Marker3D = Marker3D.new()
		marker.name = shrine_id
		var footprint: Vector2 = _vec2_of(shrine.get("pos", null))
		marker.position = Vector3(footprint.x, _height_at(footprint, heights), footprint.y)
		marker.set_meta("id", shrine_id)
		group.add_child(marker)
	return group


# --- navigation --------------------------------------------------------------------------------------------

## One navmesh quad per walkable tile, at its surface height. Quads are wound counter-clockwise seen from above.
static func _build_navigation(tiles: Array[Dictionary], nav_enabled: bool) -> NavigationRegion3D:
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	if not nav_enabled:
		return region
	var mesh: NavigationMesh = NavigationMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	for tile: Dictionary in tiles:
		if not WALKABLE_TYPES.has(str(tile["type"])):
			continue
		var cell: Vector2i = tile["cell"] as Vector2i
		var y: float = (tile["step"] as int) * STEP_HEIGHT
		var x0: float = float(cell.x) * TILE_SIZE
		var z0: float = float(cell.y) * TILE_SIZE
		var x1: float = x0 + TILE_SIZE
		var z1: float = z0 + TILE_SIZE
		var first: int = vertices.size()
		vertices.append(Vector3(x0, y, z0))
		vertices.append(Vector3(x0, y, z1))
		vertices.append(Vector3(x1, y, z1))
		vertices.append(Vector3(x1, y, z0))
		mesh.add_polygon(PackedInt32Array([first, first + 1, first + 2, first + 3]))
	mesh.set_vertices(vertices)
	region.navigation_mesh = mesh
	return region
