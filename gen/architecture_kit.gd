class_name ArchitectureKit
extends RefCounted
## Procedural Lanka architecture (DESIGN §9 M09, art direction v2 in docs/ART.md "Geometry", module B4):
## wall, tier_house, pillar, gopuram, stairs and rooftop.
##
## Every prop is a Node3D with ONE MeshInstance3D and StaticBody3D box colliders. The mesh has one surface per
## painterly material kind (MeshKit.multi -> Materials: stone, lacquer, gold, wood, cloth, foliage); there is no
## material_override. Stone is bevelled, cornices are layered (stone fillet, red lacquer band, gold lip), relief
## bands repeat gold studs, openings are ogee arches with jali screens, and towers end in kalasha finials.
## Cloth (banners, awnings) carries a wind weight in the vertex colour alpha, so it sways.
##
## The same size and rng_seed always give the same geometry (built meshes are cached and shared between
## instances). Each root carries the metadata flags 'flammable' and 'protected' (both default to false, settable
## through the optional opts Dictionary). Every prop stays under 6000 triangles.

const _STONE: StringName = &"stone"
const _LACQUER: StringName = &"lacquer"
const _GOLD: StringName = &"gold"
const _WOOD: StringName = &"wood"
const _CLOTH: StringName = &"cloth"
const _FOLIAGE: StringName = &"foliage"

const _GOPURAM_TIERS: int = 7
const _GOPURAM_TOP_SCALE: float = 0.38
const _CACHE_LIMIT: int = 512

## White stone of Lanka's palaces (a tint of Palette.STONE).
static var _marble: Color = Palette.STONE.lightened(0.58)
## Shadowed recess behind arches and jali screens.
static var _recess: Color = Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_ARMOR, 0.4)
## Dark red lacquer for doors and deep bands.
static var _deep_red: Color = Palette.RAKSHASA_ARMOR
static var _terracotta: Color = Palette.ASHOKA_RED.lerp(Palette.BARK, 0.45)
static var _cache: Dictionary = {}


