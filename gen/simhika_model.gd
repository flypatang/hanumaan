class_name SimhikaModel
extends RefCounted
## Simhika, the shadow-seizing sea demoness (DESIGN §4.5, §9 M23; art direction v2, docs/ART.md, module B2).
## A sinuous sea-serpent body rises from the water in an S-curve, with pale belly plates, a webbed dorsal crest,
## two great pectoral fins and a second coil and tail fluke breaking the surface behind her. The head is
## leonine: a broad fanged muzzle, scowling brows, swept horns, webbed ear fins, a mane of kelp-like locks that
## streams in the wind, and glowing SINDOOR eyes. Fin membranes and the foam where she breaks the surface use the
## translucent water_edge material. Menacing, never gory (§2).
##
## Named parts: "Body" (the serpent), "Head", "Jaw" (rotates for the mouth), "EyeL", "EyeR", "Mane".
## Everything hangs under "Rig", which sways slowly while the model is in the scene tree.
## Poses: idle, mouth_open, strike, kneel. The model stands at the origin (sea level) and faces -Z.

const POSES: Array[StringName] = [&"idle", &"mouth_open", &"strike", &"kneel"]
const TEAL: Color = Color("#123F4A")
const JAW_OPEN_ANGLE: float = 0.9
const HEAD_POSITION: Vector3 = Vector3(0.0, 9.6, -0.6)
const MANE_LOCKS: int = 16

const _BODY_POINTS: Array[Vector3] = [
	Vector3(1.6, -2.6, 3.6), Vector3(0.4, 0.3, 2.4), Vector3(2.0, 2.7, 1.7), Vector3(1.2, 5.0, 1.0),
	Vector3(-1.0, 6.9, 0.5), Vector3(-0.6, 8.5, 0.0), Vector3(0.0, 9.5, -0.3),
]
const _BODY_RADII: Array[float] = [2.4, 2.3, 2.1, 1.8, 1.5, 1.3, 1.25]


## Slow sway of the whole rig, so she is never perfectly still.
class Sway extends Node:
	var rig: Node3D = null
	var _time: float = 0.0

	func _process(delta: float) -> void:
		if rig == null:
			return
		_time += delta
		rig.rotation = Vector3(sin(_time * 0.47 + 1.0) * 0.022, 0.0, sin(_time * 0.63) * 0.032)


## Builds the model at the origin (sea level), facing -Z. The head rises about 10 m above the water.
static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Simhika"
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	_build_body(rig)
	_build_head(rig)
	var sway: Sway = Sway.new()
	sway.name = "Sway"
	sway.rig = rig
	root.add_child(sway)
	set_pose(root, &"idle")
	return root


## Applies a named pose. Unknown names fall back to idle.
static func set_pose(root: Node3D, pose: StringName) -> void:
	var head: Node3D = root.find_child("Head", true, false) as Node3D
	var jaw: Node3D = root.find_child("Jaw", true, false) as Node3D
	if head == null or jaw == null:
		return
	# Negative jaw pitch drops the jaw; negative head pitch bows the head toward the water.
	match pose:
		&"mouth_open":
			jaw.rotation.x = -JAW_OPEN_ANGLE
			head.rotation.x = 0.22
		&"strike":
			jaw.rotation.x = -0.4
			head.rotation.x = -0.4
		&"kneel":
			jaw.rotation.x = 0.0
			head.rotation.x = -0.75
		_:
			jaw.rotation.x = 0.0
			head.rotation.x = 0.0


# ---- colours -----------------------------------------------------------------------------------------

static func _deep() -> Color:
	return TEAL.lerp(Palette.NIGHT_INDIGO, 0.45).lightened(0.06)


static func _mid() -> Color:
	return TEAL.lerp(Palette.DEEP_OCEAN, 0.3).lightened(0.16)


static func _light() -> Color:
	return TEAL.lerp(Palette.GROVE_GREEN, 0.45).lightened(0.22)


static func _belly() -> Color:
	return TEAL.lerp(Palette.MOON, 0.42)


static func _bone() -> Color:
	return Palette.MOON


