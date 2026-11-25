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


## A house with a pillared veranda, overhanging eaves per tier and gold trim lines.
static func tier_house(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var bottom: float = -dims.y * 0.5
	var plinth_h: float = dims.y * 0.06
	parts.append(_part(MeshKit.box(Vector3(dims.x, plinth_h, dims.z), Palette.STONE), Vector3(0.0, bottom + plinth_h * 0.5, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(dims.x + 0.02, 0.05, dims.z + 0.02), Palette.GOLD), Vector3(0.0, bottom + plinth_h, 0.0)))
	var veranda_h: float = dims.y * 0.34
	var body_w: float = dims.x * 0.8
	var body_d: float = dims.z * 0.8
	var veranda_y: float = bottom + plinth_h
	parts.append(_part(MeshKit.box(Vector3(body_w, veranda_h, body_d), Palette.STONE), Vector3(0.0, veranda_y + veranda_h * 0.5, -dims.z * 0.1)))
	var pillar_r: float = minf(dims.x, dims.z) * 0.04
	var count: int = 4
	var front_z: float = dims.z * 0.5 - pillar_r * 2.0
	for i: int in range(count):
		var px: float = -body_w * 0.5 + body_w * float(i) / float(count - 1)
		parts.append(_part(MeshKit.cylinder(pillar_r, pillar_r * 1.1, veranda_h, 6, Palette.STONE), Vector3(px, veranda_y + veranda_h * 0.5, front_z)))
		parts.append(_part(MeshKit.box(Vector3(pillar_r * 3.0, 0.06, pillar_r * 3.0), Palette.GOLD), Vector3(px, veranda_y + veranda_h, front_z)))
	var tiers: int = rng.randi_range(2, 3)
	var roof_base: float = veranda_y + veranda_h
	var tier_h: float = (bottom + dims.y - roof_base) / float(tiers)
	var shrink: float = rng.randf_range(0.14, 0.2)
	for i: int in range(tiers):
		var width: float = dims.x * (1.0 - shrink * float(i))
		var depth: float = dims.z * (1.0 - shrink * float(i))
		var y0: float = roof_base + tier_h * float(i)
		var eave_h: float = tier_h * 0.22
		parts.append(_part(MeshKit.box(Vector3(width, eave_h, depth), Palette.SINDOOR), Vector3(0.0, y0 + eave_h * 0.5, 0.0)))
		parts.append(_part(MeshKit.box(Vector3(width + 0.02, 0.05, depth + 0.02), Palette.GOLD), Vector3(0.0, y0 + eave_h, 0.0)))
		var wall_h: float = tier_h - eave_h
		parts.append(_part(MeshKit.box(Vector3(width * 0.8, wall_h, depth * 0.8), Palette.STONE), Vector3(0.0, y0 + eave_h + wall_h * 0.5, 0.0)))
		parts.append(_part(MeshKit.box(Vector3(width * 0.8 + 0.04, 0.04, depth * 0.8 + 0.04), Palette.GOLD), Vector3(0.0, y0 + eave_h + wall_h * 0.5, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A column with a stepped base, a fluted shaft, and a capital with a gold band and abacus.
static func pillar(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var radius: float = minf(dims.x, dims.z) * 0.4
	var unit: float = dims.y * 0.05
	var yaw: float = rng.randf_range(0.0, TAU / 12.0)
	var bottom: float = -dims.y * 0.5
	var w: float = minf(dims.x, dims.z)
	parts.append(_part(MeshKit.box(Vector3(w, unit, w), Palette.STONE), Vector3(0.0, bottom + unit * 0.5, 0.0)))
	parts.append(_part(MeshKit.cylinder(radius * 1.25, radius * 1.35, unit, 12, Palette.STONE), Vector3(0.0, bottom + unit * 1.5, 0.0), Vector3(0.0, yaw, 0.0)))
	var shaft_h: float = dims.y - unit * 5.0
	var shaft_y: float = bottom + unit * 2.0 + shaft_h * 0.5
	parts.append(_part(MeshKit.cylinder(radius * 0.85, radius, shaft_h, 12, Palette.STONE), Vector3(0.0, shaft_y, 0.0), Vector3(0.0, yaw, 0.0)))
	for i: int in range(4):
		var a: float = float(i) * TAU / 4.0 + yaw
		parts.append(_part(MeshKit.box(Vector3(radius * 0.18, shaft_h, radius * 0.18), Palette.STONE), Vector3(cos(a) * radius * 0.95, shaft_y, sin(a) * radius * 0.95), Vector3(0.0, -a, 0.0)))
	var top: float = bottom + unit * 2.0 + shaft_h
	parts.append(_part(MeshKit.cylinder(radius * 0.95, radius * 0.95, unit * 0.5, 12, Palette.GOLD), Vector3(0.0, top + unit * 0.25, 0.0), Vector3(0.0, yaw, 0.0)))
	parts.append(_part(MeshKit.cylinder(radius * 1.5, radius * 0.95, unit * 1.5, 12, Palette.STONE), Vector3(0.0, top + unit * 1.25, 0.0), Vector3(0.0, yaw, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(w, unit * 1.0, w), Palette.STONE), Vector3(0.0, dims.y * 0.5 - unit * 0.5, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return _assemble(MeshKit.merge(parts), colliders, opts)


## A tall tapering temple tower of 5-7 tiers. Each tier has a gold cornice and repeated sindoor niches;
## the crown is a barrel vault with gold kalasha finials.
static func gopuram(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	var colliders: Array[Dictionary] = []
	var tiers: int = rng.randi_range(5, 7)
	var top_scale: float = 0.38
	var finial_h: float = dims.y * 0.07
	var crown_r: float = dims.x * top_scale * 0.4
	var tiers_h: float = dims.y - finial_h - crown_r
	var tier_h: float = tiers_h / float(tiers)
	var bottom: float = -dims.y * 0.5
	for i: int in range(tiers):
		var t: float = float(i) / float(tiers)
		var t_top: float = float(i + 1) / float(tiers)
		var width: float = dims.x * (1.0 - (1.0 - top_scale) * t) * 0.94
		var depth: float = dims.z * (1.0 - (1.0 - top_scale) * t) * 0.94
		var w_top: float = dims.x * (1.0 - (1.0 - top_scale) * t_top) * 0.94
		var d_top: float = dims.z * (1.0 - (1.0 - top_scale) * t_top) * 0.94
		var y0: float = bottom + tier_h * float(i)
		var cornice_h: float = tier_h * 0.14
		var body_h: float = tier_h - cornice_h
		var body_y: float = y0 + body_h * 0.5
		var body_w: float = (width + w_top) * 0.5
		var body_d: float = (depth + d_top) * 0.5
		parts.append(_part(MeshKit.box(Vector3(body_w, body_h, body_d), Palette.STONE), Vector3(0.0, body_y, 0.0)))
		colliders.append(_collider(Vector3(width, tier_h, depth), Vector3(0.0, y0 + tier_h * 0.5, 0.0)))
		parts.append(_part(MeshKit.box(Vector3(width + 0.12, cornice_h, depth + 0.12), Palette.GOLD), Vector3(0.0, y0 + body_h + cornice_h * 0.5, 0.0)))
		var niches: int = maxi(2, roundi(body_w / 0.9))
		var niche_w: float = minf(0.3, body_w / float(niches) * 0.5)
		var niche_h: float = body_h * 0.5
		for n: int in range(niches):
			var f: float = (float(n) + 0.5) / float(niches) - 0.5
			parts.append(_part(MeshKit.box(Vector3(niche_w, niche_h, 0.05), Palette.SINDOOR), Vector3(f * body_w, body_y, body_d * 0.5 + 0.01)))
			parts.append(_part(MeshKit.box(Vector3(niche_w, niche_h, 0.05), Palette.SINDOOR), Vector3(f * body_w, body_y, -body_d * 0.5 - 0.01)))
			parts.append(_part(MeshKit.box(Vector3(0.05, niche_h, niche_w), Palette.SINDOOR), Vector3(body_w * 0.5 + 0.01, body_y, f * body_d)))
			parts.append(_part(MeshKit.box(Vector3(0.05, niche_h, niche_w), Palette.SINDOOR), Vector3(-body_w * 0.5 - 0.01, body_y, f * body_d)))
	var top_w: float = dims.x * top_scale * 0.94
	var top_d: float = dims.z * top_scale * 0.94
	var crown_base: float = bottom + tiers_h
	var vault_r: float = minf(crown_r, top_w * 0.5)
	parts.append(_part(MeshKit.cylinder(vault_r, vault_r, top_d, 8, Palette.STONE), Vector3(0.0, crown_base, 0.0), Vector3(PI * 0.5, 0.0, 0.0)))
	parts.append(_part(MeshKit.cylinder(vault_r * 0.45, vault_r * 0.45, top_d + 0.1, 6, Palette.GOLD), Vector3(0.0, crown_base + vault_r * 0.85, 0.0), Vector3(PI * 0.5, 0.0, 0.0)))
	var fin_y: float = crown_base + vault_r + finial_h * 0.5 - 0.02
	for fz: float in [-top_d * 0.5 + 0.1, 0.0, top_d * 0.5 - 0.1]:
		parts.append(_part(MeshKit.sphere(finial_h * 0.28, 4, 6, Palette.GOLD), Vector3(0.0, fin_y - finial_h * 0.15, fz)))
		parts.append(_part(MeshKit.cone(finial_h * 0.2, finial_h * 0.55, 6, Palette.GOLD), Vector3(0.0, fin_y + finial_h * 0.22, fz)))
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