## A rampart of bevelled ashlar courses on a plinth, with a gold-studded lacquer band, a gold coping and
## petal-shaped merlons. It runs along the longer of X and Z. The seed decides where the block joints fall.
static func wall(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("wall", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_wall(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


## A palatial mansion of 2-3 storeys: studded plinth, arched windows with jali screens, an arched door, engaged
## veranda columns, layered cornices, balconies with pierced parapets, hanging banners, a merlon parapet and a
## domed rooftop pavilion with a kalasha.
static func tier_house(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("tier_house", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_tier_house(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


## A column: stepped plinth, gold base ring, panelled dado, fluted shaft, cushion capital, lacquer brackets
## and an abacus. The seed turns the flutes.
static func pillar(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("pillar", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_pillar(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


## A tall tapering temple gate tower of 7 tiers (one box collider per tier). Each tier has a layered cornice,
## arched niches holding gold buds and corner finials; a gate portal stands on both broad faces; the crown is a
## gold barrel vault along the longer side with lacquer ribs, gable arches and a row of kalasha finials.
static func gopuram(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("gopuram", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_gopuram(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


## A flight of stone steps that rises along +Z, with marble treads, a red runner edged in gold and two newel
## posts. The seed picks the step count (4 to 6); every step has its own collider.
static func stairs(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("stairs", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_stairs(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


## A flat roof terrace: a deck (the only collider, level to walk on) with an inlaid floor, low pierced parapets
## with a gap in the middle of every side, corner posts with finials, a striped cloth awning on posts over a
## rug, potted plants and a brass lamp. The seed places the awning, the pots and the lamp.
static func rooftop(size: Vector3, rng_seed: int, opts: Dictionary = {}) -> Node3D:
	var dims: Vector3 = _positive(size)
	var key: String = _key("rooftop", dims, rng_seed)
	if not _cache.has(key):
		_store(key, _build_rooftop(dims, _rng(rng_seed)))
	return _instance(_cache[key] as Dictionary, opts)


# --- builders ----------------------------------------------------------------------------------------------

static func _build_wall(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var along_z: bool = dims.z > dims.x
	var length: float = maxf(dims.x, dims.z)
	var thick: float = minf(dims.x, dims.z)
	var height: float = dims.y
	var bottom: float = -height * 0.5
	var plinth_h: float = clampf(height * 0.1, 0.01, 0.45)
	var crest_h: float = clampf(height * 0.15, 0.01, 0.6)
	var coping_h: float = clampf(height * 0.07, 0.01, 0.28)
	var band_h: float = clampf(height * 0.08, 0.01, 0.32)
	_box(parts, _STONE, Vector3(length, plinth_h, thick), minf(0.05, plinth_h * 0.3), Palette.STONE, Vector3(0.0, bottom + plinth_h * 0.5, 0.0))
	# Ashlar field.
	var inset: float = minf(0.12, thick * 0.12)
	var field_w: float = length - inset
	var field_t: float = thick - inset
	var field_h: float = height - plinth_h - crest_h - coping_h - band_h
	var courses: int = clampi(roundi(field_h / 0.5), 1, 6)
	var course_h: float = field_h / float(courses)
	var len_scale: float = maxf(1.0, field_w / 7.0)
	for c: int in range(courses):
		var y: float = bottom + plinth_h + course_h * (float(c) + 0.5)
		var x: float = -field_w * 0.5
		var end_x: float = field_w * 0.5
		while x < end_x - 0.0001:
			var block_len: float = minf(rng.randf_range(0.6, 1.2) * len_scale, end_x - x)
			if end_x - x - block_len < 0.3 * len_scale:
				block_len = end_x - x
			var tone: float = rng.randf()
			var colour: Color = Palette.STONE.lerp(_marble, tone * 0.45) if tone > 0.35 else Palette.STONE.darkened(tone * 0.25)
			_box(parts, _STONE, Vector3(block_len, course_h, field_t), minf(0.04, course_h * 0.12), colour, Vector3(x + block_len * 0.5, y, 0.0))
			x += block_len
	# Relief band: red lacquer with a row of gold studs on both faces.
	var band_y: float = bottom + plinth_h + field_h + band_h * 0.5
	var band_proud: float = inset * 0.1
	_box(parts, _LACQUER, Vector3(field_w + band_proud * 2.0, band_h, field_t + band_proud * 2.0), 0.0, Palette.SINDOOR, Vector3(0.0, band_y, 0.0))
	var studs: int = clampi(roundi(length / 0.6), 2, 16)
	var half_band_t: float = field_t * 0.5 + band_proud
	# The studs stay inside the wall's size box: their tips reach the coping's edge at most.
	var stud_r: float = minf(band_h * 0.36, (thick * 0.5 - half_band_t) / 0.66)
	for face: int in [0, 2]:
		_stud_row(parts, face, length * 0.5, half_band_t, band_y, field_w, studs, stud_r)
	var merlon_inset: float = minf(0.24, thick * 0.9) if thick >= 1.0 else 0.0
	# Coping: a marble fillet under a gold lip that spans the full size.
	var coping_y: float = band_y + band_h * 0.5
	_box(parts, _STONE, Vector3(length - inset * 0.5, coping_h * 0.5, thick - inset * 0.5), 0.02, _marble, Vector3(0.0, coping_y + coping_h * 0.25, 0.0))
	_box(parts, _GOLD, Vector3(length, coping_h * 0.5, thick), minf(0.03, coping_h * 0.2), Palette.GOLD, Vector3(0.0, coping_y + coping_h * 0.75, 0.0))
	_box(parts, _STONE, Vector3(length - inset, coping_h * 0.2, maxf(thick - merlon_inset * 2.0, thick * 0.2)), 0.0, Palette.STONE.lerp(_marble, 0.5), Vector3(0.0, coping_y + coping_h * 0.92, 0.0))
	# Merlons: one row on a thin wall, a row on each edge of a thick one (a wall-walk between them).
	var merlon_y: float = coping_y + coping_h
	var merlon_t: float = minf(0.24, thick * 0.9)
	var merlons: int = clampi(roundi(length / 0.8), 2, 12)
	var merlon_w: float = length / float(merlons) * 0.64
	var merlon: ArrayMesh = _arch_slab(_arch_profile(merlon_w, crest_h, crest_h * 0.6, 4), merlon_t, _marble, true, true)
	var rows: Array[float] = [0.0]
	if thick >= 1.0:
		rows = [-(thick - merlon_t) * 0.5, (thick - merlon_t) * 0.5]
	for row_z: float in rows:
		for m: int in range(merlons):
			var mx: float = ((float(m) + 0.5) / float(merlons) - 0.5) * length
			_put(parts, _STONE, merlon, Transform3D(Basis(), Vector3(mx, merlon_y, row_z - merlon_t * 0.5)))
	if along_z:
		_rotate_parts(parts, PI * 0.5)
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


static func _build_tier_house(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var w: float = dims.x
	var d: float = dims.z
	var h: float = dims.y
	var bottom: float = -h * 0.5
	var tiers: int = rng.randi_range(2, 3)
	var shrink: float = rng.randf_range(0.14, 0.2)
	var banner_colour: Color = Palette.SAFFRON if rng.randf() < 0.5 else Palette.SINDOOR
	var unit: float = minf(w, d)
	var over: float = unit * 0.045
	# Plinth with a band of gold studs.
	var plinth_h: float = clampf(h * 0.06, 0.01, 0.45)
	_box(parts, _STONE, Vector3(w, plinth_h, d), minf(0.05, plinth_h * 0.3), Palette.STONE, Vector3(0.0, bottom + plinth_h * 0.5, 0.0))
	for face: int in range(4):
		var plinth_len: float = _face_len(face, w, d)
		_stud_row(parts, face, w * 0.5, d * 0.5, bottom + plinth_h * 0.5, plinth_len * 0.92, clampi(roundi(plinth_len / 0.6), 3, 7), plinth_h * 0.26)
	var crown_h: float = h * 0.2
	var storey_h: float = (h - plinth_h - crown_h) / float(tiers)
	var top_w: float = w
	var top_d: float = d
	for i: int in range(tiers):
		var f: float = 0.9 - shrink * float(i)
		var body_w: float = w * f
		var body_d: float = d * f
		var y0: float = bottom + plinth_h + storey_h * float(i)
		var cornice_h: float = storey_h * 0.16
		var wall_h: float = storey_h - cornice_h
		var wall_colour: Color = Palette.STONE.lerp(_marble, 0.6) if i == 0 else _marble
		_box(parts, _STONE, Vector3(body_w, wall_h, body_d), 0.04, wall_colour, Vector3(0.0, y0 + wall_h * 0.5, 0.0))
		# Dado band and corner pilasters with gold capitals.
		_box(parts, _LACQUER, Vector3(body_w + 0.03, wall_h * 0.09, body_d + 0.03), 0.0, Palette.SINDOOR, Vector3(0.0, y0 + wall_h * 0.045, 0.0))
		_box(parts, _GOLD, Vector3(body_w + 0.025, wall_h * 0.025, body_d + 0.025), 0.0, Palette.GOLD, Vector3(0.0, y0 + wall_h * 0.2, 0.0))
		var pil: float = clampf(unit * f * 0.07, 0.05, 0.4)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector3 = Vector3(sx * (body_w - pil) * 0.5, y0 + wall_h * 0.5, sz * (body_d - pil) * 0.5)
				_box(parts, _STONE, Vector3(pil + 0.06, wall_h, pil + 0.06), 0.025 if i == 0 else 0.0, Palette.STONE, corner)
				_box(parts, _GOLD, Vector3(pil + 0.12, wall_h * 0.06, pil + 0.12), 0.0, Palette.GOLD, corner + Vector3(0.0, wall_h * 0.44, 0.0))
		# Arched windows with jali screens; the ground floor front has the door in the middle.
		for face: int in range(4):
			var face_len: float = _face_len(face, body_w, body_d) - pil * 2.0
			var count: int = clampi(roundi(face_len / 1.7), 1, 3 if i < 2 else 2)
			var has_door: bool = i == 0 and face == 0
			if has_door and count % 2 == 0:
				count += 1
			var slot: float = face_len / float(count)
			var win_h: float = wall_h * 0.6
			var win_w: float = minf(slot * 0.52, win_h * 0.58)
			var window: Dictionary = _opening(win_w, win_h, Palette.GOLD, _recess, 0.06, 4, true, true)
			for k: int in range(count):
				var along: float = ((float(k) + 0.5) / float(count) - 0.5) * face_len
				@warning_ignore("integer_division")
				if has_door and k == count / 2:
					var door_h: float = wall_h * 0.84
					var door_w: float = minf(slot * 0.62, door_h * 0.6)
					var door: Dictionary = _opening(door_w, door_h, Palette.GOLD, _deep_red, 0.08, 5, false, true)
					var door_xf: Transform3D = _face(face, body_w * 0.5, body_d * 0.5, along, y0, 0.0)
					_put_opening(parts, door, door_xf)
					_put(parts, _GOLD, MeshKit.box(Vector3(door_w * 0.05, door_h * 0.6, 0.02), Palette.GOLD), door_xf * Transform3D(Basis(), Vector3(0.0, door_h * 0.3, 0.03)))
				else:
					_put_opening(parts, window, _face(face, body_w * 0.5, body_d * 0.5, along, y0 + wall_h * 0.22, 0.0))
			# Engaged veranda columns on the ground floor front, banners hanging on the sides above.
			if has_door:
				var col_r: float = maxf(over * 0.42, 0.03)
				var column: ArrayMesh = _lathe(_column_profile(col_r, wall_h), 6, _marble, true)
				for k: int in range(1, count):
					var col_along: float = (float(k) / float(count) - 0.5) * face_len
					_put(parts, _STONE, column, _face(face, body_w * 0.5, body_d * 0.5, col_along, y0, over * 0.5))
			elif i == 0 and face % 2 == 1 and tiers >= 2:
				var banner_w: float = clampf(slot * 0.26, 0.14, 0.7)
				var banner_h: float = wall_h * 0.62
				var cloth: Array[Dictionary] = [
					{"mesh": MeshKit.box(Vector3(banner_w, banner_h, 0.025), banner_colour), "transform": Transform3D()},
					{"mesh": MeshKit.box(Vector3(banner_w * 1.02, banner_h * 0.1, 0.032), Palette.GOLD.lerp(_marble, 0.5)), "transform": Transform3D(Basis(), Vector3(0.0, -banner_h * 0.32, 0.0))},
					{"mesh": _arch_slab(_arch_profile(banner_w, banner_h * 0.16, banner_h * 0.12, 2), 0.025, banner_colour, true, true), "transform": Transform3D(Basis(Vector3.BACK, PI), Vector3(0.0, -banner_h * 0.5, -0.0125))},
				]
				var banner: ArrayMesh = MeshKit.wind_weighted(MeshKit.merge(cloth), banner_h * 0.5, -banner_h * 0.66)
				for k: int in range(1, count):
					var banner_along: float = (float(k) / float(count) - 0.5) * face_len
					var banner_xf: Transform3D = _face(face, body_w * 0.5, body_d * 0.5, banner_along, y0 + wall_h - banner_h * 0.5, over * 0.6)
					_put(parts, _CLOTH, banner, banner_xf)
					_put(parts, _GOLD, MeshKit.box(Vector3(banner_w * 1.2, banner_h * 0.05, 0.05), Palette.GOLD), banner_xf * Transform3D(Basis(), Vector3(0.0, banner_h * 0.5, 0.0)))
		# Layered cornice: lacquer band under a gold lip (the lip is the balcony floor of the next storey).
		var slab_w: float = body_w + over * 2.0
		var slab_d: float = body_d + over * 2.0
		var cornice_y: float = y0 + wall_h
		_box(parts, _STONE, Vector3(body_w + over * 0.6, cornice_h * 0.25, body_d + over * 0.6), 0.015, Palette.STONE, Vector3(0.0, cornice_y + cornice_h * 0.125, 0.0))
		_box(parts, _LACQUER, Vector3(body_w + over * 1.3, cornice_h * 0.35, body_d + over * 1.3), 0.02, Palette.SINDOOR, Vector3(0.0, cornice_y + cornice_h * 0.425, 0.0))
		_box(parts, _GOLD, Vector3(slab_w, cornice_h * 0.4, slab_d), minf(0.03, cornice_h * 0.12), Palette.GOLD, Vector3(0.0, cornice_y + cornice_h * 0.8, 0.0))
		var roof_y: float = y0 + storey_h
		if i == tiers - 1:
			_box(parts, _STONE, Vector3(slab_w - 0.3 * over, cornice_h * 0.1, slab_d - 0.3 * over), 0.0, _marble, Vector3(0.0, roof_y - cornice_h * 0.03, 0.0))
			_box(parts, _LACQUER, Vector3(slab_w * 0.8, cornice_h * 0.1, slab_d * 0.8), 0.0, Palette.SINDOOR, Vector3(0.0, roof_y - cornice_h * 0.025, 0.0))
			_box(parts, _STONE, Vector3(slab_w * 0.76, cornice_h * 0.1, slab_d * 0.76), 0.0, _marble, Vector3(0.0, roof_y - cornice_h * 0.02, 0.0))
		else:
			_box(parts, _STONE, Vector3(slab_w - 0.3 * over, cornice_h * 0.1, slab_d - 0.3 * over), 0.0, Palette.STONE.lerp(_marble, 0.5), Vector3(0.0, roof_y - cornice_h * 0.03, 0.0))
		var rail_h: float = minf(0.42, storey_h * 0.2)
		for face: int in range(4):
			var edge_len: float = _face_len(face, slab_w, slab_d)
			var rail_len: float = edge_len - 0.1
			var rail_xf: Transform3D = _face(face, slab_w * 0.5, slab_d * 0.5, 0.0, roof_y, -0.07)
			if i < tiers - 1:
				# Balcony parapet: pierced marble panel with a gold rail.
				_put(parts, _STONE, MeshKit.box(Vector3(rail_len, rail_h, 0.07), _marble), rail_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.5, 0.0)))
				_put(parts, _GOLD, MeshKit.box(Vector3(rail_len + 0.04, rail_h * 0.14, 0.11), Palette.GOLD), rail_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 1.07, 0.0)))
				var holes: int = clampi(roundi(rail_len / 0.32), 3, 12)
				_put(parts, _LACQUER, _jali(rail_len * 0.94, rail_h * 0.8, holes, 1, Palette.SINDOOR), rail_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.1, 0.04)))
			else:
				# Roof parapet: a low wall crested with petal merlons.
				_put(parts, _STONE, MeshKit.box(Vector3(rail_len, rail_h * 0.45, 0.09), Palette.STONE), rail_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.225, 0.0)))
				var merlons: int = clampi(roundi(rail_len / 0.62), 3, 7)
				var merlon_w: float = rail_len / float(merlons) * 0.7
				var merlon: ArrayMesh = _arch_slab(_arch_profile(merlon_w, rail_h * 0.7, rail_h * 0.42, 2), 0.08, _marble, true, true)
				for m: int in range(merlons):
					var m_along: float = ((float(m) + 0.5) / float(merlons) - 0.5) * rail_len
					_put(parts, _STONE, merlon, rail_xf * Transform3D(Basis(), Vector3(m_along, rail_h * 0.45, -0.04)))
		top_w = slab_w
		top_d = slab_d
	# Roof: corner finials and a domed pavilion (chhatri) with a kalasha that reaches the full height.
	var roof_top: float = bottom + plinth_h + storey_h * float(tiers)
	var post: float = clampf(minf(top_w, top_d) * 0.07, 0.05, 0.35)
	var corner_finial: ArrayMesh = _lathe(_kalasha_profile(post * 0.55, crown_h * 0.3, false), 5, Palette.GOLD, true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post_pos: Vector3 = Vector3(sx * (top_w - post) * 0.5, roof_top + crown_h * 0.11, sz * (top_d - post) * 0.5)
			_box(parts, _STONE, Vector3(post, crown_h * 0.22, post), 0.02, Palette.STONE, post_pos)
			_put(parts, _GOLD, corner_finial, Transform3D(Basis(), post_pos + Vector3(0.0, crown_h * 0.11, 0.0)))
	var cw: float = minf(top_w, top_d) * 0.46
	_box(parts, _STONE, Vector3(cw * 1.1, crown_h * 0.06, cw * 1.1), 0.02, Palette.STONE, Vector3(0.0, roof_top + crown_h * 0.03, 0.0))
	var kiosk_col: ArrayMesh = _lathe(_column_profile(cw * 0.075, crown_h * 0.3), 6, _marble, true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_put(parts, _STONE, kiosk_col, Transform3D(Basis(), Vector3(sx * cw * 0.4, roof_top + crown_h * 0.06, sz * cw * 0.4)))
	_box(parts, _LACQUER, Vector3(cw * 1.16, crown_h * 0.06, cw * 1.16), 0.02, Palette.SINDOOR, Vector3(0.0, roof_top + crown_h * 0.39, 0.0))
	_box(parts, _GOLD, Vector3(cw * 1.24, crown_h * 0.025, cw * 1.24), 0.0, Palette.GOLD, Vector3(0.0, roof_top + crown_h * 0.43, 0.0))
	_box(parts, _STONE, Vector3(cw * 1.1, crown_h * 0.03, cw * 1.1), 0.0, _marble, Vector3(0.0, roof_top + crown_h * 0.455, 0.0))
	_put(parts, _GOLD, _lathe(_dome_profile(cw * 0.5, crown_h * 0.36), 12, Palette.GOLD, true), Transform3D(Basis(), Vector3(0.0, roof_top + crown_h * 0.46, 0.0)))
	var kalasha_base: float = roof_top + crown_h * 0.8
	_put(parts, _GOLD, _lathe(_kalasha_profile(cw * 0.12, bottom + h - kalasha_base, true), 6, Palette.GOLD, true), Transform3D(Basis(), Vector3(0.0, kalasha_base, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


static func _build_pillar(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var w: float = minf(dims.x, dims.z)
	var radius: float = w * 0.4
	var unit: float = dims.y * 0.05
	var yaw: float = rng.randf_range(0.0, TAU / 12.0)
	var turn: Basis = Basis(Vector3.UP, yaw)
	var y: float = -dims.y * 0.5
	# Stepped plinth.
	_box(parts, _STONE, Vector3(w, unit * 0.7, w), minf(0.05, unit * 0.2), Palette.STONE, Vector3(0.0, y + unit * 0.35, 0.0))
	y += unit * 0.7
	_box(parts, _STONE, Vector3(w * 0.88, unit * 0.5, w * 0.88), minf(0.04, unit * 0.15), _marble, Vector3(0.0, y + unit * 0.25, 0.0))
	y += unit * 0.5
	_put(parts, _GOLD, _lathe(_ring_profile(radius * 1.02, radius * 1.2, unit * 0.5), 12, Palette.GOLD, true), Transform3D(turn, Vector3(0.0, y, 0.0)))
	y += unit * 0.5
	# Dado: a square block with a lacquer panel and a gold stud on every face.
	var dado_w: float = w * 0.74
	var dado_h: float = unit * 3.2
	_box(parts, _STONE, Vector3(dado_w, dado_h, dado_w), minf(0.04, dado_w * 0.08), Palette.STONE, Vector3(0.0, y + dado_h * 0.5, 0.0))
	var stud_r: float = dado_w * 0.16
	var stud: ArrayMesh = MeshKit.cone(stud_r, stud_r * 0.6, 4, Palette.GOLD)
	for face: int in range(4):
		var panel_xf: Transform3D = _face(face, dado_w * 0.5, dado_w * 0.5, 0.0, y + dado_h * 0.5, 0.0)
		_put(parts, _LACQUER, MeshKit.box(Vector3(dado_w * 0.62, dado_h * 0.7, 0.03), Palette.SINDOOR), panel_xf)
		_put(parts, _GOLD, stud, panel_xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.015 + stud_r * 0.3)))
	y += dado_h
	_put(parts, _GOLD, _lathe(_ring_profile(radius * 0.9, radius * 1.08, unit * 0.3), 12, Palette.GOLD, true), Transform3D(turn, Vector3(0.0, y, 0.0)))
	y += unit * 0.3
	# Fluted shaft with a lacquer and gold girdle.
	var shaft_h: float = dims.y - unit * 8.2
	_put(parts, _STONE, _fluted_shaft(radius * 0.92, radius * 0.78, shaft_h, 10, _marble), Transform3D(turn, Vector3(0.0, y + shaft_h * 0.5, 0.0)))
	_put(parts, _LACQUER, _lathe(_ring_profile(radius * 0.84, radius * 0.95, unit * 0.5), 12, Palette.SINDOOR, true), Transform3D(turn, Vector3(0.0, y + shaft_h * 0.6, 0.0)))
	_put(parts, _GOLD, _lathe(_ring_profile(radius * 0.84, radius * 1.0, unit * 0.16), 12, Palette.GOLD, true), Transform3D(turn, Vector3(0.0, y + shaft_h * 0.6 + unit * 0.5, 0.0)))
	y += shaft_h
	_put(parts, _GOLD, _lathe(_ring_profile(radius * 0.78, radius * 0.96, unit * 0.3), 12, Palette.GOLD, true), Transform3D(turn, Vector3(0.0, y, 0.0)))
	y += unit * 0.3
	# Cushion capital, crossed lacquer brackets, abacus.
	var cushion: PackedVector2Array = PackedVector2Array([
		Vector2(radius * 0.8, 0.0), Vector2(radius * 1.08, unit * 0.3), Vector2(radius * 1.2, unit * 0.7),
		Vector2(radius * 1.05, unit * 1.1), Vector2(radius * 0.85, unit * 1.25), Vector2(radius * 1.15, unit * 1.6),
	])
	_put(parts, _STONE, _lathe(cushion, 12, _marble, true), Transform3D(turn, Vector3(0.0, y, 0.0)))
	y += unit * 1.6
	_box(parts, _LACQUER, Vector3(w * 0.96, unit * 0.5, w * 0.5), minf(0.03, unit * 0.12), Palette.SINDOOR, Vector3(0.0, y + unit * 0.25, 0.0))
	_box(parts, _LACQUER, Vector3(w * 0.5, unit * 0.5, w * 0.96), minf(0.03, unit * 0.12), Palette.SINDOOR, Vector3(0.0, y + unit * 0.25, 0.0))
	_box(parts, _GOLD, Vector3(w * 0.62, unit * 0.36, w * 0.62), 0.0, Palette.GOLD, Vector3(0.0, y + unit * 0.2, 0.0))
	y += unit * 0.5
	# The top is what the camera sees most: a lotus medallion inlaid in the abacus.
	var inlay: float = minf(0.006, unit * 0.05)
	_box(parts, _STONE, Vector3(w, unit * 0.6 - inlay, w), minf(0.05, unit * 0.2), Palette.STONE, Vector3(0.0, y + (unit * 0.6 - inlay) * 0.5, 0.0))
	var top_y: float = dims.y * 0.5 - inlay
	_put(parts, _GOLD, MeshKit.cylinder(w * 0.36, w * 0.36, inlay * 0.6, 12, Palette.GOLD), Transform3D(turn, Vector3(0.0, top_y + inlay * 0.3, 0.0)))
	_put(parts, _LACQUER, MeshKit.cylinder(w * 0.29, w * 0.29, inlay * 0.8, 12, Palette.SINDOOR), Transform3D(turn, Vector3(0.0, top_y + inlay * 0.4, 0.0)))
	_put(parts, _GOLD, MeshKit.cylinder(w * 0.2, w * 0.2, inlay, 8, Palette.GOLD), Transform3D(turn, Vector3(0.0, top_y + inlay * 0.5, 0.0)))
	var colliders: Array[Dictionary] = [_collider(dims, Vector3.ZERO)]
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


static func _build_gopuram(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var colliders: Array[Dictionary] = []
	var along_z: bool = dims.z > dims.x
	var long: float = maxf(dims.x, dims.z)
	var short: float = minf(dims.x, dims.z)
	var tiers: int = _GOPURAM_TIERS
	var ridge_finials: int = 3 + 2 * rng.randi_range(0, 1)
	var finial_h: float = dims.y * 0.07
	var crown_r: float = short * _GOPURAM_TOP_SCALE * 0.94 * 0.62
	var tiers_h: float = dims.y - finial_h - crown_r
	var tier_h: float = tiers_h / float(tiers)
	var bottom: float = -dims.y * 0.5
	var spacing: float = maxf(1.5, long / 4.0)
	var portal_w: float = long * 0.3
	var detail: float = clampf(long / 6.0, 0.5, 1.6)
	var widths: Array[float] = []
	var depths: Array[float] = []
	for i: int in range(tiers + 2):
		var f: float = (1.0 - (1.0 - _GOPURAM_TOP_SCALE) * float(i) / float(tiers)) * 0.94
		widths.append(long * f)
		depths.append(short * f)
	_box(parts, _STONE, Vector3(long, tier_h * 0.16, short), minf(0.05, tier_h * 0.05), Palette.STONE, Vector3(0.0, bottom + tier_h * 0.08, 0.0))
	for i: int in range(tiers):
		var y0: float = bottom + tier_h * float(i)
		var cornice_h: float = tier_h * 0.2
		var body_h: float = tier_h - cornice_h
		var body_w: float = (widths[i] + widths[i + 1]) * 0.5
		var body_d: float = (depths[i] + depths[i + 1]) * 0.5
		var body_colour: Color = Palette.STONE if i < 2 else _marble
		_box(parts, _STONE, Vector3(body_w, body_h, body_d), 0.04 * detail, body_colour, Vector3(0.0, y0 + body_h * 0.5, 0.0))
		var f0: float = (1.0 - (1.0 - _GOPURAM_TOP_SCALE) * float(i) / float(tiers)) * 0.94
		colliders.append(_collider(Vector3(dims.x * f0, tier_h, dims.z * f0), Vector3(0.0, y0 + tier_h * 0.5, 0.0)))
		# Layered cornice: red lacquer band under a gold lip.
		var lip: float = 0.06 * detail
		_box(parts, _LACQUER, Vector3((body_w + widths[i]) * 0.5, cornice_h * 0.5, (body_d + depths[i]) * 0.5), 0.02 * detail, Palette.SINDOOR, Vector3(0.0, y0 + body_h + cornice_h * 0.25, 0.0))
		_box(parts, _GOLD, Vector3(widths[i] + lip, cornice_h * 0.5, depths[i] + lip), minf(0.03 * detail, cornice_h * 0.15), Palette.GOLD, Vector3(0.0, y0 + body_h + cornice_h * 0.75, 0.0))
		# Arched niches, each with a gold bud, on all four faces.
		var niche_h: float = body_h * 0.74
		var niche_w: float = minf(spacing * 0.42, niche_h * 0.62)
		var niche: Dictionary = _opening(niche_w, niche_h, Palette.GOLD, Palette.SINDOOR, 0.05 * detail, 4, false, false)
		var bud_r: float = niche_w * 0.2
		var bud: ArrayMesh = _lathe(_kalasha_profile(bud_r, niche_h * 0.55, false), 4, Palette.GOLD, true)
		for face: int in range(4):
			var face_len: float = _face_len(face, body_w, body_d)
			var count: int = clampi(roundi(face_len / spacing), 2, 4) if face % 2 == 0 else clampi(roundi(face_len / spacing), 1, 2)
			for k: int in range(count):
				var along: float = ((float(k) + 0.5) / float(count) - 0.5) * face_len * 0.92
				if face % 2 == 0 and i < 2 and absf(along) < (portal_w + niche_w) * 0.5:
					continue
				var niche_xf: Transform3D = _face(face, body_w * 0.5, body_d * 0.5, along, y0 + body_h * 0.12, 0.0)
				_put_opening(parts, niche, niche_xf)
				if face % 2 == 0 and i < 5:
					_put(parts, _GOLD, bud, niche_xf * Transform3D(Basis(), Vector3(0.0, niche_h * 0.04, bud_r * 0.7)))
		# Corner finials on the ledge where the next tier steps in.
		if i < tiers - 1:
			var next_w: float = (widths[i + 1] + widths[i + 2]) * 0.5
			var next_d: float = (depths[i + 1] + depths[i + 2]) * 0.5
			var ledge: float = minf(widths[i] - next_w, depths[i] - next_d) * 0.5
			var kuta: ArrayMesh = _lathe(_kalasha_profile(ledge * 0.42, tier_h * 0.45, false), 4, Palette.GOLD, true)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_put(parts, _GOLD, kuta, Transform3D(Basis(), Vector3(sx * (widths[i] - ledge) * 0.5, y0 + tier_h, sz * (depths[i] - ledge) * 0.5)))
	# Gate portals on both broad faces, two tiers tall.
	var portal_h: float = tier_h * 1.9
	var portal_t: float = (short - (depths[1] + depths[2]) * 0.5) * 0.5 + 0.1
	var door_w: float = portal_w * 0.62
	var door_h: float = portal_h * 0.86
	var door: Dictionary = _opening(door_w, door_h, Palette.GOLD, _deep_red, 0.09 * detail, 6, false, true)
	var pediment_h: float = tier_h * 0.7
	var pediment: ArrayMesh = _arch_slab(_arch_profile(portal_w * 0.9, pediment_h, pediment_h * 0.75, 6), portal_t - 0.03 * detail, Palette.SINDOOR, true, false)
	var pediment_inner: ArrayMesh = _arch_slab(_arch_profile(portal_w * 0.6, pediment_h * 0.66, pediment_h * 0.5, 6), portal_t + 0.01 * detail, Palette.GOLD, true, false)
	for face: int in [0, 2]:
		var portal_xf: Transform3D = _face(face, long * 0.5, short * 0.5, 0.0, bottom, 0.0)
		_put(parts, _STONE, MeshKit.bevel_box(Vector3(portal_w, portal_h, portal_t), 0.05 * detail, Palette.STONE), portal_xf * Transform3D(Basis(), Vector3(0.0, portal_h * 0.5, -portal_t * 0.5)))
		_put_opening(parts, door, portal_xf)
		_put(parts, _GOLD, MeshKit.box(Vector3(door_w * 0.04, door_h * 0.62, 0.02), Palette.GOLD), portal_xf * Transform3D(Basis(), Vector3(0.0, door_h * 0.31, 0.03)))
		_put(parts, _GOLD, MeshKit.bevel_box(Vector3(portal_w + 0.1 * detail, tier_h * 0.1, portal_t + 0.05 * detail), 0.02 * detail, Palette.GOLD), portal_xf * Transform3D(Basis(), Vector3(0.0, portal_h + tier_h * 0.05, -portal_t * 0.5)))
		_put(parts, _LACQUER, pediment, portal_xf * Transform3D(Basis(), Vector3(0.0, portal_h + tier_h * 0.1, -portal_t)))
		_put(parts, _GOLD, pediment_inner, portal_xf * Transform3D(Basis(), Vector3(0.0, portal_h + tier_h * 0.1, -portal_t)))
	# Crown: a gold barrel vault along the long side, lacquer ribs, gable arches, a row of kalashas.
	var crown_base: float = bottom + tiers_h
	var vault_len: float = widths[tiers] * 1.04
	var vault_hz: float = depths[tiers] * 0.5
	var lie: Basis = Basis(Vector3.BACK, PI * 0.5)
	_put(parts, _GOLD, MeshKit.cylinder_smooth(1.0, 1.0, 1.0, 14, Palette.GOLD), Transform3D(lie * Basis.from_scale(Vector3(crown_r, vault_len, vault_hz)), Vector3(0.0, crown_base, 0.0)))
	var rib: ArrayMesh = MeshKit.cylinder(1.0, 1.0, 1.0, 10, Palette.SINDOOR)
	var ribs: int = ridge_finials - 1
	for r: int in range(ribs):
		var rib_x: float = (float(r + 1) / float(ribs + 1) - 0.5) * vault_len * 0.92
		_put(parts, _LACQUER, rib, Transform3D(lie * Basis.from_scale(Vector3(crown_r * 1.035, vault_len * 0.035, vault_hz * 1.05)), Vector3(rib_x, crown_base, 0.0)))
	var gable: ArrayMesh = _arch_slab(_arch_profile(vault_hz * 2.3, crown_r * 1.12, crown_r * 0.95, 6), 0.08 * detail, Palette.SINDOOR, true, false)
	var gable_inner: ArrayMesh = _arch_slab(_arch_profile(vault_hz * 1.5, crown_r * 0.8, crown_r * 0.66, 6), 0.12 * detail, Palette.GOLD, true, false)
	for face: int in [1, 3]:
		var gable_xf: Transform3D = _face(face, vault_len * 0.5, vault_hz, 0.0, crown_base - crown_r * 0.12, -0.02)
		_put(parts, _LACQUER, gable, gable_xf)
		_put(parts, _GOLD, gable_inner, gable_xf)
	var kalasha: ArrayMesh = _lathe(_kalasha_profile(finial_h * 0.27, finial_h + crown_r * 0.03, true), 6, Palette.GOLD, true)
	for k: int in range(ridge_finials):
		var kx: float = ((float(k) + 0.5) / float(ridge_finials) - 0.5) * vault_len * 0.92
		_put(parts, _GOLD, kalasha, Transform3D(Basis(), Vector3(kx, crown_base + crown_r * 0.97, 0.0)))
	if along_z:
		_rotate_parts(parts, PI * 0.5)
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


static func _build_stairs(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var colliders: Array[Dictionary] = []
	var steps: int = rng.randi_range(4, 6)
	var step_d: float = dims.z / float(steps)
	var step_rise: float = dims.y / float(steps)
	var tread_h: float = minf(0.07, step_rise * 0.3)
	var skin: float = minf(0.012, step_rise * 0.1)
	var runner_w: float = dims.x * 0.42
	var edge_w: float = minf(0.06, dims.x * 0.03)
	for i: int in range(steps):
		var top: float = step_rise * float(i + 1)
		var centre_z: float = -dims.z * 0.5 + step_d * (float(i) + 0.5)
		var centre_y: float = -dims.y * 0.5 + top * 0.5
		var step_size: Vector3 = Vector3(dims.x, top, step_d)
		var centre: Vector3 = Vector3(0.0, centre_y, centre_z)
		colliders.append(_collider(step_size, centre))
		var riser_h: float = top - tread_h - skin
		var step_top: float = -dims.y * 0.5 + top
		_box(parts, _STONE, Vector3(dims.x, riser_h, step_d), minf(0.03, step_rise * 0.1), Palette.STONE, Vector3(0.0, -dims.y * 0.5 + riser_h * 0.5, centre_z))
		_box(parts, _STONE, Vector3(dims.x, tread_h, step_d), minf(0.02, tread_h * 0.3), _marble, Vector3(0.0, step_top - skin - tread_h * 0.5, centre_z))
		# Red runner edged in gold: a strip on the tread and one down the riser.
		var front_z: float = centre_z - step_d * 0.5
		_box(parts, _LACQUER, Vector3(runner_w, skin, step_d), 0.0, Palette.SINDOOR, Vector3(0.0, step_top - skin * 0.5, centre_z))
		_box(parts, _LACQUER, Vector3(runner_w, step_rise, skin), 0.0, Palette.SINDOOR, Vector3(0.0, step_top - step_rise * 0.5, front_z + skin * 0.5))
		for sx: float in [-1.0, 1.0]:
			var edge_x: float = sx * (runner_w + edge_w) * 0.5
			_box(parts, _GOLD, Vector3(edge_w, skin, step_d), 0.0, Palette.GOLD, Vector3(edge_x, step_top - skin * 0.5, centre_z))
			_box(parts, _GOLD, Vector3(edge_w, step_rise, skin), 0.0, Palette.GOLD, Vector3(edge_x, step_top - step_rise * 0.5, front_z + skin * 0.5))
	# Newel posts with kalashas at the foot of the flight.
	var post_w: float = minf(dims.x * 0.09, step_d * 0.7)
	var post_h: float = minf(step_rise + 0.5, dims.y * 0.7)
	var finial_h: float = minf(post_w * 1.4, dims.y - post_h)
	var finial: ArrayMesh = _lathe(_kalasha_profile(post_w * 0.42, finial_h, true), 6, Palette.GOLD, true)
	for sx: float in [-1.0, 1.0]:
		var post_pos: Vector3 = Vector3(sx * (dims.x - post_w) * 0.5, -dims.y * 0.5 + post_h * 0.5, (-dims.z + post_w) * 0.5)
		_box(parts, _STONE, Vector3(post_w, post_h, post_w), minf(0.03, post_w * 0.15), _marble, post_pos)
		_box(parts, _LACQUER, Vector3(post_w * 1.04, post_h * 0.14, post_w * 1.04), 0.0, Palette.SINDOOR, post_pos + Vector3(0.0, post_h * 0.3, 0.0))
		_put(parts, _GOLD, finial, Transform3D(Basis(), post_pos + Vector3(0.0, post_h * 0.5, 0.0)))
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


static func _build_rooftop(dims: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary = _new_parts()
	var w: float = dims.x
	var d: float = dims.z
	var unit: float = minf(w, d)
	var deck_h: float = dims.y * 0.2
	var deck_centre: Vector3 = Vector3(0.0, -dims.y * 0.5 + deck_h * 0.5, 0.0)
	var deck_size: Vector3 = Vector3(w, deck_h, d)
	var colliders: Array[Dictionary] = [_collider(deck_size, deck_centre)]
	var floor_y: float = -dims.y * 0.5 + deck_h
	# Deck: stone slab with a lacquer band and a gold lip around its edge.
	_box(parts, _STONE, Vector3(w - unit * 0.02, deck_h, d - unit * 0.02), minf(0.04, deck_h * 0.2), Palette.STONE, deck_centre)
	_box(parts, _LACQUER, Vector3(w - unit * 0.008, deck_h * 0.3, d - unit * 0.008), 0.0, Palette.SINDOOR, Vector3(0.0, floor_y - deck_h * 0.45, 0.0))
	_box(parts, _GOLD, Vector3(w, deck_h * 0.2, d), minf(0.02, deck_h * 0.08), Palette.GOLD, Vector3(0.0, floor_y - deck_h * 0.2, 0.0))
	_box(parts, _STONE, Vector3(w - unit * 0.03, deck_h * 0.2, d - unit * 0.03), 0.0, _marble, Vector3(0.0, floor_y - deck_h * 0.1, 0.0))
	# Floor inlay: a gold and lacquer border and a lotus medallion.
	var inlay: float = 0.012
	var border: float = unit * 0.1
	for face: int in range(4):
		var strip_len: float = _face_len(face, w, d) - border * 2.0
		var strip_xf: Transform3D = _face(face, w * 0.5, d * 0.5, 0.0, floor_y, -border)
		_put(parts, _GOLD, MeshKit.box(Vector3(strip_len + unit * 0.012, inlay, unit * 0.012), Palette.GOLD), strip_xf * Transform3D(Basis(), Vector3(0.0, inlay * 0.5, 0.0)))
		_put(parts, _LACQUER, MeshKit.box(Vector3(strip_len - unit * 0.05, inlay, unit * 0.02), Palette.SINDOOR), strip_xf * Transform3D(Basis(), Vector3(0.0, inlay * 0.5, -unit * 0.025)))
	var medal_r: float = unit * 0.13
	_put(parts, _GOLD, MeshKit.cylinder(medal_r, medal_r, inlay, 12, Palette.GOLD), Transform3D(Basis(), Vector3(0.0, floor_y + inlay * 0.5, 0.0)))
	_put(parts, _LACQUER, MeshKit.cylinder(medal_r * 0.84, medal_r * 0.84, inlay * 1.6, 12, Palette.SINDOOR), Transform3D(Basis(), Vector3(0.0, floor_y + inlay * 0.8, 0.0)))
	var petal: ArrayMesh = MeshKit.cylinder(medal_r * 0.2, medal_r * 0.2, inlay * 2.2, 4, Palette.GOLD)
	for p: int in range(8):
		var pa: float = TAU * float(p) / 8.0
		_put(parts, _GOLD, petal, Transform3D(Basis(Vector3.UP, pa) * Basis.from_scale(Vector3(0.55, 1.0, 1.6)), Vector3(sin(pa) * medal_r * 0.5, floor_y + inlay * 1.1, cos(pa) * medal_r * 0.5)))
	_put(parts, _GOLD, MeshKit.cylinder(medal_r * 0.22, medal_r * 0.22, inlay * 2.6, 8, Palette.GOLD), Transform3D(Basis(), Vector3(0.0, floor_y + inlay * 1.3, 0.0)))
	# Parapets (decorative, no collision so leaps between roofs stay free), open in the middle of each side.
	var rail_h: float = clampf(dims.y * 0.2, 0.05, 0.5)
	var rail_t: float = minf(0.16, unit * 0.04)
	var post_w: float = rail_t * 1.9
	for face: int in range(4):
		var side: float = _face_len(face, w, d)
		var gap: float = side * 0.34
		var seg_len: float = (side - gap) * 0.5 - post_w
		var panel: ArrayMesh = MeshKit.box(Vector3(seg_len, rail_h, rail_t), _marble)
		var rail: ArrayMesh = MeshKit.box(Vector3(seg_len + 0.04, rail_h * 0.16, rail_t + 0.05), Palette.GOLD)
		var holes: int = clampi(roundi(seg_len / 0.3), 2, 8)
		var screen: ArrayMesh = _jali(seg_len * 0.9, rail_h * 0.7, holes, 1, Palette.SINDOOR)
		var crests: int = clampi(roundi(seg_len / 0.5), 2, 4)
		var crest_w: float = seg_len / float(crests) * 0.72
		var crest: ArrayMesh = _arch_slab(_arch_profile(crest_w, rail_h * 0.5, rail_h * 0.34, 2), rail_t * 0.6, _marble, true, true)
		for sign: float in [-1.0, 1.0]:
			var seg_along: float = sign * (gap * 0.5 + seg_len * 0.5)
			var seg_xf: Transform3D = _face(face, w * 0.5, d * 0.5, seg_along, floor_y, -rail_t * 0.5 - 0.02)
			_put(parts, _STONE, panel, seg_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.5, 0.0)))
			_put(parts, _GOLD, rail, seg_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 1.08, 0.0)))
			_put(parts, _LACQUER, screen, seg_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.15, rail_t * 0.5 + 0.004)))
			_put(parts, _LACQUER, screen, seg_xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, rail_h * 0.15, -rail_t * 0.5 - 0.004)))
			for c: int in range(crests):
				var crest_along: float = ((float(c) + 0.5) / float(crests) - 0.5) * seg_len
				_put(parts, _STONE, crest, seg_xf * Transform3D(Basis(), Vector3(crest_along, rail_h * 1.16, -rail_t * 0.3)))
			# A small gold-capped post closes the parapet at the gap.
			var end_xf: Transform3D = seg_xf * Transform3D(Basis(), Vector3(-sign * (seg_len * 0.5 + post_w * 0.3), 0.0, 0.0))
			_put(parts, _STONE, MeshKit.box(Vector3(post_w * 0.7, rail_h * 1.3, post_w * 0.7), Palette.STONE), end_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 0.65, 0.0)))
			_put(parts, _GOLD, MeshKit.cone(post_w * 0.42, post_w * 0.5, 4, Palette.GOLD), end_xf * Transform3D(Basis(), Vector3(0.0, rail_h * 1.3 + post_w * 0.25, 0.0)))
	var corner_finial: ArrayMesh = _lathe(_kalasha_profile(post_w * 0.55, rail_h * 1.1, false), 6, Palette.GOLD, true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner: Vector3 = Vector3(sx * (w * 0.5 - post_w * 0.5 - 0.02), floor_y, sz * (d * 0.5 - post_w * 0.5 - 0.02))
			_box(parts, _STONE, Vector3(post_w, rail_h * 1.5, post_w), 0.025, Palette.STONE, corner + Vector3(0.0, rail_h * 0.75, 0.0))
			_box(parts, _LACQUER, Vector3(post_w * 1.05, rail_h * 0.2, post_w * 1.05), 0.0, Palette.SINDOOR, corner + Vector3(0.0, rail_h * 1.1, 0.0))
			_put(parts, _GOLD, corner_finial, Transform3D(Basis(), corner + Vector3(0.0, rail_h * 1.5, 0.0)))
	# Awning in one quarter of the roof: wooden posts, a striped sloping canopy, a swaying valance, a rug.
	var quarter: int = rng.randi_range(0, 3)
	var ax: float = -1.0 if quarter % 2 == 0 else 1.0
	var az: float = -1.0 if quarter < 2 else 1.0
	var stripe_a: Color = Palette.SAFFRON if rng.randf() < 0.5 else Palette.SINDOOR
	var stripe_b: Color = _marble
	var aw: float = w * 0.34
	var ad: float = d * 0.34
	var a_centre: Vector3 = Vector3(ax * w * 0.24, floor_y, az * d * 0.24)
	var high: float = maxf(dims.y - deck_h, 2.35)
	var drop: float = 0.3
	var post_r: float = 0.045
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post_h: float = high - 0.04 - (0.0 if sz * az > 0.0 else drop)
			var post_pos: Vector3 = a_centre + Vector3(sx * aw * 0.5, post_h * 0.5, sz * ad * 0.5)
			_put(parts, _WOOD, MeshKit.cylinder_smooth(post_r * 0.8, post_r, post_h, 6, Palette.BARK), Transform3D(Basis(), post_pos))
			_put(parts, _GOLD, MeshKit.sphere_smooth(post_r * 1.5, 4, 6, Palette.GOLD), Transform3D(Basis(), post_pos + Vector3(0.0, post_h * 0.5 + post_r * 1.6, 0.0)))
	var tilt: Basis = Basis(Vector3.RIGHT, -az * atan2(drop, ad))
	var canopy_xf: Transform3D = Transform3D(tilt, a_centre + Vector3(0.0, high - drop * 0.5, 0.0))
	var stripes: int = 6
	var stripe_w: float = aw * 1.14 / float(stripes)
	var canopy_len: float = ad * 1.16
	for s: int in range(stripes):
		var stripe_colour: Color = stripe_a if s % 2 == 0 else stripe_b
		var sx_pos: float = ((float(s) + 0.5) / float(stripes) - 0.5) * aw * 1.14
		var strip: ArrayMesh = MeshKit.with_wind(MeshKit.box(Vector3(stripe_w, 0.03, canopy_len), stripe_colour), 0.08)
		_put(parts, _CLOTH, strip, canopy_xf * Transform3D(Basis(), Vector3(sx_pos, 0.0, 0.0)))
		# Valance tongues along both eaves: pinned at the top, free at the tip.
		var tongue_h: float = 0.24
		var tongue: ArrayMesh = MeshKit.wind_weighted(_arch_slab(_arch_profile(stripe_w * 0.94, tongue_h, tongue_h * 0.5, 2), 0.02, stripe_b if s % 2 == 0 else stripe_a, true, true), 0.0, tongue_h)
		for eave: float in [-1.0, 1.0]:
			_put(parts, _CLOTH, tongue, canopy_xf * Transform3D(Basis(Vector3.BACK, PI), Vector3(sx_pos, 0.0, eave * canopy_len * 0.5 - 0.01)))
	_put(parts, _CLOTH, MeshKit.with_wind(MeshKit.box(Vector3(aw * 0.86, 0.016, ad * 0.86), _deep_red), 0.0), Transform3D(Basis(), a_centre + Vector3(0.0, 0.018, 0.0)))
	_put(parts, _CLOTH, MeshKit.with_wind(MeshKit.box(Vector3(aw * 0.6, 0.02, ad * 0.6), stripe_a), 0.0), Transform3D(Basis(), a_centre + Vector3(0.0, 0.02, 0.0)))
	_put(parts, _GOLD, MeshKit.box(Vector3(aw * 0.92, 0.012, ad * 0.92), Palette.GOLD), Transform3D(Basis(), a_centre + Vector3(0.0, 0.007, 0.0)))
	# Pots and a brass lamp in the corners that the awning leaves free.
	var slots: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			if sx == ax and sz == az:
				continue
			slots.append(Vector3(sx * (w * 0.5 - unit * 0.1), floor_y, sz * (d * 0.5 - unit * 0.1)))
			slots.append(Vector3(sx * (w * 0.5 - unit * 0.085), floor_y, sz * (d * 0.5 - unit * 0.2)))
			slots.append(Vector3(sx * (w * 0.5 - unit * 0.2), floor_y, sz * (d * 0.5 - unit * 0.085)))
	var pot_count: int = rng.randi_range(4, 6)
	for p: int in range(pot_count):
		var pick: int = rng.randi_range(0, slots.size() - 1)
		var spot: Vector3 = slots[pick]
		slots.remove_at(pick)
		var pot_r: float = rng.randf_range(0.24, 0.36) * clampf(unit / 7.0, 0.4, 1.5)
		var style: int = rng.randi_range(0, 2)
		if p == 0:
			_put_lamp(parts, spot, pot_r * 0.8)
		elif style == 0:
			_put(parts, _GOLD, _lathe(_pot_profile(pot_r, pot_r * 2.0), 6, Palette.GOLD, true), Transform3D(Basis(), spot))
			_put(parts, _FOLIAGE, MeshKit.with_wind(MeshKit.sphere_smooth(pot_r * 0.62, 4, 6, Palette.GROVE_GREEN), 0.3), Transform3D(Basis(), spot + Vector3(0.0, pot_r * 2.25, 0.0)))
		else:
			var jar_colour: Color = _terracotta if style == 1 else Palette.SINDOOR
			_put(parts, _LACQUER, _lathe(_pot_profile(pot_r, pot_r * 2.3), 6, jar_colour, true), Transform3D(Basis(), spot))
			_put(parts, _GOLD, _lathe(_ring_profile(pot_r * 0.6, pot_r * 0.72, pot_r * 0.16), 6, Palette.GOLD, true), Transform3D(Basis(), spot + Vector3(0.0, pot_r * 2.2, 0.0)))
			var bush_y: float = pot_r * 2.3
			for b: int in range(2):
				var ba: float = TAU * float(b) / 2.0 + rng.randf_range(0.0, 1.0)
				var leaf_colour: Color = Palette.GROVE_GREEN if b != 1 else Palette.LEAF_DARK
				var bush: ArrayMesh = MeshKit.with_wind(MeshKit.sphere_smooth(pot_r * rng.randf_range(0.5, 0.7), 4, 6, leaf_colour), 0.55)
				_put(parts, _FOLIAGE, bush, Transform3D(Basis.from_scale(Vector3(1.0, 1.25, 1.0)), spot + Vector3(sin(ba) * pot_r * 0.4, bush_y + pot_r * (0.4 + 0.3 * float(b)), cos(ba) * pot_r * 0.4)))
			_put(parts, _FOLIAGE, MeshKit.with_wind(MeshKit.sphere_smooth(pot_r * 0.22, 3, 5, Palette.ASHOKA_RED), 0.55), Transform3D(Basis(), spot + Vector3(pot_r * 0.5, bush_y + pot_r * 1.1, pot_r * 0.3)))
	return {"mesh": MeshKit.multi(parts), "colliders": colliders}


## A brass lamp stand (deepa stambha) with a small flame.
static func _put_lamp(parts: Dictionary, base: Vector3, r: float) -> void:
	var h: float = r * 5.5
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(r, 0.0), Vector2(r * 0.9, h * 0.05), Vector2(r * 0.3, h * 0.12), Vector2(r * 0.2, h * 0.45),
		Vector2(r * 0.38, h * 0.5), Vector2(r * 0.2, h * 0.55), Vector2(r * 0.2, h * 0.84), Vector2(r * 0.85, h * 0.92),
		Vector2(r * 0.95, h * 0.97), Vector2(0.0, h * 0.95),
	])
	_put(parts, _GOLD, _lathe(profile, 6, Palette.GOLD, true), Transform3D(Basis(), base))
	_put(parts, _LACQUER, MeshKit.sphere_smooth(r * 0.3, 4, 6, Palette.FIRE_CORE), Transform3D(Basis.from_scale(Vector3(1.0, 1.8, 1.0)), base + Vector3(0.0, h * 0.97 + r * 0.45, 0.0)))


# --- part helpers ------------------------------------------------------------------------------------------

static func _new_parts() -> Dictionary:
	return {_STONE: [], _LACQUER: [], _GOLD: [], _WOOD: [], _CLOTH: [], _FOLIAGE: []}


static func _put(parts: Dictionary, kind: StringName, mesh: ArrayMesh, xf: Transform3D) -> void:
	(parts[kind] as Array).append({"mesh": mesh, "transform": xf})


## Adds a box of `size` centred on `pos`; bevelled when `bevel` > 0.
static func _box(parts: Dictionary, kind: StringName, size: Vector3, bevel: float, colour: Color, pos: Vector3) -> void:
	var mesh: ArrayMesh = MeshKit.bevel_box(size, bevel, colour) if bevel > 0.0 else MeshKit.box(size, colour)
	_put(parts, kind, mesh, Transform3D(Basis(), pos))


## Turns every part by `yaw` about the Y axis (used when a prop's long side is Z instead of X).
static func _rotate_parts(parts: Dictionary, yaw: float) -> void:
	var turn: Transform3D = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	for kind: Variant in parts:
		for part: Variant in parts[kind] as Array:
			var entry: Dictionary = part as Dictionary
			entry["transform"] = turn * (entry["transform"] as Transform3D)


## Frame on one vertical face of a box with half extents (hw, hd): local +Z points out of the face, local +X
## runs along it and the origin sits `along` metres from the face centre at height `y`, pushed `out` metres
## outward. Faces: 0 = +Z, 1 = +X, 2 = -Z, 3 = -X.
static func _face(face: int, hw: float, hd: float, along: float, y: float, out: float) -> Transform3D:
	match face:
		0:
			return Transform3D(Basis(), Vector3(along, y, hd + out))
		1:
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hw + out, y, -along))
		2:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(-along, y, -hd - out))
		_:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hw - out, y, along))


