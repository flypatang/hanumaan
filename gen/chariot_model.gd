class_name ChariotModel
extends RefCounted
## Akshaya Kumara's chariot (DESIGN §9 M26; art direction v2, docs/ART.md, module B2): a carved, gilded war
## chariot drawn by two dark horses.
##
## The car is a curved crimson-lacquer shell that rises to a prow, with gold rails, ribs, sun medallions and
## kalasha finials, a timber deck, and a tall standard flying a pennant. The wheels have turned spokes, a
## lacquered felloe with a gold tyre and studs, and a bossed hub. The horses have sculpted bodies, arched necks,
## flowing manes and tails (cloth with wind weights), gold tack and crimson caparisons; one paws the air.
##
## The chariot faces -Z (Godot forward), the horses stand ahead of the car, and the rider's platform top is at
## PLATFORM_TOP. build() returns the root Node3D with the MeshInstance3D children "Car", "Wheel_L", "Wheel_R",
## "Pole", "Horse_A" and "Horse_B". Each of them shows one material kind and carries one child MeshInstance3D
## per further kind (gold, cloth, ...), so a wheel still spins as one piece.

const PLATFORM_TOP: float = 0.85
const WHEEL_RADIUS: float = 0.62
const WHEEL_X: float = 0.85
const HORSE_X: float = 0.5
const HORSE_Z: float = -2.6
const WHEEL_SPOKES: int = 12
const _SHELL_STEPS: int = 18
const _SHELL_HALF: float = 0.72
const _SHELL_BACK: float = 0.78
const _SHELL_FRONT: float = -0.22


## Builds the chariot with its horses.
static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Chariot"
	_assemble(root, "Car", _car_parts(), Vector3.ZERO)
	_assemble(root, "Wheel_L", _wheel_parts(-1.0), Vector3(-WHEEL_X, WHEEL_RADIUS, 0.0))
	_assemble(root, "Wheel_R", _wheel_parts(1.0), Vector3(WHEEL_X, WHEEL_RADIUS, 0.0))
	_assemble(root, "Pole", _pole_parts(), Vector3.ZERO)
	_assemble(root, "Horse_A", _horse_parts(0.0, -1.0), Vector3(-HORSE_X, 0.0, HORSE_Z))
	_assemble(root, "Horse_B", _horse_parts(1.0, 1.0), Vector3(HORSE_X, 0.0, HORSE_Z))
	return root


## Spins both wheels by `angle` radians (call with the distance travelled / WHEEL_RADIUS).
static func spin_wheels(root: Node3D, angle: float) -> void:
	for wheel_name: String in ["Wheel_L", "Wheel_R"]:
		var w: Node3D = root.get_node_or_null(wheel_name) as Node3D
		if w != null:
			w.rotation.x += angle


## One MeshInstance3D for the first kind of `kinds` (kind -> Array of merge() parts), named `node_name`, with a
## child MeshInstance3D "<node_name>_<kind>" for every other kind. "glow" is the emissive eye material.
static func _assemble(root: Node3D, node_name: String, kinds: Dictionary, pos: Vector3) -> void:
	var main: MeshInstance3D = null
	for key: Variant in kinds:
		var kind: StringName = key as StringName
		var typed: Array[Dictionary] = []
		for piece: Variant in kinds[key] as Array:
			typed.append(piece as Dictionary)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = MeshKit.merge(typed)
		mi.material_override = RakshasaModel.glow_material() if kind == &"glow" else Materials.get_material(kind)
		if main == null:
			main = mi
			mi.name = node_name
			mi.position = pos
			root.add_child(mi)
		else:
			mi.name = node_name + "_" + String(kind)
			main.add_child(mi)


static func _put(kinds: Dictionary, kind: StringName, piece: Dictionary) -> void:
	if not kinds.has(kind):
		kinds[kind] = []
	(kinds[kind] as Array).append(piece)


static func _crimson() -> Color:
	return Palette.RAKSHASA_ARMOR.lerp(Palette.SINDOOR, 0.25)