static func _membrane(alpha: float) -> Color:
	return Color(TEAL.lerp(Palette.GROVE_GREEN, 0.5).lightened(0.2), alpha)


# ---- body --------------------------------------------------------------------------------------------

static func _build_body(rig: Node3D) -> void:
	var body: Node3D = Node3D.new()
	body.name = "Body"
	rig.add_child(body)
	var pts: PackedVector3Array = PackedVector3Array(_BODY_POINTS)
	var rad: PackedVector2Array = PackedVector2Array()
	for r: float in _BODY_RADII:
		rad.append(Vector2(r, r * 0.92))
	var grad: PackedColorArray = PackedColorArray([_deep(), _deep(), _mid(), _mid(), _light(), _mid(), _light()])
	_add(body, "Serpent", RakshasaModel.tube(pts, rad, 14, grad, 4), &"lacquer_local")

	# Frames along the spine: belly plates on the front, a webbed crest of spines down the back.
	var frames: Array[Dictionary] = _frames(_BODY_POINTS, _BODY_RADII, 5)
	var plates: Array[Dictionary] = []
	var spines: Array[Dictionary] = []
	var crest_base: PackedVector3Array = PackedVector3Array()
	var crest_tip: PackedVector3Array = PackedVector3Array()
	for i: int in range(4, frames.size() - 1):
		var f: Dictionary = frames[i]
		var p: Vector3 = f["pos"] as Vector3
		var t: Vector3 = f["tangent"] as Vector3
		var back: Vector3 = f["back"] as Vector3
		var r: float = f["radius"] as float
		var side: Vector3 = t.cross(back).normalized()
		var basis: Basis = Basis(side, t, back)
		plates.append(RakshasaModel.ellipsoid(_belly().lerp(_light(), 0.5 * float(i % 2)), Vector3(r * 0.8, r * 0.42, r * 0.36), p - back * r * 0.66 + t * r * 0.1, basis * Basis(Vector3.RIGHT, 0.3), 4, 9))
		var tall: float = r * (0.75 + 0.45 * absf(sin(float(i) * 1.3)))
		var lean: Vector3 = (back * 1.0 - t * 0.35).normalized()
		if i % 2 == 0:
			spines.append(RakshasaModel.spike(_deep(), r * 0.13, tall + r * 0.3, p + back * r * 0.75, lean, 5))
		else:
			tall *= 0.72
		crest_base.append(p + back * r * 0.85)
		crest_tip.append(p + back * r * 0.8 + lean * tall)
	_add(body, "Belly", MeshKit.merge(plates), &"skin")
	_add(body, "CrestSpines", MeshKit.merge(spines), &"lacquer_local")
	var crest_rows: Array[PackedVector3Array] = [crest_base, crest_tip]
	_add(body, "Crest", RakshasaModel.grid_surface(crest_rows, PackedColorArray([_membrane(0.95), _membrane(0.55)]), false, Vector3.RIGHT), &"water_edge")

	# Pectoral fins spread from the upper body.
	for sgn: float in [-1.0, 1.0]:
		var origin: Vector3 = Vector3(0.3 + sgn * 1.5, 5.6, 0.7)
		var fin: Array[ArrayMesh] = _fin(origin, Vector3(sgn * 0.9, 0.55, 0.2), Vector3(sgn * 0.75, -0.55, 0.45), 4.6, 5, 0.2)
		var tag: String = "L" if sgn < 0.0 else "R"
		_add(body, "PectoralSpines" + tag, fin[0], &"lacquer_local")
		_add(body, "Pectoral" + tag, fin[1], &"water_edge")

	# A second coil arching out of the water behind her, and the tail with its fluke.
	_add(body, "Coil", RakshasaModel.tube(
		PackedVector3Array([Vector3(-4.6, -2.2, 4.6), Vector3(-4.0, 1.2, 5.6), Vector3(-2.2, 1.9, 6.9), Vector3(-0.9, -2.0, 7.6)]),
		PackedVector2Array([Vector2(1.7, 1.6), Vector2(1.6, 1.5), Vector2(1.45, 1.35), Vector2(1.3, 1.2)]), 12, PackedColorArray([_deep(), _mid(), _deep()]), 4), &"lacquer_local")
	_add(body, "Tail", RakshasaModel.tube(
		PackedVector3Array([Vector3(3.6, -2.0, 6.6), Vector3(4.4, 1.2, 7.4), Vector3(3.9, 3.6, 8.0), Vector3(2.9, 5.0, 8.3)]),
		PackedVector2Array([Vector2(1.0, 0.95), Vector2(0.8, 0.75), Vector2(0.5, 0.45), Vector2(0.14, 0.14)]), 10, PackedColorArray([_deep(), _mid(), TEAL]), 4), &"lacquer_local")
	var fluke: Array[ArrayMesh] = _fin(Vector3(3.0, 4.9, 8.3), Vector3(-0.9, 0.75, 0.1), Vector3(0.55, 1.0, 0.25), 2.6, 5, 0.1)
	_add(body, "FlukeSpines", fluke[0], &"lacquer_local")
	_add(body, "Fluke", fluke[1], &"water_edge")

	# Foam where she breaks the surface.
	var foam: Array[Dictionary] = []
	for ring: Vector3 in [Vector3(0.55, 2.5, 2.6), Vector3(-4.35, 2.0, 5.0), Vector3(-1.35, 1.7, 7.3), Vector3(3.9, 1.4, 7.0)]:
		foam.append(RakshasaModel.part(_foam_ring(Vector3(ring.x, 0.06, ring.z), ring.y)))
	_add(body, "Foam", MeshKit.merge(foam), &"water_edge")