static func _face_len(face: int, w: float, d: float) -> float:
	return w if face % 2 == 0 else d


## A row of `count` gold pyramid studs along a face: the repeated motif of the relief bands.
static func _stud_row(parts: Dictionary, face: int, hw: float, hd: float, y: float, span: float, count: int, r: float) -> void:
	var stud: ArrayMesh = MeshKit.cone(r, r * 0.7, 4, Palette.GOLD)
	var lift: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, r * 0.3))
	for k: int in range(count):
		var along: float = ((float(k) + 0.5) / float(count) - 0.5) * span
		_put(parts, _GOLD, stud, _face(face, hw, hd, along, y, 0.0) * lift)


## Meshes of an arched opening of outer size w x h standing on y = 0 against a wall at z = 0: a frame ring, a
## dark backing and, optionally, a jali screen of gold diamonds over the lower part.
static func _opening(w: float, h: float, frame: Color, back: Color, depth: float, segs: int, jali: bool, outer_wall: bool) -> Dictionary:
	var rise: float = minf(w * 0.62, h * 0.5)
	var border: float = w * 0.15
	var inner_w: float = w - border * 2.0
	var inner_h: float = h - border * 1.2
	var inner_rise: float = rise * inner_w / w
	var outer: PackedVector2Array = _arch_profile(w, h, rise, segs)
	var inner: PackedVector2Array = _arch_profile(inner_w, inner_h, inner_rise, segs)
	var meshes: Dictionary = {
		"ring": _arch_ring(outer, inner, depth, frame, outer_wall),
		"back": _arch_slab(inner, depth * 0.15, back, false, false),
	}
	if jali:
		var screen_h: float = inner_h - inner_rise
		var cols: int = 3
		var rows: int = clampi(roundi(screen_h / (inner_w / float(cols))), 2, 3)
		meshes["jali"] = _jali(inner_w, screen_h, cols, rows, frame)
		meshes["jali_z"] = depth * 0.45
	return meshes