static func _crimson_dark() -> Color:
	return Palette.RAKSHASA_ARMOR.lerp(Palette.NIGHT_INDIGO, 0.45)


static func _antique() -> Color:
	return Palette.GOLD.lerp(Palette.RAKSHASA_ARMOR, 0.3).darkened(0.18)


## Plan of the car wall: a U, open at the back. u = 0 is the back left end, 0.5 the prow, 1 the back right end.
## Returns Vector3(x, 0, z).
static func _shell_plan(u: float) -> Vector3:
	var side_len: float = _SHELL_BACK - _SHELL_FRONT
	var arc_len: float = PI * _SHELL_HALF
	var d: float = clampf(u, 0.0, 1.0) * (2.0 * side_len + arc_len)
	if d < side_len:
		return Vector3(-_SHELL_HALF, 0.0, _SHELL_BACK - d)
	if d < side_len + arc_len:
		var a: float = (d - side_len) / _SHELL_HALF
		return Vector3(-cos(a) * _SHELL_HALF, 0.0, _SHELL_FRONT - sin(a) * _SHELL_HALF)
	return Vector3(_SHELL_HALF, 0.0, _SHELL_FRONT + (d - side_len - arc_len))


## Outward direction of the wall at u.
static func _shell_out(u: float) -> Vector3:
	var e: float = 0.004
	var t: Vector3 = (_shell_plan(u + e) - _shell_plan(u - e)).normalized()
	return Vector3(-t.z, 0.0, t.x) * -1.0


## Height of the wall above the deck: low at the back, sweeping up to the prow.
static func _shell_height(u: float) -> float:
	var k: float = sin(clampf(u, 0.0, 1.0) * PI)
	return 0.52 + 0.5 * k * k * k


## A point on the wall: v = 0 at the deck, 1 at the rim; the wall bellies out and flares at the rim.
static func _shell_point(u: float, v: float, inset: float) -> Vector3:
	var flare: float = 0.07 * sin(v * PI) + 0.13 * v * v * v
	return _shell_plan(u) + _shell_out(u) * (flare - inset) + Vector3(0.0, PLATFORM_TOP - 0.06 + _shell_height(u) * v, 0.0)