## Position, tangent, back vector and radius at every sample of the body spline.
static func _frames(points: Array[Vector3], radii: Array[float], subdiv: int) -> Array[Dictionary]:
	var samples: Array[Vector3] = []
	var sample_r: Array[float] = []
	var n: int = points.size()
	for i: int in range(n - 1):
		for s: int in range(subdiv):
			var t: float = float(s) / float(subdiv)
			samples.append(points[i].cubic_interpolate(points[i + 1], points[maxi(i - 1, 0)], points[mini(i + 2, n - 1)], t))
			sample_r.append(lerpf(radii[i], radii[i + 1], t))
	samples.append(points[n - 1])
	sample_r.append(radii[n - 1])
	var out: Array[Dictionary] = []
	for i: int in range(samples.size()):
		var tangent: Vector3 = (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var back: Vector3 = (Vector3.BACK - tangent * Vector3.BACK.dot(tangent)).normalized()
		out.append({"pos": samples[i], "tangent": tangent, "back": back, "radius": sample_r[i]})
	return out


## A webbed fin: spines fanning from `origin` between directions `from` and `to`, joined by a membrane.
## Returns [spines mesh, membrane mesh]. `droop` bends the spine tips down.
static func _fin(origin: Vector3, from: Vector3, to: Vector3, length: float, spines_n: int, droop: float) -> Array[ArrayMesh]:
	var parts: Array[Dictionary] = []
	var inner: PackedVector3Array = PackedVector3Array()
	var mid_row: PackedVector3Array = PackedVector3Array()
	var outer: PackedVector3Array = PackedVector3Array()
	var normal: Vector3 = from.cross(to).normalized()
	for i: int in range(spines_n):
		var u: float = float(i) / float(spines_n - 1)
		var dir: Vector3 = from.normalized().slerp(to.normalized(), u)
		var len: float = length * (0.62 + 0.38 * sin(lerpf(0.35, 1.0, 1.0 - u) * PI * 0.5))
		var mid: Vector3 = origin + dir * len * 0.55 + normal * len * 0.06
		var tip: Vector3 = origin + dir * len + Vector3.DOWN * len * droop
		parts.append(RakshasaModel.part(RakshasaModel.tube(PackedVector3Array([origin, mid, tip]), PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.12, 0.12), Vector2.ZERO]), 5, PackedColorArray([_deep(), _mid(), _light()]), 3)))
		inner.append(origin + dir * 0.3)
		mid_row.append(mid)
		# The membrane is scalloped: it stops short of each spine tip.
		outer.append(origin.lerp(tip, 0.9) + (mid - origin.lerp(tip, 0.55)) * 0.2)
	var rows: Array[PackedVector3Array] = [inner, mid_row, outer]
	var membrane: ArrayMesh = RakshasaModel.grid_surface(rows, PackedColorArray([_membrane(0.95), _membrane(0.8), _membrane(0.45)]), false, normal)
	return [MeshKit.merge(parts), membrane]