static func _put_opening(parts: Dictionary, meshes: Dictionary, xf: Transform3D) -> void:
	_put(parts, _GOLD, meshes["ring"] as ArrayMesh, xf)
	_put(parts, _LACQUER, meshes["back"] as ArrayMesh, xf)
	if meshes.has("jali"):
		_put(parts, _GOLD, meshes["jali"] as ArrayMesh, xf * Transform3D(Basis(), Vector3(0.0, 0.0, meshes["jali_z"] as float)))


# --- custom meshes -----------------------------------------------------------------------------------------

## Outline of an ogee (pointed) arch, w wide and h tall, standing on y = 0 and centred on x = 0. The straight
## jambs end `rise` below the apex; the curve has `segs` segments (use an even number so the apex is a vertex).
static func _arch_profile(w: float, h: float, rise: float, segs: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var spring: float = h - rise
	pts.append(Vector2(-w * 0.5, 0.0))
	for i: int in range(segs + 1):
		var th: float = PI * float(i) / float(segs)
		var s: float = sin(th)
		pts.append(Vector2(-w * 0.5 * cos(th), spring + rise * (0.76 * s + 0.24 * pow(s, 8.0))))
	pts.append(Vector2(w * 0.5, 0.0))
	return pts


## The profile extruded from z = 0 to z = depth: a front face, optional side walls and an optional back face.
static func _arch_slab(profile: PackedVector2Array, depth: float, colour: Color, sides: bool, back: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector2 = _profile_centre(profile)
	for i: int in range(profile.size() - 1):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		_tri(st, Vector3(0.0, 0.0, depth), Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), colour, Vector3.BACK)
		if back:
			_tri(st, Vector3.ZERO, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), colour, Vector3.FORWARD)
		if sides:
			var mid: Vector2 = (a + b) * 0.5 - centre
			_quad(st, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), Vector3(b.x, b.y, depth), Vector3(a.x, a.y, depth), colour, Vector3(mid.x, mid.y, 0.0))
	return st.commit()