static func _car_parts() -> Dictionary:
	var kinds: Dictionary = {}
	var gold: Color = Palette.GOLD
	var lacq: StringName = &"lacquer_local"
	var deck_y: float = PLATFORM_TOP - 0.06

	# The lacquer shell, outside and inside.
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for i: int in range(6):
		var v: float = float(i) / 5.0
		var row_out: PackedVector3Array = PackedVector3Array()
		var row_in: PackedVector3Array = PackedVector3Array()
		for j: int in range(_SHELL_STEPS + 1):
			var u: float = float(j) / float(_SHELL_STEPS)
			row_out.append(_shell_point(1.0 - u, v, 0.0))
			row_in.append(_shell_point(u, v, 0.05))
		outer.append(row_out)
		inner.append(row_in)
	_put(kinds, lacq, RakshasaModel.part(RakshasaModel.grid_surface(outer, PackedColorArray([_crimson_dark(), _crimson(), _crimson(), _crimson().lightened(0.06)]), false)))
	_put(kinds, lacq, RakshasaModel.part(RakshasaModel.grid_surface(inner, PackedColorArray([_crimson_dark(), _crimson_dark().lightened(0.05)]), false)))

	# Gold rails along the rim, the waist and the sill; ribs between them; kalasha finials on the back posts.
	for band: Vector2 in [Vector2(1.0, 0.045), Vector2(0.52, 0.022), Vector2(0.06, 0.035)]:
		var rail: PackedVector3Array = PackedVector3Array()
		for j2: int in range(_SHELL_STEPS + 1):
			rail.append(_shell_point(float(j2) / float(_SHELL_STEPS), band.x, 0.02 if band.x > 0.9 else -0.012))
		_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(rail, PackedVector2Array([Vector2(band.y, band.y)]), 4, PackedColorArray([gold]), 1, Vector3.UP)))
	for k: int in range(9):
		var u2: float = (float(k) + 0.5) / 9.0
		var rib: PackedVector3Array = PackedVector3Array()
		for s: int in range(5):
			rib.append(_shell_point(u2, float(s) / 4.0, -0.012))
		_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(rib, PackedVector2Array([Vector2(0.026, 0.02), Vector2(0.018, 0.016), Vector2(0.026, 0.02)]), 4, PackedColorArray([gold]), 1, _shell_out(u2))))
		# A sun medallion with a sindoor heart in every second bay.
		if k % 2 == 1:
			continue
		var um: float = float(k) / 9.0 + 0.5 / 9.0 + 0.5 / 9.0
		um = clampf(um, 0.06, 0.94)
		var out: Vector3 = _shell_out(um)
		var centre: Vector3 = _shell_point(um, 0.3, -0.015)
		var face: Basis = RakshasaModel.aim(out)
		_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.085, 0.025, 0.085), centre, face, 3, 8))
		_put(kinds, lacq, RakshasaModel.ellipsoid(Palette.SINDOOR, Vector3(0.04, 0.03, 0.04), centre + out * 0.012, face, 3, 6))
		for p: int in range(8):
			var a: float = TAU * float(p) / 8.0
			var petal: Vector3 = face * Vector3(cos(a), 0.0, sin(a))
			_put(kinds, &"gold", RakshasaModel.spike(gold, 0.022, 0.075, centre + petal * 0.07, petal + out * 0.2, 4))
	for sgn: float in [-1.0, 1.0]:
		var post: Vector3 = Vector3(sgn * _SHELL_HALF, deck_y, _SHELL_BACK)
		_put(kinds, &"gold", _lathe(post, [Vector2(0.0, 0.05), Vector2(0.3, 0.04), Vector2(0.56, 0.05), Vector2(0.62, 0.085), Vector2(0.7, 0.1), Vector2(0.78, 0.06), Vector2(0.84, 0.035), Vector2(0.95, 0.0)], gold, 8))
	# The prow: a gold lotus bud curling forward over the rim.
	var prow: Vector3 = _shell_point(0.5, 1.0, 0.0)
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([prow + Vector3(0.0, -0.1, 0.03), prow + Vector3(0.0, 0.14, -0.06), prow + Vector3(0.0, 0.3, -0.2), prow + Vector3(0.0, 0.3, -0.36)]),
		PackedVector2Array([Vector2(0.07, 0.05), Vector2(0.055, 0.045), Vector2(0.04, 0.04), Vector2(0.03, 0.03)]), 6, PackedColorArray([gold]), 3)))
	_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.075, 0.075, 0.11), prow + Vector3(0.0, 0.29, -0.42), Basis.IDENTITY, 5, 8))
	_put(kinds, &"gold", RakshasaModel.spike(gold, 0.04, 0.12, prow + Vector3(0.0, 0.29, -0.5), Vector3(0.0, 0.2, -1.0), 5))

	# Timber deck with a gilded edge, the frame under it, the axle.
	_put(kinds, &"wood_local", RakshasaModel.part(MeshKit.bevel_box(Vector3(1.5, 0.1, 1.72), 0.025, Palette.BARK.lerp(Palette.RAKSHASA_ARMOR, 0.25)), Transform3D(Basis.IDENTITY, Vector3(0.0, PLATFORM_TOP - 0.05, 0.0))))
	_put(kinds, &"gold", RakshasaModel.part(MeshKit.bevel_box(Vector3(1.56, 0.05, 0.08), 0.015, gold), Transform3D(Basis.IDENTITY, Vector3(0.0, PLATFORM_TOP - 0.055, 0.86))))
	for sgn2: float in [-1.0, 1.0]:
		_put(kinds, &"wood_local", RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([Vector3(sgn2 * 0.45, deck_y - 0.03, 0.8), Vector3(sgn2 * 0.45, WHEEL_RADIUS + 0.06, 0.0), Vector3(sgn2 * 0.3, deck_y - 0.05, -0.85)]),
			PackedVector2Array([Vector2(0.05, 0.05)]), 5, PackedColorArray([Palette.BARK.darkened(0.2)]), 3)))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(-WHEEL_X - 0.02, WHEEL_RADIUS, 0.0), Vector3(WHEEL_X + 0.02, WHEEL_RADIUS, 0.0)]),
		PackedVector2Array([Vector2(0.055, 0.055)]), 7, PackedColorArray([_antique()]), 1)))

	# The standard: a tall gold staff with turned rings, a trident finial and a long pennant.
	var staff: Vector3 = Vector3(0.0, deck_y, 0.74)
	_put(kinds, &"gold", _lathe(staff, [Vector2(0.0, 0.06), Vector2(0.08, 0.075), Vector2(0.16, 0.04), Vector2(1.2, 0.034), Vector2(1.26, 0.06), Vector2(1.32, 0.034), Vector2(2.5, 0.028), Vector2(2.56, 0.07), Vector2(2.64, 0.08), Vector2(2.72, 0.03)], gold, 7))
	var top: Vector3 = staff + Vector3(0.0, 2.72, 0.0)
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([top, top + Vector3(0.0, 0.12, 0.0), top + Vector3(0.0, 0.42, 0.0)]), PackedVector2Array([Vector2(0.025, 0.02), Vector2(0.045, 0.014), Vector2.ZERO]), 5, PackedColorArray([gold]), 2)))
	for sgn3: float in [-1.0, 1.0]:
		_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([top, top + Vector3(sgn3 * 0.13, 0.04, 0.0), top + Vector3(sgn3 * 0.16, 0.16, 0.0), top + Vector3(sgn3 * 0.12, 0.32, 0.0)]), PackedVector2Array([Vector2(0.02, 0.016), Vector2(0.026, 0.014), Vector2(0.028, 0.012), Vector2.ZERO]), 5, PackedColorArray([gold]), 2)))
	var flag_rows: Array[PackedVector3Array] = []
	var flag_cols: PackedColorArray = PackedColorArray()
	for i2: int in range(8):
		var t: float = float(i2) / 7.0
		var row: PackedVector3Array = PackedVector3Array()
		var tall: float = lerpf(0.62, 0.06, t * t)
		for j3: int in range(4):
			var w: float = float(j3) / 3.0
			row.append(staff + Vector3(sin(t * 5.0) * 0.06 * t, 2.5 - tall * w - 0.12 * t, 0.03 + 1.5 * t))
		flag_rows.append(row)
		flag_cols.append(Color(Palette.SINDOOR.lerp(Palette.GOLD, 0.85 if i2 == 7 else 0.0), pow(t, 1.3)))
	_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.grid_surface(flag_rows, flag_cols, false, Vector3.RIGHT)))
	return kinds