## Flat ring of foam on the water: opaque and pale at the body, fading outward.
static func _foam_ring(center: Vector3, radius: float) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	for k: int in range(3):
		var row: PackedVector3Array = PackedVector3Array()
		var r: float = radius * (0.97 + 0.09 * float(k))
		for i: int in range(18):
			var a: float = TAU * float(i) / 18.0
			var wobble: float = 1.0 + 0.09 * sin(a * 5.0 + float(k) * 1.7)
			row.append(center + Vector3(cos(a) * r * wobble, 0.02 * float(k), sin(a) * r * wobble))
		rows.append(row)
	var pale: Color = Palette.MOON
	# Wrapped rows give outward normals; the water_edge material is double-sided, so the ring shows from above.
	return RakshasaModel.grid_surface(rows, PackedColorArray([Color(pale, 0.95), Color(pale, 0.6), Color(pale, 0.0)]), true)


# ---- head --------------------------------------------------------------------------------------------

static func _build_head(rig: Node3D) -> void:
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = HEAD_POSITION
	rig.add_child(head)
	var deep: Color = _deep()

	# Skull and upper muzzle, cheeks, nostrils, brow ridges.
	var skull: Array[Dictionary] = []
	skull.append(RakshasaModel.ellipsoid(TEAL, Vector3(1.6, 1.4, 1.75), Vector3(0.0, 0.1, 0.1), Basis.IDENTITY, 9, 14))
	skull.append(RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 0.05, -0.4), Vector3(0.0, -0.1, -1.7), Vector3(0.0, -0.3, -2.7), Vector3(0.0, -0.42, -3.15)]),
		PackedVector2Array([Vector2(1.4, 1.05), Vector2(1.12, 0.72), Vector2(0.9, 0.5), Vector2(0.5, 0.26)]), 12, PackedColorArray([TEAL, _mid(), _light()]), 3, Vector3.UP)))
	for sgn: float in [-1.0, 1.0]:
		skull.append(RakshasaModel.ellipsoid(_mid(), Vector3(0.4, 0.42, 0.95), Vector3(sgn * 1.02, -0.3, -0.7), Basis(Vector3.UP, sgn * 0.25), 5, 8))
		skull.append(RakshasaModel.ellipsoid(deep, Vector3(0.13, 0.07, 0.2), Vector3(sgn * 0.3, -0.12, -3.2), Basis(Vector3.UP, sgn * 0.5), 4, 6))
		skull.append(RakshasaModel.ellipsoid(deep, Vector3(0.95, 0.3, 0.75), Vector3(sgn * 0.8, 0.82, -1.2), Basis(Vector3.BACK, sgn * 0.45) * Basis(Vector3.RIGHT, 0.35), 6, 10))
		skull.append(RakshasaModel.ellipsoid(deep, Vector3(0.5, 0.28, 0.4), Vector3(sgn * 0.85, 0.38, -1.38), Basis.IDENTITY, 5, 8))
	skull.append(RakshasaModel.ellipsoid(_mid(), Vector3(0.5, 0.3, 1.2), Vector3(0.0, 0.5, -1.8), Basis(Vector3.RIGHT, 0.12), 5, 8))
	_add(head, "Skull", MeshKit.merge(skull), &"lacquer_local")
	# The dark maw behind the teeth.
	_add(head, "Maw", MeshKit.merge([
		RakshasaModel.ellipsoid(Palette.RAKSHASA_ARMOR.darkened(0.45), Vector3(0.95, 0.35, 1.5), Vector3(0.0, -0.72, -1.2), Basis.IDENTITY, 5, 10),
	]), &"skin")

	# Eyes: slanted, glowing sindoor.
	for sgn2: float in [-1.0, 1.0]:
		var eye: ArrayMesh = MeshKit.merge([RakshasaModel.ellipsoid(Palette.SINDOOR, Vector3(0.4, 0.17, 0.24), Vector3.ZERO, Basis(Vector3.BACK, sgn2 * 0.4), 5, 10)])
		var eye_node: MeshInstance3D = _add(head, "EyeL" if sgn2 < 0.0 else "EyeR", eye, &"")
		eye_node.position = Vector3(sgn2 * 0.85, 0.5, -1.62)
		eye_node.material_override = RakshasaModel.glow_material()

	# Horns sweeping back, and a crown of bony points.
	var horns: Array[Dictionary] = []
	for sgn3: float in [-1.0, 1.0]:
		horns.append(RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([Vector3(sgn3 * 0.9, 1.0, -0.3), Vector3(sgn3 * 1.7, 2.0, 0.5), Vector3(sgn3 * 2.0, 3.1, 1.7), Vector3(sgn3 * 1.5, 3.7, 3.0)]),
			PackedVector2Array([Vector2(0.42, 0.42), Vector2(0.34, 0.34), Vector2(0.2, 0.2), Vector2.ZERO]), 8, PackedColorArray([deep, deep, _mid(), _bone()]), 3)))
	for i: int in range(5):
		var a: float = (float(i) - 2.0) * 0.38
		horns.append(RakshasaModel.spike(deep.lerp(_bone(), 0.25), 0.2, 0.9 - absf(a) * 0.4, Vector3(sin(a) * 1.3, 1.25 + cos(a) * 0.1, -0.5 + absf(a) * 0.4), Vector3(sin(a), 1.0, 0.25), 6))
	_add(head, "Horns", MeshKit.merge(horns), &"skin")

	# Webbed ear fins.
	for sgn4: float in [-1.0, 1.0]:
		var fin: Array[ArrayMesh] = _fin(Vector3(sgn4 * 1.35, 0.2, 0.4), Vector3(sgn4 * 0.75, 0.85, 0.35), Vector3(sgn4 * 0.9, -0.5, 0.6), 2.5, 4, 0.05)
		var tag: String = "L" if sgn4 < 0.0 else "R"
		_add(head, "EarSpines" + tag, fin[0], &"lacquer_local")
		_add(head, "Ear" + tag, fin[1], &"water_edge")

	# Upper teeth: two great fangs and a row of smaller ones.
	var teeth: Array[Dictionary] = []
	for sgn5: float in [-1.0, 1.0]:
		teeth.append(RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([Vector3(sgn5 * 0.62, -0.6, -2.55), Vector3(sgn5 * 0.68, -1.15, -2.7), Vector3(sgn5 * 0.6, -1.75, -2.55)]),
			PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.15, 0.15), Vector2.ZERO]), 7, PackedColorArray([_bone()]), 3)))
		for k: int in range(4):
			teeth.append(RakshasaModel.spike(_bone(), 0.11, 0.42 - 0.04 * float(k), Vector3(sgn5 * (0.82 + 0.07 * float(k)), -0.62, -2.0 + 0.42 * float(k)), Vector3(0.0, -1.0, 0.05), 5))
	teeth.append(RakshasaModel.spike(_bone(), 0.1, 0.36, Vector3(0.22, -0.62, -3.0), Vector3.DOWN, 5))
	teeth.append(RakshasaModel.spike(_bone(), 0.1, 0.36, Vector3(-0.22, -0.62, -3.0), Vector3.DOWN, 5))
	_add(head, "Fangs", MeshKit.merge(teeth), &"skin")

	_build_mane(head)

	# Lower jaw with its own fangs; it rotates about the hinge for the mouth poses.
	var jaw: Node3D = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0.0, -0.9, -0.4)
	head.add_child(jaw)
	var jaw_parts: Array[Dictionary] = []
	jaw_parts.append(RakshasaModel.part(RakshasaModel.tube(
		PackedVector3Array([Vector3(0.0, 0.1, 0.5), Vector3(0.0, -0.2, -0.9), Vector3(0.0, -0.22, -2.1), Vector3(0.0, -0.05, -2.75)]),
		PackedVector2Array([Vector2(1.3, 0.6), Vector2(1.08, 0.5), Vector2(0.82, 0.36), Vector2(0.4, 0.18)]), 12, PackedColorArray([deep, deep, _mid()]), 3, Vector3.UP)))
	jaw_parts.append(RakshasaModel.ellipsoid(_mid(), Vector3(0.5, 0.3, 0.45), Vector3(0.0, -0.3, -2.4), Basis.IDENTITY, 5, 8))
	_add(jaw, "JawMesh", MeshKit.merge(jaw_parts), &"lacquer_local")
	_add(jaw, "Tongue", MeshKit.merge([
		RakshasaModel.ellipsoid(Palette.RAKSHASA_ARMOR.lerp(Palette.SINDOOR, 0.35), Vector3(0.55, 0.14, 1.2), Vector3(0.0, 0.12, -1.2), Basis.IDENTITY, 5, 9),
	]), &"skin")
	var lower: Array[Dictionary] = []
	for sgn6: float in [-1.0, 1.0]:
		lower.append(RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([Vector3(sgn6 * 0.5, 0.0, -2.3), Vector3(sgn6 * 0.56, 0.5, -2.42), Vector3(sgn6 * 0.5, 1.0, -2.3)]),
			PackedVector2Array([Vector2(0.17, 0.17), Vector2(0.12, 0.12), Vector2.ZERO]), 6, PackedColorArray([_bone()]), 3)))
		for k2: int in range(4):
			lower.append(RakshasaModel.spike(_bone(), 0.1, 0.36 - 0.03 * float(k2), Vector3(sgn6 * (0.72 + 0.08 * float(k2)), 0.1, -1.85 + 0.42 * float(k2)), Vector3.UP, 5))
	_add(jaw, "LowerFang", MeshKit.merge(lower), &"skin")