## A frame between two arch profiles with the same point count, from z = 0 to z = depth: the front strip, the
## inner reveal and, optionally, the outer wall.
static func _arch_ring(outer: PackedVector2Array, inner: PackedVector2Array, depth: float, colour: Color, outer_wall: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector2 = _profile_centre(inner)
	for i: int in range(outer.size() - 1):
		var oa: Vector2 = outer[i]
		var ob: Vector2 = outer[i + 1]
		var ia: Vector2 = inner[i]
		var ib: Vector2 = inner[i + 1]
		_quad(st, Vector3(oa.x, oa.y, depth), Vector3(ob.x, ob.y, depth), Vector3(ib.x, ib.y, depth), Vector3(ia.x, ia.y, depth), colour, Vector3.BACK)
		var out_dir: Vector2 = (ia + ib) * 0.5 - centre
		_quad(st, Vector3(ia.x, ia.y, 0.0), Vector3(ib.x, ib.y, 0.0), Vector3(ib.x, ib.y, depth), Vector3(ia.x, ia.y, depth), colour, Vector3(-out_dir.x, -out_dir.y, 0.0))
		if outer_wall:
			var o_dir: Vector2 = (oa + ob) * 0.5 - centre
			_quad(st, Vector3(oa.x, oa.y, 0.0), Vector3(ob.x, ob.y, 0.0), Vector3(ob.x, ob.y, depth), Vector3(oa.x, oa.y, depth), colour, Vector3(o_dir.x, o_dir.y, 0.0))
	return st.commit()


static func _profile_centre(profile: PackedVector2Array) -> Vector2:
	var top: float = 0.0
	for p: Vector2 in profile:
		top = maxf(top, p.y)
	return Vector2(0.0, top * 0.45)


## A jali screen: cols x rows diamonds that touch corner to corner, in the rectangle w x h standing on y = 0,
## facing +Z. One-sided, to lie just in front of a dark backing.
static func _jali(w: float, h: float, cols: int, rows: int, colour: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cw: float = w / float(cols)
	var ch: float = h / float(rows)
	for r: int in range(rows):
		for c: int in range(cols):
			var cx: float = -w * 0.5 + cw * (float(c) + 0.5)
			var cy: float = ch * (float(r) + 0.5)
			var left: Vector3 = Vector3(cx - cw * 0.46, cy, 0.0)
			var right: Vector3 = Vector3(cx + cw * 0.46, cy, 0.0)
			var up: Vector3 = Vector3(cx, cy + ch * 0.46, 0.0)
			var down: Vector3 = Vector3(cx, cy - ch * 0.46, 0.0)
			_quad(st, left, down, right, up, colour, Vector3.BACK)
	return st.commit()


## Surface of revolution about the Y axis. `profile` lists (radius, y) from the bottom up; with `smooth` the
## normals follow the curve. The ends are left open unless the profile reaches radius 0.
static func _lathe(profile: PackedVector2Array, sides: int, colour: Color, smooth: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = profile.size()
	var normals: PackedVector2Array = PackedVector2Array()
	for i: int in range(count):
		var tangent: Vector2 = profile[mini(i + 1, count - 1)] - profile[maxi(i - 1, 0)]
		var n: Vector2 = Vector2(tangent.y, -tangent.x)
		normals.append(n.normalized() if n.length_squared() > 1e-12 else Vector2.RIGHT)
	for i: int in range(count - 1):
		for k: int in range(sides):
			var a0: float = TAU * float(k) / float(sides)
			var a1: float = TAU * float(k + 1) / float(sides)
			var v00: Vector3 = _ring_point(profile[i], a0)
			var v01: Vector3 = _ring_point(profile[i], a1)
			var v10: Vector3 = _ring_point(profile[i + 1], a0)
			var v11: Vector3 = _ring_point(profile[i + 1], a1)
			var n00: Vector3 = _ring_normal(normals[i], a0)
			var n01: Vector3 = _ring_normal(normals[i], a1)
			var n10: Vector3 = _ring_normal(normals[i + 1], a0)
			var n11: Vector3 = _ring_normal(normals[i + 1], a1)
			if smooth:
				_tri_smooth(st, v00, v01, v11, n00, n01, n11, colour)
				_tri_smooth(st, v00, v11, v10, n00, n11, n10, colour)
			else:
				var hint: Vector3 = n00 + n01 + n10 + n11
				_tri(st, v00, v01, v11, colour, hint)
				_tri(st, v00, v11, v10, colour, hint)
	return st.commit()


static func _ring_point(p: Vector2, angle: float) -> Vector3:
	return Vector3(sin(angle) * p.x, p.y, cos(angle) * p.x)


static func _ring_normal(n: Vector2, angle: float) -> Vector3:
	return Vector3(sin(angle) * n.x, n.y, cos(angle) * n.x).normalized()


## A tapering shaft centred on the origin whose cross-section alternates ridge and groove: flat-shaded, so each
## flute catches the light on its own.
static func _fluted_shaft(r_bottom: float, r_top: float, h: float, flutes: int, colour: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = flutes * 2
	for k: int in range(n):
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var f0: float = 1.0 if k % 2 == 0 else 0.84
		var f1: float = 0.84 if k % 2 == 0 else 1.0
		var b0: Vector3 = Vector3(sin(a0) * r_bottom * f0, -h * 0.5, cos(a0) * r_bottom * f0)
		var b1: Vector3 = Vector3(sin(a1) * r_bottom * f1, -h * 0.5, cos(a1) * r_bottom * f1)
		var t0: Vector3 = Vector3(sin(a0) * r_top * f0, h * 0.5, cos(a0) * r_top * f0)
		var t1: Vector3 = Vector3(sin(a1) * r_top * f1, h * 0.5, cos(a1) * r_top * f1)
		var mid: float = (a0 + a1) * 0.5
		_quad(st, b0, b1, t1, t0, colour, Vector3(sin(mid), 0.0, cos(mid)))
	return st.commit()


## A moulding ring: narrow at both ends, bulging to r_out in the middle.
static func _ring_profile(r_in: float, r_out: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r_in, 0.0), Vector2(r_out * 0.96, h * 0.2), Vector2(r_out, h * 0.5), Vector2(r_out * 0.96, h * 0.8), Vector2(r_in, h),
	])


## A slim column with a base and a flared capital, standing on y = 0.
static func _column_profile(r: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 1.5, 0.0), Vector2(r * 1.5, h * 0.05), Vector2(r, h * 0.09), Vector2(r * 0.86, h * 0.84),
		Vector2(r * 1.3, h * 0.89), Vector2(r, h * 0.93), Vector2(r * 1.6, h),
	])