## Upright turned column at `origin`: `profile` is Vector2(height, radius) stations.
static func _lathe(origin: Vector3, profile: Array[Vector2], color: Color, sides: int) -> Dictionary:
	var pts: PackedVector3Array = PackedVector3Array()
	var rad: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in profile:
		pts.append(origin + Vector3(0.0, p.x, 0.0))
		rad.append(Vector2(p.y, p.y))
	return RakshasaModel.part(RakshasaModel.tube(pts, rad, sides, PackedColorArray([color]), 1))


## A wheel in the YZ plane around the origin: lacquered felloe, gold tyre and studs, turned spokes, bossed hub.
## `outer_sign` is the side (in X) that faces away from the car.
static func _wheel_parts(outer_sign: float) -> Dictionary:
	var kinds: Dictionary = {}
	var gold: Color = Palette.GOLD
	var r: float = WHEEL_RADIUS
	_put(kinds, &"lacquer_local", RakshasaModel.part(RakshasaModel.ring(Vector3.ZERO, Vector3(0.0, r - 0.075, 0.0), Vector3(0.0, 0.0, r - 0.075), 0.06, 20, 5, _crimson())))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3.ZERO, Vector3(0.0, r - 0.022, 0.0), Vector3(0.0, 0.0, r - 0.022), 0.034, 20, 4, gold)))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3.ZERO, Vector3(0.0, r - 0.135, 0.0), Vector3(0.0, 0.0, r - 0.135), 0.018, 20, 3, gold)))
	for i: int in range(WHEEL_SPOKES):
		var a: float = TAU * float(i) / float(WHEEL_SPOKES)
		var dir: Vector3 = Vector3(0.0, cos(a), sin(a))
		_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([dir * 0.1, dir * 0.26, dir * 0.33, dir * (r - 0.11)]),
			PackedVector2Array([Vector2(0.03, 0.03), Vector2(0.022, 0.022), Vector2(0.036, 0.036), Vector2(0.02, 0.02)]), 4, PackedColorArray([_antique(), gold]), 1, Vector3.RIGHT, false)))
		var stud: Vector3 = Vector3(0.0, cos(a + 0.26), sin(a + 0.26)) * (r - 0.075)
		_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.024, 0.028, 0.028), stud + Vector3(outer_sign * 0.055, 0.0, 0.0), Basis.IDENTITY, 3, 5))
	# Hub turned along the axle, with a pointed boss on the outside.
	var hub_pts: PackedVector3Array = PackedVector3Array()
	var hub_rad: PackedVector2Array = PackedVector2Array()
	for st: Vector2 in [Vector2(-0.13, 0.07), Vector2(-0.09, 0.13), Vector2(0.0, 0.15), Vector2(0.09, 0.13), Vector2(0.14, 0.08)]:
		hub_pts.append(Vector3(st.x * outer_sign, 0.0, 0.0))
		hub_rad.append(Vector2(st.y, st.y))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(hub_pts, hub_rad, 10, PackedColorArray([gold]), 1)))
	_put(kinds, &"gold", RakshasaModel.spike(gold, 0.06, 0.16, Vector3(outer_sign * 0.13, 0.0, 0.0), Vector3(outer_sign, 0.0, 0.0), 7))
	_put(kinds, &"lacquer_local", RakshasaModel.part(RakshasaModel.ring(Vector3(outer_sign * 0.05, 0.0, 0.0), Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.0, 0.15), 0.022, 12, 4, Palette.SINDOOR)))
	return kinds