## The mane: long flattened locks from the crown and the back of the skull, free at their tips.
static func _build_mane(head: Node3D) -> void:
	var mane: Node3D = Node3D.new()
	mane.name = "Mane"
	mane.position = Vector3(0.0, 0.0, 0.7)
	head.add_child(mane)
	var root_col: Color = Color(_deep(), 0.0)
	var mid_col: Color = Color(TEAL.lerp(Palette.GROVE_GREEN, 0.3), 0.35)
	var tip_col: Color = Color(Palette.GROVE_GREEN.lightened(0.25), 1.0)
	var group: Array[Dictionary] = []
	for k: int in range(MANE_LOCKS):
		# Locks ring the back of the head from one cheek, over the crown, to the other.
		var u: float = float(k) / float(MANE_LOCKS - 1)
		var a: float = lerpf(-0.75, PI + 0.75, u)
		var outward: Vector3 = Vector3(cos(a), sin(a), 0.0)
		var len: float = 3.4 + 1.5 * absf(sin(float(k) * 2.1)) + (1.2 if sin(a) < 0.2 else 0.0)
		var start: Vector3 = outward * 1.25 + Vector3(0.0, 0.1, -0.25 + 0.3 * absf(cos(float(k) * 1.7)))
		var p1: Vector3 = start + outward * 0.9 + Vector3(0.0, 0.15, 0.7)
		var p2: Vector3 = p1 + outward * 0.35 + Vector3(0.0, -len * 0.45, 0.8)
		var p3: Vector3 = p2 + Vector3(sin(float(k) * 3.3) * 0.5, -len * 0.55, 0.5)
		group.append(RakshasaModel.part(RakshasaModel.tube(
			PackedVector3Array([start, p1, p2, p3]),
			PackedVector2Array([Vector2(0.42, 0.26), Vector2(0.5, 0.24), Vector2(0.36, 0.16), Vector2(0.03, 0.02)]), 5, PackedColorArray([root_col, mid_col, tip_col]), 2, outward)))
		if k % 4 == 3 or k == MANE_LOCKS - 1:
			_add(mane, "Mane%d" % (k / 4), MeshKit.merge(group), &"cloth")
			group = []


## Adds a MeshInstance3D with the material of a Materials kind (an empty kind leaves the material unset).
static func _add(parent: Node3D, part_name: String, mesh: Mesh, kind: StringName) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	if kind != &"":
		mi.material_override = Materials.get_material(kind)
	parent.add_child(mi)
	return mi