## A kalasha finial (pot, neck, bud) standing on y = 0; the simple form has fewer bands for small ornaments.
static func _kalasha_profile(r: float, h: float, detailed: bool) -> PackedVector2Array:
	if not detailed:
		return PackedVector2Array([
			Vector2(r * 0.6, 0.0), Vector2(r, h * 0.26), Vector2(r * 0.4, h * 0.56), Vector2(r * 0.52, h * 0.68), Vector2(0.0, h),
		])
	return PackedVector2Array([
		Vector2(r * 0.6, 0.0), Vector2(r * 0.8, h * 0.06), Vector2(r * 0.48, h * 0.13), Vector2(r, h * 0.32),
		Vector2(r * 0.88, h * 0.46), Vector2(r * 0.34, h * 0.58), Vector2(r * 0.56, h * 0.66), Vector2(r * 0.22, h * 0.78),
		Vector2(0.0, h),
	])


## An onion dome standing on y = 0.
static func _dome_profile(r: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 0.94, 0.0), Vector2(r * 1.08, h * 0.2), Vector2(r, h * 0.48), Vector2(r * 0.66, h * 0.76),
		Vector2(r * 0.24, h * 0.93), Vector2(0.0, h),
	])


## A water pot with a closed mouth, standing on y = 0.
static func _pot_profile(r: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 0.5, 0.0), Vector2(r * 0.92, h * 0.22), Vector2(r, h * 0.5), Vector2(r * 0.74, h * 0.8),
		Vector2(r * 0.52, h * 0.9), Vector2(r * 0.68, h), Vector2(0.0, h * 0.94),
	])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, facing: Vector3) -> void:
	_tri(st, a, b, c, colour, facing)
	_tri(st, a, c, d, colour, facing)