## The draught pole from the car to the yoke, and the yoke bowed over the two horses' withers.
static func _pole_parts() -> Dictionary:
	var kinds: Dictionary = {}
	var gold: Color = Palette.GOLD
	var yoke_z: float = HORSE_Z + 0.62
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 0.72, -0.7), Vector3(0.0, 0.72, -1.3), Vector3(0.0, 1.05, yoke_z + 0.35), Vector3(0.0, 1.42, yoke_z), Vector3(0.0, 1.6, yoke_z - 0.22)]),
		PackedVector2Array([Vector2(0.06, 0.06), Vector2(0.055, 0.055), Vector2(0.05, 0.05), Vector2(0.045, 0.045), Vector2(0.03, 0.03)]), 7, PackedColorArray([_antique(), gold]), 3)))
	_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.06, 0.08, 0.06), Vector3(0.0, 1.66, yoke_z - 0.26), Basis.IDENTITY, 5, 8))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(-HORSE_X - 0.42, 1.36, yoke_z), Vector3(-HORSE_X - 0.25, 1.5, yoke_z), Vector3(-HORSE_X, 1.56, yoke_z), Vector3(-HORSE_X * 0.4, 1.46, yoke_z), Vector3(0.0, 1.42, yoke_z), Vector3(HORSE_X * 0.4, 1.46, yoke_z), Vector3(HORSE_X, 1.56, yoke_z), Vector3(HORSE_X + 0.25, 1.5, yoke_z), Vector3(HORSE_X + 0.42, 1.36, yoke_z)]),
		PackedVector2Array([Vector2(0.03, 0.03), Vector2(0.045, 0.045), Vector2(0.05, 0.05), Vector2(0.045, 0.045), Vector2(0.055, 0.055), Vector2(0.045, 0.045), Vector2(0.05, 0.05), Vector2(0.045, 0.045), Vector2(0.03, 0.03)]), 6, PackedColorArray([gold]), 2, Vector3.UP)))
	for sgn: float in [-1.0, 1.0]:
		_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.05, 0.05, 0.05), Vector3(sgn * (HORSE_X + 0.44), 1.34, yoke_z), Basis.IDENTITY, 4, 6))
		# Reins from the bits back to the rail.
		_put(kinds, &"lacquer_local", RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([Vector3(sgn * HORSE_X, 1.62, HORSE_Z - 1.5), Vector3(sgn * HORSE_X * 0.9, 1.62, HORSE_Z - 0.3), Vector3(sgn * 0.3, 1.5, -1.6), Vector3(sgn * 0.2, PLATFORM_TOP + 0.95, -0.9)]),
			PackedVector2Array([Vector2(0.012, 0.012)]), 4, PackedColorArray([_crimson_dark()]), 3)))
	return kinds


