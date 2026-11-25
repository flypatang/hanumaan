class_name ArchitectureKit
extends RefCounted
## Procedural architecture props (DESIGN §9, M09): wall, tier_house, pillar, gopuram, stairs and rooftop.
## Every prop is a Node3D with one MeshInstance3D (flat-shaded, built with MeshKit) and StaticBody3D collision
## boxes. The same rng_seed always gives the same geometry. Each root carries the metadata flags
## 'flammable' and 'protected' (both default to false, settable through the optional opts Dictionary).

const _SIDES: int = 10
const _COURSE_HEIGHT: float = 0.5


## A stone wall made of courses of blocks. The seed decides where the block joints fall.
static func wall(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var courses: int = maxi(1, roundi(dims.y / _COURSE_HEIGHT))
	var course_h: float = dims.y / float(courses)
	for c: int in range(courses):
		var y: float = -dims.y * 0.5 + course_h * (float(c) + 0.5)
		var x: float = -dims.x * 0.5
		var end_x: float = dims.x * 0.5
		while x < end_x - 0.0001:
			var block_len: float = minf(rng.randf_range(0.6, 1.2), end_x - x)
			var block: ArrayMesh = MeshKit.box(Vector3(block_len, course_h, dims.z), Palette.STONE)
			parts.append(_part(block, Vector3(x + block_len * 0.5, y, 0.0)))
			x += block_len
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A house of stacked, shrinking tiers under a roof. Gold cornices sit on each tier's top edge.
static func tier_house(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var base_h: float = dims.y * 0.6
	var base_top: float = -dims.y * 0.5 + base_h
	parts.append(_part(MeshKit.box(Vector3(dims.x, base_h, dims.z), Palette.STONE), Vector3(0.0, -dims.y * 0.5 + base_h * 0.5, 0.0)))
	var tiers: int = rng.randi_range(2, 3)
	var roof_h: float = dims.y - base_h
	var tier_h: float = roof_h / float(tiers)
	var shrink: float = rng.randf_range(0.12, 0.18)
	for i: int in range(tiers):
		var width: float = dims.x * (1.0 - shrink * float(i + 1))
		var depth: float = dims.z * (1.0 - shrink * float(i + 1))
		var tier_bottom: float = base_top + tier_h * float(i)
		var tier_top: float = tier_bottom + tier_h
		parts.append(_part(MeshKit.box(Vector3(width, tier_h, depth), Palette.STONE), Vector3(0.0, tier_bottom + tier_h * 0.5, 0.0)))
		parts.append(_part(MeshKit.box(Vector3(width + 0.12, 0.08, depth + 0.12), Palette.GOLD), Vector3(0.0, tier_top, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A round stone column with a square base and a shaft turned by a small seeded yaw.
static func pillar(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var radius: float = minf(dims.x, dims.z) * 0.5
	var base_h: float = dims.y * 0.05
	var shaft_h: float = dims.y - base_h * 2.0
	var yaw: float = rng.randf_range(0.0, TAU / float(_SIDES))
	parts.append(_part(MeshKit.box(Vector3(radius * 2.4, base_h, radius * 2.4), Palette.STONE), Vector3(0.0, -dims.y * 0.5 + base_h * 0.5, 0.0)))
	parts.append(_part(MeshKit.cylinder(radius, radius, shaft_h, _SIDES, Palette.STONE), Vector3.ZERO, Vector3(0.0, yaw, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(radius * 2.4, base_h, radius * 2.4), Palette.STONE), Vector3(0.0, dims.y * 0.5 - base_h * 0.5, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A tiered temple tower (gopuram): shrinking stone tiers, a gold cornice on each, and a gold finial on top.
static func gopuram(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var colliders: Array[Dictionary] = []
	var tiers: int = rng.randi_range(3, 5)
	var finial_h: float = dims.y * 0.12
	var tiers_h: float = dims.y - finial_h
	var tier_h: float = tiers_h / float(tiers)
	var bottom: float = -dims.y * 0.5
	for i: int in range(tiers):
		var t: float = float(i) / float(maxi(1, tiers - 1))
		var width: float = dims.x * (1.0 - 0.5 * t)
		var depth: float = dims.z * (1.0 - 0.5 * t)
		var centre_y: float = bottom + tier_h * (float(i) + 0.5)
		parts.append(_part(MeshKit.box(Vector3(width, tier_h, depth), Palette.STONE), Vector3(0.0, centre_y, 0.0)))
		parts.append(_part(MeshKit.box(Vector3(width + 0.14, 0.08, depth + 0.14), Palette.GOLD), Vector3(0.0, bottom + tier_h * float(i + 1), 0.0)))
		colliders.append(_collider(Vector3(width, tier_h, depth), Vector3(0.0, centre_y, 0.0)))
	var finial_base: float = bottom + tiers_h
	parts.append(_part(MeshKit.cone(dims.x * 0.15, finial_h, 6, Palette.GOLD), Vector3(0.0, finial_base + finial_h * 0.5, 0.0)))
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A flight of stone steps that rises along +Z. The seed picks the step count (4 to 6).
static func stairs(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var colliders: Array[Dictionary] = []
	var steps: int = rng.randi_range(4, 6)
	var step_d: float = dims.z / float(steps)
	var step_rise: float = dims.y / float(steps)
	for i: int in range(steps):
		var top: float = step_rise * float(i + 1)
		var centre_z: float = -dims.z * 0.5 + step_d * (float(i) + 0.5)
		var centre_y: float = -dims.y * 0.5 + top * 0.5
		var step_size: Vector3 = Vector3(dims.x, top, step_d)
		var centre: Vector3 = Vector3(0.0, centre_y, centre_z)
		parts.append(_part(MeshKit.box(step_size, Palette.STONE), centre))
		colliders.append(_collider(step_size, centre))
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A stone deck with a gable roof running along Z. The seed sets the eave overhang.
static func rooftop(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var colliders: Array[Dictionary] = []
	var deck_h: float = dims.y * 0.2
	var deck_centre: Vector3 = Vector3(0.0, -dims.y * 0.5 + deck_h * 0.5, 0.0)
	var deck_size: Vector3 = Vector3(dims.x, deck_h, dims.z)
	parts.append(_part(MeshKit.box(deck_size, Palette.STONE), deck_centre))
	colliders.append(_collider(deck_size, deck_centre))
	var overhang: float = rng.randf_range(0.0, 0.2)
	var half: float = dims.x * 0.5 + overhang
	var base: float = -dims.y * 0.5 + deck_h
	var rise: float = dims.y - deck_h
	var slope_len: float = sqrt(half * half + rise * rise)
	var angle: float = atan2(rise, half)
	var slab_size: Vector3 = Vector3(slope_len, 0.15, dims.z)
	var left_centre: Vector3 = Vector3(-half * 0.5, base + rise * 0.5, 0.0)
	var right_centre: Vector3 = Vector3(half * 0.5, base + rise * 0.5, 0.0)
	parts.append(_part(MeshKit.box(slab_size, Palette.STONE), left_centre, Vector3(0.0, 0.0, angle)))
	parts.append(_part(MeshKit.box(slab_size, Palette.STONE), right_centre, Vector3(0.0, 0.0, -angle)))
	colliders.append(_collider(slab_size, left_centre, Vector3(0.0, 0.0, angle)))
	colliders.append(_collider(slab_size, right_centre, Vector3(0.0, 0.0, -angle)))
	return _assemble(MeshKit.merge(parts), colliders, opts)


static func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


static func _positive(size: Vector3) -> Vector3:
	return Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01))


static func _part(mesh: ArrayMesh, pos: Vector3, euler: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D(Basis.from_euler(euler), pos)}


static func _collider(size: Vector3, pos: Vector3, euler: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"size": size, "pos": pos, "euler": euler}


static func _assemble(mesh: ArrayMesh, colliders: Array[Dictionary], opts: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = MeshKit.flat_material()
	root.add_child(visual)
	for c: Dictionary in colliders:
		var body: StaticBody3D = StaticBody3D.new()
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = c["size"] as Vector3
		shape_node.shape = box
		shape_node.transform = Transform3D(Basis.from_euler(c["euler"] as Vector3), c["pos"] as Vector3)
		body.add_child(shape_node)
		root.add_child(body)
	root.set_meta("flammable", _flag(opts, "flammable"))
	root.set_meta("protected", _flag(opts, "protected"))
	return root


static func _flag(opts: Dictionary, key: String) -> bool:
	var value: Variant = opts.get(key, false)
	return value is bool and (value as bool)
