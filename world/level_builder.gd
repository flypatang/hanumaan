class_name LevelBuilder
extends RefCounted
## Builds a level scene from levels/<id>.json (DESIGN §5, §9 M15). The format is in levels/SCHEMA.md.
## Stateless: every function is static, so `LevelBuilder.build(data)` is the whole API.
## Tiles are merged into one mesh per tile type. Every walkable tile becomes one navmesh quad.
## Systems talk through the built nodes' metadata and signals; this module never touches other modules' children.

const TILE_SIZE: float = 2.0
const STEP_HEIGHT: float = 0.5
const SLAB_DEPTH: float = 1.0
const WALL_EXTRA_HEIGHT: float = 2.0
const DEFAULT_PROP_SIZE: Vector3 = Vector3(2.0, 3.0, 2.0)
const DEFAULT_TRIGGER_SIZE: Vector3 = Vector3(2.0, 2.0, 2.0)

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
	root.add_child(_build_tiles(tiles))
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

static func _tile_colour(tile_type: String) -> Color:
	match tile_type:
		"ground":
			return Palette.BARK
		"stone_floor":
			return Palette.STONE
		"grass":
			return Palette.GROVE_GREEN
		"sand":
			return Palette.STONE.lerp(Palette.GOLD, 0.35)
		"water":
			return Palette.DEEP_OCEAN
		_:
			return Palette.STONE


## Roof height of a tile: its surface, or the top of the solid block for walls.
static func _roof_of(tile: Dictionary) -> float:
	var top: float = (tile["step"] as int) * STEP_HEIGHT
	if str(tile["type"]) == "wall":
		return top + WALL_EXTRA_HEIGHT
	return top


## Deterministic per-tile value factor in [0.96, 1.04], seeded by the tile's x and z.
static func _jitter_factor(cell: Vector2i) -> float:
	var h: int = posmod(cell.x * 374761393 + cell.y * 668265263, 1000003)
	h = posmod(h * h + cell.x * 31 + cell.y * 17, 1000003)
	var unit: float = float(h) / 1000002.0
	return 1.0 + (unit * 2.0 - 1.0) * 0.04


static func _jittered(colour: Color, cell: Vector2i) -> Color:
	var factor: float = _jitter_factor(cell)
	return Color(clampf(colour.r * factor, 0.0, 1.0), clampf(colour.g * factor, 0.0, 1.0), clampf(colour.b * factor, 0.0, 1.0), colour.a)


## Adds one flat quad with the given outward normal. Godot draws clockwise triangles (seen from outside) as front
## faces, so the emitted winding is the one whose right-hand cross product points against `normal`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, colour: Color) -> void:
	var flip: bool = (b - a).cross(c - a).dot(normal) > 0.0
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	if flip:
		corners = [a, c, b, a, d, c]
	for corner: Vector3 in corners:
		st.set_normal(normal)
		st.set_color(colour)
		st.add_vertex(corner)


## Emits one tile into its type's surface: a flat top at the roof height, plus a side face toward every
## neighbour whose roof is lower (or a void neighbour, which counts as height 0). Higher or equal neighbours
## hide the face, so no faces are drawn between tiles at the same height.
static func _emit_tile_surface(st: SurfaceTool, tile: Dictionary, by_cell: Dictionary) -> void:
	var cell: Vector2i = tile["cell"] as Vector2i
	var roof: float = _roof_of(tile)
	var colour: Color = _jittered(_tile_colour(str(tile["type"])), cell)
	var x0: float = float(cell.x) * TILE_SIZE
	var x1: float = x0 + TILE_SIZE
	var z0: float = float(cell.y) * TILE_SIZE
	var z1: float = z0 + TILE_SIZE
	_quad(st, Vector3(x0, roof, z0), Vector3(x0, roof, z1), Vector3(x1, roof, z1), Vector3(x1, roof, z0), Vector3.UP, colour)
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var low: float = 0.0
		var neighbour_cell: Vector2i = cell + dir
		if by_cell.has(neighbour_cell):
			low = _roof_of(by_cell[neighbour_cell] as Dictionary)
		if roof <= low:
			continue
		if dir.x == 1:
			_quad(st, Vector3(x1, low, z0), Vector3(x1, low, z1), Vector3(x1, roof, z1), Vector3(x1, roof, z0), Vector3.RIGHT, colour)
		elif dir.x == -1:
			_quad(st, Vector3(x0, low, z1), Vector3(x0, low, z0), Vector3(x0, roof, z0), Vector3(x0, roof, z1), Vector3.LEFT, colour)
		elif dir.y == 1:
			_quad(st, Vector3(x1, low, z1), Vector3(x0, low, z1), Vector3(x0, roof, z1), Vector3(x1, roof, z1), Vector3.BACK, colour)
		else:
			_quad(st, Vector3(x0, low, z0), Vector3(x1, low, z0), Vector3(x1, roof, z0), Vector3(x0, roof, z0), Vector3.FORWARD, colour)


## One continuous flat-top mesh per tile type (cliff faces only where the ground drops), plus per-tile colliders.
static func _build_tiles(tiles: Array[Dictionary]) -> Node3D:
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
		if not surfaces.has(tile_type):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[tile_type] = st
		_emit_tile_surface(surfaces[tile_type] as SurfaceTool, tile, by_cell)
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.name = "Tile_%d_%d" % [cell.x, cell.y]
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape_node.shape = box
		shape_node.position = Vector3(centre_x, centre_y, centre_z)
		floor_body.add_child(shape_node)
	for tile_type: String in TILE_TYPES:
		if not surfaces.has(tile_type):
			continue
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = "Tiles_%s" % tile_type
		mesh_node.mesh = (surfaces[tile_type] as SurfaceTool).commit()
		mesh_node.material_override = MeshKit.flat_material()
		group.add_child(mesh_node)
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
	return holder


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