## A horse facing -Z, origin on the ground under its body. `phase` 0 lifts the left foreleg, 1 the right;
## `mane_side` is the side (in X) the mane falls to.
static func _horse_parts(phase: float, mane_side: float) -> Dictionary:
	var kinds: Dictionary = {}
	var gold: Color = Palette.GOLD
	var coat: Color = Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.4)
	var coat_dark: Color = Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.12)
	var hair: Color = _crimson()

	# Barrel, croup and chest.
	_put(kinds, &"fur", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 1.2, 0.92), Vector3(0.0, 1.2, 0.62), Vector3(0.0, 1.1, 0.05), Vector3(0.0, 1.14, -0.5), Vector3(0.0, 1.22, -0.8)]),
		PackedVector2Array([Vector2(0.19, 0.22), Vector2(0.32, 0.36), Vector2(0.3, 0.32), Vector2(0.32, 0.39), Vector2(0.21, 0.3)]), 10, PackedColorArray([coat_dark, coat, coat, coat]), 2, Vector3.UP)))
	for sgn: float in [-1.0, 1.0]:
		_put(kinds, &"fur", RakshasaModel.ellipsoid(coat, Vector3(0.19, 0.32, 0.32), Vector3(sgn * 0.16, 1.12, 0.58), Basis.IDENTITY, 5, 8))
		_put(kinds, &"fur", RakshasaModel.ellipsoid(coat, Vector3(0.16, 0.3, 0.24), Vector3(sgn * 0.18, 1.13, -0.55), Basis.IDENTITY, 5, 8))
	# Arched neck, long head, ears.
	_put(kinds, &"fur", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 1.22, -0.62), Vector3(0.0, 1.56, -0.93), Vector3(0.0, 1.83, -1.05), Vector3(0.0, 1.94, -1.14)]),
		PackedVector2Array([Vector2(0.21, 0.36), Vector2(0.16, 0.26), Vector2(0.13, 0.19), Vector2(0.115, 0.15)]), 8, PackedColorArray([coat, coat, coat_dark]), 2)))
	_put(kinds, &"fur", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 1.95, -1.06), Vector3(0.0, 1.86, -1.32), Vector3(0.0, 1.66, -1.52), Vector3(0.0, 1.55, -1.6)]),
		PackedVector2Array([Vector2(0.12, 0.15), Vector2(0.118, 0.15), Vector2(0.088, 0.1), Vector2(0.08, 0.072)]), 7, PackedColorArray([coat_dark, coat, coat_dark]), 2)))
	_put(kinds, &"fur", RakshasaModel.ellipsoid(coat, Vector3(0.115, 0.15, 0.15), Vector3(0.0, 1.8, -1.2), Basis.IDENTITY, 5, 8))
	for sgn2: float in [-1.0, 1.0]:
		_put(kinds, &"fur", RakshasaModel.spike(coat_dark, 0.045, 0.17, Vector3(sgn2 * 0.08, 2.02, -1.08), Vector3(sgn2 * 0.25, 1.0, -0.15), 5))
		_put(kinds, &"glow", RakshasaModel.ellipsoid(Palette.FIRE_CORE, Vector3(0.018, 0.026, 0.034), Vector3(sgn2 * 0.112, 1.87, -1.3), Basis.IDENTITY, 3, 6))
		_put(kinds, &"fur", RakshasaModel.ellipsoid(coat_dark, Vector3(0.02, 0.02, 0.03), Vector3(sgn2 * 0.05, 1.57, -1.65), Basis.IDENTITY, 3, 5))

	# Legs: forearm, knee, cannon, fetlock and a bronze hoof. One foreleg is lifted.
	for sgn3: float in [-1.0, 1.0]:
		var lifted: bool = (sgn3 < 0.0) == (phase < 0.5)
		var fx: float = sgn3 * 0.17
		var fore: PackedVector3Array = PackedVector3Array([Vector3(fx, 1.05, -0.56), Vector3(fx, 0.62, -0.58), Vector3(fx, 0.2, -0.56), Vector3(fx, 0.09, -0.6)])
		if lifted:
			fore = PackedVector3Array([Vector3(fx, 1.05, -0.56), Vector3(fx, 0.78, -0.86), Vector3(fx, 0.46, -0.72), Vector3(fx, 0.34, -0.7)])
		_leg(kinds, fore, coat, coat_dark, 1.0)
		var back_swing: float = 0.1 if lifted else -0.06
		var hind: PackedVector3Array = PackedVector3Array([Vector3(fx, 1.02, 0.62), Vector3(fx, 0.62, 0.78 + back_swing), Vector3(fx, 0.2, 0.7 + back_swing), Vector3(fx, 0.09, 0.66 + back_swing)])
		_leg(kinds, hind, coat, coat_dark, 1.15)

	# Mane locks down one side of the neck, a forelock, and a long tail: all free in the wind.
	for k: int in range(7):
		var t: float = float(k) / 6.0
		var crest: Vector3 = Vector3(0.0, 1.5, -0.66).lerp(Vector3(0.0, 1.99, -1.06), t) + Vector3(0.0, 0.06 * sin(t * PI), 0.12 * sin(t * PI))
		var hang: Vector3 = crest + Vector3(mane_side * 0.14, -0.2, 0.1)
		var tip: Vector3 = crest + Vector3(mane_side * 0.2, -0.46 - 0.08 * sin(float(k) * 2.3), 0.2)
		_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([crest, hang, tip]), PackedVector2Array([Vector2(0.075, 0.03), Vector2(0.07, 0.025), Vector2(0.01, 0.006)]), 5, PackedColorArray([Color(hair.darkened(0.25), 0.0), Color(hair, 0.4), Color(hair.lightened(0.1), 1.0)]), 2, Vector3(mane_side, 0.3, 0.0))))
	_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([Vector3(0.0, 2.0, -1.1), Vector3(0.0, 1.98, -1.26), Vector3(mane_side * 0.03, 1.84, -1.38)]), PackedVector2Array([Vector2(0.06, 0.03), Vector2(0.05, 0.025), Vector2(0.01, 0.006)]), 5, PackedColorArray([Color(hair.darkened(0.25), 0.0), Color(hair, 0.7)]), 2)))
	_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 1.33, 0.94), Vector3(0.0, 1.5, 1.2), Vector3(0.0, 1.15, 1.52), Vector3(0.0, 0.55, 1.66)]),
		PackedVector2Array([Vector2(0.06, 0.06), Vector2(0.1, 0.1), Vector2(0.13, 0.1), Vector2(0.02, 0.015)]), 7, PackedColorArray([Color(hair.darkened(0.25), 0.0), Color(hair, 0.25), Color(hair, 0.7), Color(hair.lightened(0.1), 1.0)]), 3)))

	# Tack: caparison with gold borders, breast collar, bridle with a brow jewel, a sindoor plume.
	_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 1.17, 0.5), Vector3(0.0, 1.11, 0.15), Vector3(0.0, 1.11, -0.2)]),
		PackedVector2Array([Vector2(0.335, 0.375), Vector2(0.318, 0.34), Vector2(0.325, 0.36)]), 10, PackedColorArray([Color(_crimson(), 0.0)]), 2, Vector3.UP, false)))
	for z: float in [0.5, -0.2]:
		var ry: float = 0.38 if z > 0.0 else 0.365
		var cy: float = 1.17 if z > 0.0 else 1.11
		_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3(0.0, cy, z), Vector3(0.34, 0.0, 0.0), Vector3(0.0, ry, 0.0), 0.02, 12, 3, gold)))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3(0.0, 1.3, -0.72), Vector3(0.235, 0.0, 0.0), Vector3(0.0, 0.29, 0.2), 0.035, 12, 4, gold)))
	_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.06, 0.06, 0.03), Vector3(0.0, 1.1, -0.92), Basis(Vector3.RIGHT, 0.5), 4, 8))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3(0.0, 1.64, -1.55), Vector3(0.095, 0.0, 0.0), Vector3(0.0, 0.075, 0.07), 0.012, 8, 3, gold)))
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(Vector3(0.0, 1.88, -1.22), Vector3(0.128, 0.0, 0.0), Vector3(0.0, 0.11, -0.1), 0.012, 8, 3, gold)))
	_put(kinds, &"gold", RakshasaModel.ellipsoid(gold, Vector3(0.05, 0.02, 0.09), Vector3(0.0, 1.95, -1.3), Basis(Vector3.RIGHT, -0.75), 4, 7))
	_put(kinds, &"cloth", RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([Vector3(0.0, 2.04, -1.12), Vector3(0.0, 2.26, -1.1), Vector3(0.0, 2.44, -1.0)]), PackedVector2Array([Vector2(0.03, 0.03), Vector2(0.06, 0.06), Vector2(0.01, 0.01)]), 5, PackedColorArray([Color(Palette.SINDOOR, 0.0), Color(Palette.SINDOOR, 0.5), Color(Palette.SINDOOR.lerp(Palette.GOLD, 0.4), 1.0)]), 2)))
	return kinds