## One flat triangle whose normal points to the same side as `facing`, wound clockwise (Godot's front face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, facing: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	var p1: Vector3 = b
	var p2: Vector3 = c
	if n.dot(facing) < 0.0:
		p1 = c
		p2 = b
		n = -n
	var normal: Vector3 = n.normalized()
	for v: Vector3 in [a, p2, p1]:
		st.set_normal(normal)
		st.set_color(colour)
		st.add_vertex(v)


## One triangle with a normal per vertex; the normals decide which side is the front.
static func _tri_smooth(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, colour: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	var order: Array[Vector3] = [a, c, b]
	var order_n: Array[Vector3] = [na, nc, nb]
	if n.dot(na + nb + nc) < 0.0:
		order = [a, b, c]
		order_n = [na, nb, nc]
	for i: int in range(3):
		st.set_normal(order_n[i])
		st.set_color(colour)
		st.add_vertex(order[i])


# --- assembly ----------------------------------------------------------------------------------------------

static func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


static func _positive(size: Vector3) -> Vector3:
	return Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01))


static func _key(kind: String, dims: Vector3, rng_seed: int) -> String:
	return "%s|%s|%d" % [kind, var_to_str(dims), rng_seed]


static func _store(key: String, built: Dictionary) -> void:
	if _cache.size() >= _CACHE_LIMIT:
		_cache.clear()
	_cache[key] = built


static func _collider(size: Vector3, pos: Vector3, euler: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"size": size, "pos": pos, "euler": euler}


static func _instance(built: Dictionary, opts: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = built["mesh"] as ArrayMesh
	root.add_child(visual)
	for entry: Variant in built["colliders"] as Array:
		var c: Dictionary = entry as Dictionary
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