## One horse leg through four joints (elbow or stifle, knee or hock, fetlock, hoof), with a bronze hoof.
static func _leg(kinds: Dictionary, joints: PackedVector3Array, coat: Color, coat_dark: Color, bulk: float) -> void:
	_put(kinds, &"fur", RakshasaModel.part(RakshasaModel.tube(joints,
		PackedVector2Array([Vector2(0.12, 0.155) * bulk, Vector2(0.07, 0.085) * bulk, Vector2(0.05, 0.057), Vector2(0.06, 0.064)]), 6, PackedColorArray([coat, coat, coat_dark]), 2)))
	_put(kinds, &"fur", RakshasaModel.ellipsoid(coat, Vector3(0.072, 0.085, 0.085) * bulk, joints[1], Basis.IDENTITY, 4, 6))
	var down: Vector3 = (joints[3] - joints[2]).normalized()
	_put(kinds, &"gold", {"mesh": MeshKit.cylinder_smooth(0.06, 0.08, 0.1, 7, _antique()), "transform": Transform3D(RakshasaModel.aim(-down), joints[3] + down * 0.045)})
	_put(kinds, &"gold", RakshasaModel.part(RakshasaModel.ring(joints[2] + (joints[3] - joints[2]) * 0.3, Vector3(0.062, 0.0, 0.0), Vector3(0.0, 0.0, 0.062), 0.013, 8, 3, Palette.GOLD)))
