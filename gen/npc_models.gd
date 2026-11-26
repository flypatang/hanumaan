class_name NpcModels
extends RefCounted
## Story characters and set-piece figures (DESIGN §9 M36, art pass B3 per docs/ART.md "Painted Temple").
##
## Every figure is sculpted from smooth forms built here on top of MeshKit: lathes (bodies, drapery, crowns),
## swept tubes (limbs, tails, bows, the naga's coils), ellipsoids and thin cloth shells. Each node is one
## MeshKit.multi() mesh with one surface per Materials kind (skin, fur, cloth, gold, wood, lacquer, stone, foliage).
## Vertex colour alpha is the wind weight: bodies are rigid (0) and hems of drapery sway gently.
##
## Structure of a figure (forward is -Z, feet on y = 0):
##   root "Npc_<id>"
##     Legs, Garment, (Tail, props planted on the ground)   - still
##     Upper (pivot at the hips; breathes)                   - Torso, Arms, Head, Ornaments, crowns, held props
##     Idle (AnimationPlayer, autoplays the looping "idle" breathing animation)
## Sita is seated (Lap instead of Legs and Garment; her pallu is "Sita_Pallu"); Ravana's ten faces are the children
## of "Heads" directly under the root; Mainaka and Surasa are set pieces with their own parts.
## There are no skeletons, so set_pose is a safe no-op kept for API parity with HanumanModel.
##
## Depiction rules (DESIGN §2): Sita is dignified, seated, her head covered by her pallu, eyes lowered; Rama is
## serene and reverent, his right hand raised in blessing, never in a combat stance. Both carry a faint additive
## aura (node "<Name>_Aura"). Nobody is comic. Ravana is regal and imposing rather than monstrous.
##
## Ids: jambavan, angada, vanara (or vanara_<seed>), sita, trijata, rakshasi, ravana, vibhishana, indrajit,
## courtier, rama, mainaka, surasa. Unknown ids fall back to vanara.

## Extra colour constants beyond Palette (documented here; see allowed_colors()). Vertex colours are these or
## Palette colours, or a shaded blend of two of them.
const BEAR_FUR: Color = Color("#3A2C26")
const BEAR_MUZZLE: Color = Color("#6B5646")
const BROW_WHITE: Color = Color("#EEE8DA")
const HUMAN_SKIN: Color = Color("#D9A878")
const SARI_SOILED: Color = Color("#CDB57C")
const SARI_HEM: Color = Color("#A8935F")
const RAMA_SKIN: Color = Color("#2E4A7A")
const DHOTI_YELLOW: Color = Color("#E8C23A")
const ELDER_HAIR: Color = Color("#BDB8C8")
const RAKSHASA_PALE: Color = Color("#8A7DB5")
const EMERALD: Color = Color("#1F8A5B")
const GOLD_DARK: Color = Color("#C99A2E")
const VANARA_GREY: Color = Color("#8C8C86")
const HAIR_BLACK: Color = Color("#1C1622")
const LIP_ROSE: Color = Color("#B4544C")

const _AURA_SHADER: String = """shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, shadows_disabled;
// A soft additive halo: only the far half of an enveloping shell is drawn, brightest behind the figure and
// fading to nothing at the shell's silhouette. Orthographic cameras have a constant view direction.
uniform float strength = 0.3;
uniform float power = 2.0;
varying vec3 v_color;
void vertex() {
	v_color = pow(COLOR.rgb, vec3(2.2));
}
void fragment() {
	vec3 view_dir = PROJECTION_MATRIX[3][3] != 0.0 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW);
	float facing = abs(dot(normalize(NORMAL), view_dir));
	ALBEDO = v_color;
	ALPHA = pow(facing, power) * strength;
}
"""

static var _aura_shader: Shader = null
static var _balls: Dictionary = {}


static func allowed_colors() -> Array[Color]:
	return [
		Palette.SAFFRON, Palette.SINDOOR, Palette.GOLD, Palette.HANUMAN_FUR, Palette.DEEP_OCEAN, Palette.NIGHT_INDIGO,
		Palette.MOON, Palette.GROVE_GREEN, Palette.ASHOKA_RED, Palette.RAKSHASA_SKIN, Palette.RAKSHASA_ARMOR,
		Palette.STONE, Palette.FIRE_CORE, Palette.FIRE_EDGE, Palette.UI_DARK, Palette.BARK, Palette.LEAF_DARK,
		Palette.SKY_DUSK, BEAR_FUR, BEAR_MUZZLE, BROW_WHITE, HUMAN_SKIN, SARI_SOILED, SARI_HEM, RAMA_SKIN,
		DHOTI_YELLOW, ELDER_HAIR, RAKSHASA_PALE, EMERALD, GOLD_DARK, VANARA_GREY, HAIR_BLACK, LIP_ROSE,
	]


static func build(id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Npc_" + String(id)
	var sid: String = String(id)
	if sid.begins_with("vanara"):
		var seed_value: int = 0
		if sid.length() > 7:
			seed_value = sid.substr(7).to_int()
		_vanara(root, seed_value)
		return root
	match id:
		&"jambavan":
			_jambavan(root)
		&"angada":
			_angada(root)
		&"sita":
			_sita(root)
		&"trijata":
			_trijata(root)
		&"rakshasi":
			_rakshasi(root)
		&"ravana":
			_ravana(root)
		&"vibhishana":
			_vibhishana(root)
		&"indrajit":
			_indrajit(root)
		&"courtier":
			_courtier(root)
		&"rama":
			_rama(root)
		&"mainaka":
			_mainaka(root)
		&"surasa":
			_surasa(root)
		_:
			_vanara(root, 0)
	return root


## All figures are static apart from their breathing loop, so every pose is the same idle stance.
static func set_pose(_root: Node3D, _pose: StringName) -> void:
	pass


# ================================================================ sculpting kit

## Catmull-Rom subdivision of a polyline (`sub` points per segment).
static func _cr3(p: PackedVector3Array, sub: int) -> PackedVector3Array:
	var n: int = p.size()
	if sub <= 1 or n < 3:
		return p
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in n - 1:
		var a: Vector3 = p[maxi(i - 1, 0)]
		var d: Vector3 = p[mini(i + 2, n - 1)]
		for s: int in sub:
			out.append(p[i].cubic_interpolate(p[i + 1], a, d, float(s) / float(sub)))
	out.append(p[n - 1])
	return out


static func _cr2(p: PackedVector2Array, sub: int) -> PackedVector2Array:
	var n: int = p.size()
	if sub <= 1 or n < 3:
		return p
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n - 1:
		var a: Vector2 = p[maxi(i - 1, 0)]
		var d: Vector2 = p[mini(i + 2, n - 1)]
		for s: int in sub:
			out.append(p[i].cubic_interpolate(p[i + 1], a, d, float(s) / float(sub)))
	out.append(p[n - 1])
	return out


static func _crf(p: PackedFloat32Array, sub: int) -> PackedFloat32Array:
	var n: int = p.size()
	if sub <= 1 or n < 3:
		return p
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in n - 1:
		var a: float = p[maxi(i - 1, 0)]
		var d: float = p[mini(i + 2, n - 1)]
		for s: int in sub:
			out.append(maxf(0.0, cubic_interpolate(p[i], p[i + 1], a, d, float(s) / float(sub))))
	out.append(p[n - 1])
	return out


## Smooth-shaded mesh from a grid of points (rows x columns, every row the same length). `wrap` joins the last
## column to the first (lathes, tubes); rows whose points coincide are poles. Closed shapes are oriented outward
## automatically. With `shell` > 0 the grid is an open sheet of cloth and gets a second, inner side that far apart.
static func _grid(pts: Array[PackedVector3Array], cols: Array[PackedColorArray], wrap: bool, shell: float = 0.0) -> ArrayMesh:
	var rows: int = pts.size()
	var n: int = pts[0].size()
	var cents: PackedVector3Array = PackedVector3Array()
	for i: int in rows:
		var c: Vector3 = Vector3.ZERO
		for p: Vector3 in pts[i]:
			c += p
		cents.append(c / float(n))
	var fp: PackedVector3Array = PackedVector3Array()
	var fn: PackedVector3Array = PackedVector3Array()
	var fc: PackedColorArray = PackedColorArray()
	fp.resize(rows * n)
	fn.resize(rows * n)
	fc.resize(rows * n)
	var vote: float = 0.0
	var up_vote: float = 0.0
	var pole_rows: PackedInt32Array = PackedInt32Array()
	for i: int in rows:
		var i0: int = maxi(i - 1, 0)
		var i1: int = mini(i + 1, rows - 1)
		var is_pole: bool = wrap and pts[i][0].distance_squared_to(pts[i][n / 2]) < 1e-12
		if is_pole:
			pole_rows.append(i)
		for j: int in n:
			var j0: int = (j - 1 + n) % n if wrap else maxi(j - 1, 0)
			var j1: int = (j + 1) % n if wrap else mini(j + 1, n - 1)
			var k: int = i * n + j
			fp[k] = pts[i][j]
			fc[k] = cols[i][j]
			var nn: Vector3 = Vector3.UP
			if is_pole:
				nn = cents[i] - (cents[i1] if i == 0 else cents[i0])
			else:
				nn = (pts[i][j1] - pts[i][j0]).cross(pts[i1][j] - pts[i0][j])
			if nn.length_squared() < 1e-18:
				nn = pts[i][j] - cents[i]
			if nn.length_squared() < 1e-18:
				nn = Vector3.UP
			nn = nn.normalized()
			if not is_pole:
				vote += nn.dot(pts[i][j] - cents[i])
				up_vote += nn.y
			fn[k] = nn
	var flip: bool = vote < -1e-6 or (absf(vote) <= 1e-6 and up_vote < 0.0)
	if flip and shell <= 0.0:
		for i: int in rows:
			if pole_rows.has(i):
				continue
			for j: int in n:
				fn[i * n + j] = -fn[i * n + j]
	var out_v: PackedVector3Array = PackedVector3Array()
	var out_n: PackedVector3Array = PackedVector3Array()
	var out_c: PackedColorArray = PackedColorArray()
	var jn: int = n if wrap else n - 1
	var sides: int = 2 if shell > 0.0 else 1
	for side: int in sides:
		var sgn: float = 1.0 if side == 0 else -1.0
		var push: float = 0.0 if side == 0 else shell
		for i: int in rows - 1:
			for j: int in jn:
				var a: int = i * n + j
				var b: int = i * n + (j + 1) % n
				var c2: int = (i + 1) * n + (j + 1) % n
				var d: int = (i + 1) * n + j
				for tri: int in 2:
					var t0: int = a
					var t1: int = b if tri == 0 else c2
					var t2: int = c2 if tri == 0 else d
					var p0: Vector3 = fp[t0] - fn[t0] * push
					var p1: Vector3 = fp[t1] - fn[t1] * push
					var p2: Vector3 = fp[t2] - fn[t2] * push
					var face: Vector3 = (p2 - p0).cross(p1 - p0)
					if face.length_squared() < 1e-20:
						continue
					if face.dot(fn[t0] + fn[t1] + fn[t2]) * sgn < 0.0:
						var ti: int = t1
						t1 = t2
						t2 = ti
						var tp: Vector3 = p1
						p1 = p2
						p2 = tp
					out_v.append(p0)
					out_v.append(p1)
					out_v.append(p2)
					out_n.append(fn[t0] * sgn)
					out_n.append(fn[t1] * sgn)
					out_n.append(fn[t2] * sgn)
					out_c.append(fc[t0])
					out_c.append(fc[t1])
					out_c.append(fc[t2])
	var mesh: ArrayMesh = ArrayMesh.new()
	if out_v.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_COLOR] = out_c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _rigid(c: Color, wind: float = 0.0) -> Color:
	return Color(c.r, c.g, c.b, wind)


## Surface of revolution around Y. `prof` holds (radius, y) from bottom to top; `sq` squashes the X and Z radii.
## Colour runs from `c_lo` at the bottom to `c_hi` at the top. `folds` > 0 adds drapery pleats of relative depth
## `fold_amp` that deepen toward the hem (valleys are shaded toward `c_lo`), and `wind` is the wind weight of the
## hem (the top stays pinned).
static func _lathe(prof: PackedVector2Array, segs: int, c_lo: Color, c_hi: Color, sq: Vector2 = Vector2.ONE, folds: int = 0, fold_amp: float = 0.0, wind: float = 0.0) -> ArrayMesh:
	var y0: float = prof[0].y
	var y1: float = prof[prof.size() - 1].y
	var span: float = maxf(absf(y1 - y0), 1e-6)
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var count: int = prof.size()
	for i: int in range(-1, count + 1):
		var pr: Vector2 = prof[clampi(i, 0, count - 1)]
		var r: float = pr.x if (i >= 0 and i < count) else 0.0
		var t: float = clampf((pr.y - y0) / span, 0.0, 1.0)
		var free: float = 1.0 - t
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		var base: Color = c_lo.lerp(c_hi, t)
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var wave: float = sin(float(folds) * a + pr.y * 3.0) if folds > 0 else 0.0
			var rr: float = r * (1.0 + fold_amp * free * wave)
			row.append(Vector3(sin(a) * rr * sq.x, pr.y, cos(a) * rr * sq.y))
			var col: Color = base
			if folds > 0:
				col = base.lerp(c_lo, 0.45 * free * (0.5 - 0.5 * wave))
			crow.append(_rigid(col, wind * free))
		pts.append(row)
		cols.append(crow)
	return _grid(pts, cols, true)


## Tube swept along `path` (Catmull-Rom subdivided `sub` times) with a radius per control point (one value = a
## constant radius). `wide` optionally stretches each ring along the frame's first axis, which starts as `ref`
## projected off the path. Colours: `col` alone; or with `col2` a gradient along the length (stripe 0), bands
## of `stripe` rings (stripe > 0), or a belly colour on the side facing -Y (stripe -1) or -Z (stripe -2).
## `wind` is the wind weight reached at the end of the path.
static func _tube(path: PackedVector3Array, radii: PackedFloat32Array, segs: int, col: Color, sub: int = 3, wide: PackedFloat32Array = PackedFloat32Array(), ref: Vector3 = Vector3.RIGHT, col2: Color = Color(0.0, 0.0, 0.0, -1.0), stripe: int = 0, wind: float = 0.0) -> ArrayMesh:
	var p: PackedVector3Array = _cr3(path, sub)
	var count: int = p.size()
	var rad: PackedFloat32Array = radii
	if rad.size() == 1:
		rad = PackedFloat32Array()
		rad.resize(path.size())
		rad.fill(radii[0])
	rad = _crf(rad, sub)
	var wid: PackedFloat32Array = _crf(wide, sub) if wide.size() == path.size() else PackedFloat32Array()
	var has2: bool = col2.a >= 0.0
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var normal: Vector3 = ref
	for i: int in range(-1, count + 1):
		var ci: int = clampi(i, 0, count - 1)
		var tangent: Vector3 = (p[mini(ci + 1, count - 1)] - p[maxi(ci - 1, 0)]).normalized()
		normal = normal - tangent * normal.dot(tangent)
		if normal.length_squared() < 1e-8:
			normal = tangent.cross(Vector3.UP)
			if normal.length_squared() < 1e-8:
				normal = tangent.cross(Vector3.RIGHT)
		normal = normal.normalized()
		var binormal: Vector3 = tangent.cross(normal)
		var r: float = rad[ci] if (i >= 0 and i < count) else 0.0
		var w: float = wid[ci] if wid.size() == count else 1.0
		var t: float = float(ci) / float(maxi(count - 1, 1))
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var off: Vector3 = normal * (cos(a) * w) + binormal * sin(a)
			row.append(p[ci] + off * r)
			var c: Color = col
			if has2:
				if stripe == 0:
					c = col.lerp(col2, t)
				elif stripe > 0:
					c = col2 if (ci / stripe) % 2 == 1 else col
				else:
					var toward: float = -off.y if stripe == -1 else -off.z
					var under: float = smoothstep(0.25, 0.8, toward / maxf(w, 1.0) if stripe == -1 else toward)
					# Saddle bands of darker scales across the back.
					c = col.lerp(col2, under) if under > 0.0 else col.lerp(Palette.UI_DARK, 0.42 * smoothstep(0.35, 0.75, 0.5 + 0.5 * sin(float(ci) * 0.9)))
			crow.append(_rigid(c, wind * t))
		pts.append(row)
		cols.append(crow)
	return _grid(pts, cols, true)


## Cached unit sphere of one colour (smooth, rigid). lod 0 = tiny details, 1 = forms, 2 = close-up forms.
static func _unit_ball(col: Color, lod: int) -> ArrayMesh:
	var key: String = "%s_%d" % [col.to_html(false), lod]
	if _balls.has(key):
		return _balls[key] as ArrayMesh
	var rings: int = 4 + 2 * lod
	var segs: int = 6 + 3 * lod
	var mesh: ArrayMesh = MeshKit.with_wind(MeshKit.sphere(1.0, rings, segs, col, true), 0.0)
	_balls[key] = mesh
	return mesh


static func _basis_y(dir: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	if d.dot(Vector3.UP) < -0.9995:
		return Basis.from_euler(Vector3(PI, 0.0, 0.0))
	if d.dot(Vector3.UP) > 0.9995:
		return Basis.IDENTITY
	return Basis(Quaternion(Vector3.UP, d))


## Adds a mesh to group `g` of kit `k` under material `kind`.
static func _put(k: Dictionary, g: String, kind: StringName, mesh: ArrayMesh, xf: Transform3D = Transform3D.IDENTITY) -> void:
	if not k.has(g):
		k[g] = {}
	var group: Dictionary = k[g] as Dictionary
	if not group.has(kind):
		group[kind] = []
	(group[kind] as Array).append({"mesh": mesh, "transform": xf})


## Adds an ellipsoid with radii `size`, optionally rotated by `basis`.
static func _ball(k: Dictionary, g: String, kind: StringName, pos: Vector3, size: Vector3, col: Color, basis: Basis = Basis.IDENTITY, lod: int = 1) -> void:
	_put(k, g, kind, _unit_ball(col, lod), Transform3D(basis * Basis.from_scale(size), pos))


static func _orb(k: Dictionary, g: String, kind: StringName, pos: Vector3, r: float, col: Color, lod: int = 0) -> void:
	_ball(k, g, kind, pos, Vector3(r, r, r), col, Basis.IDENTITY, lod)


## Turns group `g` into a MeshInstance3D named `node_name` under `parent` (null when the group is empty).
static func _emit(parent: Node3D, k: Dictionary, g: String, node_name: String, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if not k.has(g):
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = MeshKit.multi(k[g] as Dictionary)
	mi.position = offset
	parent.add_child(mi)
	return mi


## A faint additive halo shell (see _AURA_SHADER). `mesh` should loosely envelop the figure.
static func _aura(parent: Node3D, node_name: String, mesh: ArrayMesh, strength: float, power: float = 2.0) -> MeshInstance3D:
	if _aura_shader == null:
		_aura_shader = Shader.new()
		_aura_shader.code = _AURA_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _aura_shader
	mat.set_shader_parameter(&"strength", strength)
	mat.set_shader_parameter(&"power", power)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The breathing pivot: a Node3D named "Upper" at `pivot`, leaning forward by `stoop` radians.
static func _upper(root: Node3D, pivot: Vector3, stoop: float = 0.0) -> Node3D:
	var upper: Node3D = Node3D.new()
	upper.name = "Upper"
	upper.position = pivot
	upper.rotation.x = -stoop
	root.add_child(upper)
	return upper


## Adds the looping "idle" animation: each node of `paths` swells by `amount` and settles again.
static func _idle(root: Node3D, paths: Array[String], amount: Vector3, period: float) -> void:
	var anim: Animation = Animation.new()
	anim.length = period
	anim.loop_mode = Animation.LOOP_LINEAR
	for i: int in paths.size():
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("%s:scale" % paths[i]))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var lag: float = 0.12 * period * float(i)
		anim.track_insert_key(track, 0.0, Vector3.ONE)
		anim.track_insert_key(track, minf(period * 0.45 + lag, period * 0.8), Vector3.ONE + amount)
		anim.track_insert_key(track, period, Vector3.ONE)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"idle", anim)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "Idle"
	player.add_animation_library(&"", library)
	player.autoplay = "idle"
	root.add_child(player)


# ================================================================ heads and faces

## A point on the face of a head of radius `r` centred on `c`: `x`, `y` in head radii, `out` lifts it off the skin.
static func _fp(c: Vector3, r: float, jaw: float, x: float, y: float, out: float = 0.0) -> Vector3:
	var sy: float = clampf(y / 1.06, -0.98, 0.98)
	var cy: float = sqrt(1.0 - sy * sy)
	var t: float = clampf(-sy, 0.0, 1.0)
	var wx: float = 0.86 * (1.0 - (1.0 - jaw) * pow(t, 1.6))
	var dx: float = clampf(x / (cy * wx), -0.98, 0.98)
	var dz: float = -sqrt(1.0 - dx * dx)
	var zf: float = 1.0 - 0.10 * t * (-dz)
	var p: Vector3 = Vector3(dx * cy * wx, sy * 1.06, dz * cy * 0.96 * zf)
	var n: Vector3 = Vector3(dx * cy, sy, dz * cy).normalized()
	return c + (p + n * out) * r


## An oval skull: widest at the temples, tapering to the chin by `jaw` (1 = round, 0.6 = slender).
static func _skull(c: Vector3, r: float, col: Color, jaw: float, rows: int = 12, segs: int = 18) -> ArrayMesh:
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i: int in rows + 1:
		var v: float = -PI * 0.5 + PI * float(i) / float(rows)
		var sy: float = sin(v)
		var cy: float = maxf(cos(v), 0.0)
		if i == 0 or i == rows:
			cy = 0.0
		var t: float = clampf(-sy, 0.0, 1.0)
		var wx: float = 0.86 * (1.0 - (1.0 - jaw) * pow(t, 1.6))
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var dx: float = sin(a)
			var dz: float = cos(a)
			var wz: float = 0.96 + 0.07 * clampf(dz, 0.0, 1.0) * (0.4 + 0.6 * sy)
			var zf: float = 1.0 - 0.10 * t * clampf(-dz, 0.0, 1.0)
			row.append(c + Vector3(dx * cy * wx, sy * 1.06, dz * cy * wz * zf) * r)
			crow.append(_rigid(col))
		pts.append(row)
		cols.append(crow)
	return _grid(pts, cols, true)


## A calm face on an oval head. Options: skin (Color), kind (skin/fur), jaw, eyes ("open", "down", "glow" or
## "none"), iris, brow, lip (Colors), hair (Color; omit for none), tilak (Color), moustache (bool), nose (scale),
## lite (bool: a simplified face for small or distant heads).
static func _head(k: Dictionary, g: String, c: Vector3, r: float, o: Dictionary) -> void:
	var skin: Color = o.get("skin", HUMAN_SKIN) as Color
	var kind: StringName = o.get("kind", &"skin") as StringName
	var jaw: float = o.get("jaw", 0.66) as float
	var eyes: String = o.get("eyes", "open") as String
	var dark: Color = o.get("brow", HAIR_BLACK) as Color
	var lip: Color = o.get("lip", LIP_ROSE) as Color
	var nose: float = o.get("nose", 1.0) as float
	var lite: bool = o.get("lite", false) as bool
	var seg: int = 4 if lite else 5
	var sub: int = 1 if lite else 2
	if lite:
		_put(k, g, kind, _skull(c, r, skin, jaw, 8, 10))
	else:
		_put(k, g, kind, _skull(c, r, skin, jaw))
	# Nose: a soft bridge that swells to a small rounded tip.
	_put(k, g, kind, _tube(PackedVector3Array([_fp(c, r, jaw, 0.0, 0.3, -0.02), _fp(c, r, jaw, 0.0, 0.04, 0.05 * nose), _fp(c, r, jaw, 0.0, -0.16, 0.1 * nose)]),
		PackedFloat32Array([0.05 * r, 0.062 * r, 0.085 * r]), seg + 1, _rigid(skin), sub))
	_ball(k, g, kind, _fp(c, r, jaw, 0.0, -0.2, 0.05 * nose), Vector3(0.12, 0.075, 0.09) * r, skin, Basis.IDENTITY, 0)
	if not lite:
		# Lips: one soft curve, corners lifted a little. Chin and cheeks: gentle fullness.
		_put(k, g, &"lacquer_local", _tube(PackedVector3Array([
			_fp(c, r, jaw, -0.18, -0.468, 0.0), _fp(c, r, jaw, -0.09, -0.48, 0.02), _fp(c, r, jaw, 0.0, -0.48, 0.03),
			_fp(c, r, jaw, 0.09, -0.48, 0.02), _fp(c, r, jaw, 0.18, -0.468, 0.0)]),
			PackedFloat32Array([0.012 * r, 0.04 * r, 0.048 * r, 0.04 * r, 0.012 * r]), 5, _rigid(lip), 2))
		_ball(k, g, kind, _fp(c, r, jaw, 0.0, -0.78, -0.1), Vector3(0.2, 0.14, 0.14) * r, skin, Basis.IDENTITY, 0)
	for sx: float in [-1.0, 1.0]:
		if not lite:
			_ball(k, g, kind, c + Vector3(sx * 0.82, -0.04, 0.08) * r, Vector3(0.07, 0.2, 0.13) * r, skin, Basis.IDENTITY, 0)
			_ball(k, g, kind, _fp(c, r, jaw, sx * 0.38, -0.2, -0.12), Vector3(0.22, 0.2, 0.14) * r, skin)
		# Brows: long, even arcs.
		_put(k, g, &"fur", _tube(PackedVector3Array([_fp(c, r, jaw, sx * 0.13, 0.38, 0.01), _fp(c, r, jaw, sx * 0.36, 0.41, 0.02), _fp(c, r, jaw, sx * 0.6, 0.27, 0.01)]),
			PackedFloat32Array([0.028 * r, 0.036 * r, 0.012 * r]), seg, _rigid(dark), sub))
		if eyes == "open":
			_ball(k, g, &"lacquer_local", _fp(c, r, jaw, sx * 0.33, 0.115, -0.035), Vector3(0.15, 0.068, 0.05) * r, BROW_WHITE)
			_ball(k, g, &"lacquer_local", _fp(c, r, jaw, sx * 0.33, 0.115, -0.012), Vector3(0.066, 0.066, 0.04) * r, o.get("iris", HAIR_BLACK) as Color)
			_put(k, g, &"fur", _tube(PackedVector3Array([_fp(c, r, jaw, sx * 0.15, 0.13, 0.012), _fp(c, r, jaw, sx * 0.33, 0.178, 0.03), _fp(c, r, jaw, sx * 0.5, 0.12, 0.02), _fp(c, r, jaw, sx * 0.57, 0.07, 0.005)]),
				PackedFloat32Array([0.012 * r, 0.026 * r, 0.024 * r, 0.008 * r]), seg, _rigid(dark), sub))
		elif eyes == "glow":
			_ball(k, g, &"gold", _fp(c, r, jaw, sx * 0.33, 0.13, -0.02), Vector3(0.14, 0.06, 0.045) * r, Palette.FIRE_CORE, Basis.IDENTITY, 0 if lite else 1)
			if not lite:
				_put(k, g, &"fur", _tube(PackedVector3Array([_fp(c, r, jaw, sx * 0.14, 0.17, 0.02), _fp(c, r, jaw, sx * 0.33, 0.21, 0.035), _fp(c, r, jaw, sx * 0.56, 0.13, 0.02)]),
					PackedFloat32Array([0.02 * r, 0.035 * r, 0.012 * r]), seg, _rigid(dark), sub))
		if o.get("moustache", false) as bool:
			_put(k, g, &"fur", _tube(PackedVector3Array([_fp(c, r, jaw, sx * 0.04, -0.33, 0.05), _fp(c, r, jaw, sx * 0.26, -0.37, 0.07), _fp(c, r, jaw, sx * 0.5, -0.3, 0.07), _fp(c, r, jaw, sx * 0.62, -0.16, 0.08)]),
				PackedFloat32Array([0.06 * r, 0.065 * r, 0.04 * r, 0.008 * r]), seg + 1, _rigid(dark), sub))
	if o.has("hair"):
		_ball(k, g, &"fur", c + Vector3(0.0, 0.1, 0.14) * r, Vector3(0.93, 1.06, 1.0) * r, o["hair"] as Color, Basis.IDENTITY, 1 if lite else 2)
	if o.has("tilak"):
		_put(k, g, &"lacquer_local", _tube(PackedVector3Array([_fp(c, r, jaw, 0.0, 0.36, 0.0), _fp(c, r, jaw, 0.0, 0.5, 0.012), _fp(c, r, jaw, 0.0, 0.62, 0.0)]),
			PackedFloat32Array([0.022 * r, 0.036 * r, 0.02 * r]), seg, _rigid(o["tilak"] as Color), sub))


## A tall tiered crown (kirita mukuta) whose band of radius `r` sits at `base`. With `split`, the base goes to
## group g, the kalasha finial to g + "_peak", the crest and wings to g + "_point" and the gems to g + "_gems".
static func _kirita(k: Dictionary, g: String, base: Vector3, r: float, tall: float, split: bool = false, lite: bool = false) -> void:
	var g_peak: String = g + "_peak" if split else g
	var g_point: String = g + "_point" if split else g
	var g_gems: String = g + "_gems" if split else g
	var shape: Array[Vector2] = [
		Vector2(0.98, 0.0), Vector2(1.08, 0.03), Vector2(1.08, 0.09), Vector2(0.98, 0.12), Vector2(0.95, 0.17),
		Vector2(1.04, 0.28), Vector2(0.94, 0.4), Vector2(0.84, 0.42), Vector2(0.9, 0.5), Vector2(0.74, 0.61),
		Vector2(0.64, 0.63), Vector2(0.68, 0.7), Vector2(0.48, 0.78), Vector2(0.4, 0.8),
	]
	var prof: PackedVector2Array = PackedVector2Array()
	for s: Vector2 in shape:
		prof.append(Vector2(s.x * r, s.y * tall))
	var at: Transform3D = Transform3D(Basis.IDENTITY, base)
	_put(k, g, &"gold", _lathe(prof, 9 if lite else 16, GOLD_DARK.lerp(Palette.GOLD, 0.6), Palette.GOLD), at)
	var top: PackedVector2Array = PackedVector2Array([
		Vector2(0.4 * r, 0.79 * tall), Vector2(0.2 * r, 0.84 * tall), Vector2(0.12 * r, 0.87 * tall),
		Vector2(0.2 * r, 0.91 * tall), Vector2(0.1 * r, 0.96 * tall), Vector2(0.03 * r, 1.0 * tall),
	])
	_put(k, g_peak, &"gold", _lathe(top, 6 if lite else 10, Palette.GOLD, Palette.GOLD.lerp(Palette.FIRE_CORE, 0.5)), at)
	# Crest leaf at the front and two wings by the ears.
	_ball(k, g_point, &"gold", base + Vector3(0.0, 0.3 * tall, -r * 1.02), Vector3(0.36 * r, 0.24 * tall, 0.08 * r), Palette.GOLD, Basis.IDENTITY, 0 if lite else 1)
	_orb(k, g_gems, &"lacquer_local", base + Vector3(0.0, 0.3 * tall, -r * 1.1), 0.11 * r, Palette.SINDOOR)
	if lite:
		return
	for sx: float in [-1.0, 1.0]:
		_ball(k, g_point, &"gold", base + Vector3(sx * r * 1.04, 0.16 * tall, 0.0), Vector3(0.09 * r, 0.2 * tall, 0.3 * r), Palette.GOLD, Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.25)))
	for i: int in 8:
		var a: float = TAU * (float(i) + 0.5) / 8.0
		_orb(k, g_gems, &"lacquer_local", base + Vector3(sin(a) * r * 1.07, 0.06 * tall, cos(a) * r * 1.07), 0.085 * r, Palette.SINDOOR if i % 2 == 0 else EMERALD)


# ================================================================ bodies

static func _arm_points(h: float, w: float, sx: float, pose: String) -> PackedVector3Array:
	var s: Vector3 = Vector3(sx * 0.15 * w, 0.75, 0.0) * h
	var e: Vector3 = Vector3(sx * 0.186 * w, 0.6, 0.014) * h
	var wr: Vector3 = Vector3(sx * 0.184 * w, 0.465, -0.035) * h
	match pose:
		"bless":
			e = Vector3(sx * 0.205 * w, 0.61, -0.02) * h
			wr = Vector3(sx * 0.175 * w, 0.7, -0.15) * h
		"hold":
			e = Vector3(sx * 0.21 * w, 0.61, 0.0) * h
			wr = Vector3(sx * 0.225 * w, 0.56, -0.15) * h
		"anjali":
			e = Vector3(sx * 0.19 * w, 0.6, -0.03) * h
			wr = Vector3(sx * 0.022, 0.655, -0.16 * (0.6 + 0.4 * w)) * h
		"clasp":
			e = Vector3(sx * 0.205 * w, 0.6, 0.0) * h
			wr = Vector3(sx * 0.03, 0.5, -0.125 * w) * h
	return PackedVector3Array([s, e, wr])


## Standing humanoid, feet on y = 0, head centre at 0.868 * H. Groups: legs, garment (stay still), torso, arms,
## ornaments (go under Upper). Options (all optional): H, w, skin, kind (&"skin" or &"fur"), cloth, cloth_lo,
## lower ("dhoti" or "robe"), hem (fraction of H), top (Color), top_kind, trim, belly, armlets, anklets,
## sleeve (Color), arm_l / arm_r ("hang", "bless", "hold", "anjali", "clasp").
static func _body(k: Dictionary, o: Dictionary) -> void:
	var h: float = o.get("H", 1.8) as float
	var w: float = o.get("w", 1.0) as float
	var skin: Color = o.get("skin", HUMAN_SKIN) as Color
	var kind: StringName = o.get("kind", &"skin") as StringName
	var cloth: Color = o.get("cloth", Palette.STONE) as Color
	var cloth_lo: Color = o.get("cloth_lo", cloth.lerp(Palette.NIGHT_INDIGO, 0.32)) as Color
	var top: Color = o.get("top", skin) as Color
	var top_kind: StringName = o.get("top_kind", kind) as StringName
	var trim: Color = o.get("trim", Palette.GOLD) as Color
	var belly: float = o.get("belly", 0.0) as float
	var robe: bool = (o.get("lower", "dhoti") as String) == "robe"
	var hem: float = o.get("hem", 0.05 if robe else 0.2) as float
	var skin_c: Color = _rigid(skin)
	# Legs and feet.
	for sx: float in [-1.0, 1.0]:
		var hx: float = sx * 0.06 * h * w
		_put(k, "legs", kind, _tube(PackedVector3Array([Vector3(hx, 0.52 * h, 0.0), Vector3(hx * 1.1, 0.29 * h, -0.012 * h), Vector3(hx, 0.17 * h, 0.012 * h), Vector3(hx * 0.95, 0.045 * h, 0.012 * h)]),
			PackedFloat32Array([0.074 * h * w, 0.052 * h * w, 0.05 * h * w, 0.031 * h * w]), 9, skin_c, 2))
		_ball(k, "legs", kind, Vector3(hx, 0.02 * h, -0.026 * h), Vector3(0.033 * w, 0.021, 0.064) * h, skin)
		if o.get("anklets", false) as bool:
			_ball(k, "legs", &"gold", Vector3(hx * 0.95, 0.06 * h, 0.01 * h), Vector3(0.04 * w, 0.012, 0.04 * w) * h, Palette.GOLD)
	# Lower garment: a wrapped cloth with pleats that deepen toward the hem, and a fan of pleats in front.
	var flare: float = 1.12 if robe else 0.98
	var prof: PackedVector2Array = _cr2(PackedVector2Array([
		Vector2(0.106 * w + belly * 0.6, 0.585) * h, Vector2(0.128 * w + belly * 0.5, 0.52) * h, Vector2(0.134 * w, 0.44) * h,
		Vector2(0.128 * w, (0.44 + hem) * 0.5) * h, Vector2(0.13 * w * flare, hem + 0.015) * h, Vector2(0.124 * w * flare, hem) * h]), 2)
	_put(k, "garment", &"cloth", _lathe(prof, 20, cloth_lo, cloth, Vector2(1.0, 0.78 + belly * 2.0), 9, 0.06, 0.3))
	var fan: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.026, 0.553) * h, Vector2(0.042, 0.42) * h, Vector2(0.062, hem + 0.03) * h, Vector2(0.066, hem - 0.012) * h]), 3)
	_put(k, "garment", &"cloth", _lathe(fan, 12, cloth_lo, cloth, Vector2(1.0, 0.42), 5, 0.24, 0.4),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -(0.098 * w + belly * 1.2) * h)))
	# Belt with a clasp.
	var belt: PackedVector2Array = PackedVector2Array([Vector2(0.108 * w + belly * 0.6, 0.556) * h, Vector2(0.119 * w + belly * 0.6, 0.561) * h, Vector2(0.122 * w + belly * 0.6, 0.575) * h, Vector2(0.117 * w + belly * 0.6, 0.589) * h, Vector2(0.106 * w + belly * 0.6, 0.594) * h])
	_put(k, "garment", &"gold", _lathe(belt, 16, GOLD_DARK.lerp(Palette.BARK, 0.35), GOLD_DARK.lerp(Palette.BARK, 0.15), Vector2(1.0, 0.78 + belly * 2.0)))
	_ball(k, "garment", &"gold", Vector3(0.0, 0.575 * h, -(0.096 * w + belly * 1.7) * h), Vector3(0.026, 0.022, 0.01) * h, trim)
	# Torso and neck.
	var body: PackedVector2Array = _cr2(PackedVector2Array([
		Vector2(0.106 * w + belly * 0.6, 0.55) * h, Vector2(0.104 * w + belly, 0.6) * h, Vector2(0.124 * w + belly * 0.7, 0.66) * h,
		Vector2(0.142 * w, 0.712) * h, Vector2(0.136 * w, 0.752) * h, Vector2(0.09 * w, 0.784) * h, Vector2(0.05, 0.798) * h]), 2)
	_put(k, "torso", top_kind, _lathe(body, 20, _rigid(top.lerp(Palette.NIGHT_INDIGO, 0.12)), _rigid(top), Vector2(1.0, 0.62 + belly * 2.4)))
	_put(k, "torso", kind, _tube(PackedVector3Array([Vector3(0.0, 0.77 * h, 0.0), Vector3(0.0, 0.84 * h, -0.004 * h)]), PackedFloat32Array([0.045 * h * sqrt(w), 0.038 * h * sqrt(w)]), 10, skin_c, 1))
	# Arms.
	var th: float = 0.043 * h * sqrt(w)
	for sx: float in [-1.0, 1.0]:
		var pose: String = o.get("arm_r" if sx > 0.0 else "arm_l", "hang") as String
		var pts: PackedVector3Array = _arm_points(h, w, sx, pose)
		var s: Vector3 = pts[0]
		var e: Vector3 = pts[1]
		var wr: Vector3 = pts[2]
		_ball(k, "arms", top_kind, s, Vector3(th * 1.14, th * 1.02, th * 1.12), top, Basis.IDENTITY, 2)
		_put(k, "arms", kind, _tube(PackedVector3Array([s, s.lerp(e, 0.45), e, e.lerp(wr, 0.45), wr]), PackedFloat32Array([th, th * 1.04, th * 0.84, th * 0.82, th * 0.58]), 9, skin_c, 2))
		if o.has("sleeve"):
			var sleeve: Color = o["sleeve"] as Color
			_put(k, "arms", &"cloth", _tube(PackedVector3Array([s, s.lerp(e, 0.4), s.lerp(e, 0.8)]), PackedFloat32Array([th * 1.1, th * 1.12, th * 1.06]), 10, _rigid(sleeve), 2))
		var dir: Vector3 = (wr - e).normalized()
		if pose == "anjali" or pose == "bless":
			dir = Vector3(-sx * 0.12, 1.0, -0.12).normalized() if pose == "anjali" else Vector3(0.0, 1.0, -0.1).normalized()
		var hand_basis: Basis = _basis_y(dir)
		var flat: Vector3 = Vector3(th * 0.36, th * 1.2, th * 0.66) if pose == "anjali" else Vector3(th * 0.66, th * 1.2, th * 0.36)
		_ball(k, "arms", kind, wr + dir * th * 1.0, flat, skin, hand_basis)
		if o.get("armlets", false) as bool:
			var upper_dir: Basis = _basis_y(e - s)
			_ball(k, "ornaments", &"gold", s.lerp(e, 0.5), Vector3(th * 1.2, th * 0.36, th * 1.2), GOLD_DARK.lerp(trim, 0.5), upper_dir)
			_orb(k, "ornaments", &"lacquer_local", s.lerp(e, 0.5) + Vector3(sx * th * 1.22, 0.0, 0.0), th * 0.3, Palette.SINDOOR)
			_ball(k, "ornaments", &"gold", e.lerp(wr, 0.88), Vector3(th * 0.8, th * 0.28, th * 0.8), GOLD_DARK.lerp(trim, 0.5), _basis_y(wr - e))


## A necklace resting on the collarbones, dipping `drop` in front, with a pendant.
static func _necklace(k: Dictionary, h: float, w: float, drop: float, col: Color, gem: Color) -> void:
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in 17:
		var a: float = TAU * float(i) / 16.0
		var front: float = 0.5 - 0.5 * cos(a)
		path.append(Vector3(sin(a) * (0.062 + 0.5 * drop) * w, 0.792 - drop * front, 0.012 - (0.066 + 0.25 * drop) * front * 1.3 + 0.03 * (1.0 - front)) * h)
	_put(k, "ornaments", &"gold", _tube(path, PackedFloat32Array([0.0085 * h]), 5, _rigid(col), 1))
	_orb(k, "ornaments", &"lacquer_local", path[8] + Vector3(0.0, -0.012 * h, -0.004 * h), 0.015 * h, gem)


## A long cloth worn over the left shoulder and across the chest to the right hip, closed around the back.
static func _sash(k: Dictionary, h: float, w: float, col: Color, col_lo: Color) -> void:
	var path: PackedVector3Array = PackedVector3Array([
		Vector3(-0.112 * w, 0.776, 0.01) * h, Vector3(-0.07 * w, 0.728, -0.092) * h, Vector3(0.02 * w, 0.652, -0.092) * h,
		Vector3(0.108 * w, 0.585, -0.05) * h, Vector3(0.118 * w, 0.585, 0.04) * h, Vector3(0.02 * w, 0.66, 0.092) * h,
		Vector3(-0.08 * w, 0.74, 0.085) * h, Vector3(-0.112 * w, 0.776, 0.01) * h])
	_put(k, "torso", &"cloth", _tube(path, PackedFloat32Array([0.013 * h]), 8, _rigid(col), 3, PackedFloat32Array([3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2]), Vector3(1.0, 1.0, 0.0), _rigid(col_lo), 0))


## A cape hanging from the shoulders down the back to y = `bottom` * H; it sways toward its hem.
static func _cape(k: Dictionary, g: String, h: float, w: float, col: Color, col_lo: Color, bottom: float, wind: float = 0.4) -> void:
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var rows: int = 12
	var n: int = 15
	for i: int in rows + 1:
		var t: float = float(i) / float(rows)
		var y: float = lerpf(0.78, bottom, t) * h
		var rad: float = (0.15 + 0.07 * t) * h * w
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		for j: int in n:
			var u: float = float(j) / float(n - 1) * 2.0 - 1.0
			var a: float = u * 1.35
			var fold: float = sin(u * 9.0 + t * 2.0) * 0.012 * h * t
			row.append(Vector3(sin(a) * rad, y, 0.035 * h + cos(a) * (rad * 0.62 + 0.04 * h * t) + fold))
			var c: Color = col.lerp(col_lo, t * 0.8 + 0.2 * (0.5 - 0.5 * sin(u * 9.0 + t * 2.0)) * t)
			crow.append(_rigid(c, wind * t * t))
		pts.append(row)
		cols.append(crow)
	_put(k, g, &"cloth", _grid(pts, cols, false, 0.012 * h))


## Emits the standard groups of a standing figure and adds the breathing loop. Returns the Upper pivot.
static func _finish(root: Node3D, k: Dictionary, h: float, stoop: float = 0.0, period: float = 3.6) -> Node3D:
	_emit(root, k, "legs", "Legs")
	_emit(root, k, "garment", "Garment")
	_emit(root, k, "tail", "Tail")
	_emit(root, k, "ground", "Planted")
	var pivot: Vector3 = Vector3(0.0, 0.54 * h, 0.0)
	var upper: Node3D = _upper(root, pivot, stoop)
	_emit(upper, k, "torso", "Torso", -pivot)
	_emit(upper, k, "arms", "Arms", -pivot)
	_emit(upper, k, "head", "Head", -pivot)
	_emit(upper, k, "ornaments", "Ornaments", -pivot)
	_emit(upper, k, "drape", "Drape", -pivot)
	_emit(upper, k, "prop", "Prop", -pivot)
	_idle(root, ["Upper"], Vector3(0.012, 0.005, 0.022), period)
	return upper


static func _staff(k: Dictionary, g: String, pos: Vector3, length: float, wood: Color, knob: Color, knob_kind: StringName) -> void:
	_put(k, g, &"wood", _tube(PackedVector3Array([pos, pos + Vector3(0.004, length * 0.5, 0.0), pos + Vector3(0.0, length, 0.0)]), PackedFloat32Array([0.022, 0.026, 0.021]), 8, _rigid(wood), 3))
	_orb(k, g, knob_kind, pos + Vector3(0.0, length + 0.03, 0.0), 0.045, knob.lerp(GOLD_DARK, 0.6) if knob_kind == &"gold" else knob, 1)
	_ball(k, g, knob_kind, pos + Vector3(0.0, length - 0.02, 0.0), Vector3(0.034, 0.014, 0.034), knob)


## An upright recurved bow centred on `pos`, its belly toward -Z and the string on the archer's side.
static func _bow(k: Dictionary, g: String, pos: Vector3, size: float, wood: Color, tips: Color) -> void:
	var half: float = size * 0.5
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i: int in 9:
		var u: float = float(i) / 8.0 * 2.0 - 1.0
		var z: float = -0.2 * size * (1.0 - u * u) - 0.035 * size * pow(absf(u), 6.0) + 0.11 * size
		path.append(pos + Vector3(0.0, u * half, z))
		radii.append(size * (0.017 - 0.009 * absf(u)))
	_put(k, g, &"wood", _tube(path, radii, 7, _rigid(wood), 2))
	for sgn: float in [-1.0, 1.0]:
		var tip: Vector3 = pos + Vector3(0.0, sgn * half, 0.075 * size)
		_ball(k, g, &"gold", tip + Vector3(0.0, sgn * 0.012 * size, -0.006 * size), Vector3(0.014, 0.03, 0.014) * size, tips, Basis.IDENTITY, 0)
		_ball(k, g, &"gold", pos + Vector3(0.0, sgn * 0.085 * size, -0.088 * size), Vector3(0.022, 0.012, 0.022) * size, tips, Basis.IDENTITY, 0)
		_ball(k, g, &"gold", pos + Vector3(0.0, sgn * 0.3 * size, -0.074 * size), Vector3(0.017, 0.01, 0.017) * size, tips, Basis.IDENTITY, 0)
	_put(k, g, &"cloth", _tube(PackedVector3Array([pos + Vector3(0.0, -half, 0.075 * size), pos + Vector3(0.0, half, 0.075 * size)]), PackedFloat32Array([0.002 * size]), 5, _rigid(Palette.STONE), 1))


## A quiver slung across the back, with fletched arrows.
static func _quiver(k: Dictionary, g: String, h: float, body: Color, fletch: Color) -> void:
	var lo: Vector3 = Vector3(-0.07, 0.55, 0.125) * h
	var hi: Vector3 = Vector3(0.1, 0.84, 0.115) * h
	var dir: Vector3 = (hi - lo).normalized()
	_put(k, g, &"wood", _tube(PackedVector3Array([lo, lo.lerp(hi, 0.5), hi]), PackedFloat32Array([0.03 * h, 0.038 * h, 0.04 * h]), 8, _rigid(body), 2))
	var around: Basis = _basis_y(dir)
	for t: float in [0.12, 0.62, 0.98]:
		_ball(k, g, &"gold", lo.lerp(hi, t), Vector3(0.043, 0.012, 0.043) * h, Palette.GOLD, around, 0)
	for i: int in 4:
		var off: Vector3 = around * Vector3(0.016 * h * cos(float(i) * 1.7), 0.0, 0.016 * h * sin(float(i) * 1.7))
		var a: Vector3 = hi + off
		_put(k, g, &"wood", _tube(PackedVector3Array([a, a + dir * 0.07 * h]), PackedFloat32Array([0.004 * h]), 4, _rigid(Palette.BARK), 1))
		_ball(k, g, &"cloth", a + dir * (0.06 + 0.008 * float(i)) * h, Vector3(0.011, 0.028, 0.004) * h, fletch, around * Basis.from_euler(Vector3(0.0, float(i) * 0.9, 0.0)), 0)


# ================================================================ vanaras and Jambavan

## A vanara's head: a calm, noble face with a short pale muzzle, framed by a mane of fur swept back from the brow.
static func _vanara_head(k: Dictionary, c: Vector3, r: float, fur: Color, face: Color) -> void:
	var jaw: float = 0.82
	_head(k, "head", c, r, {"skin": face, "jaw": jaw, "eyes": "open", "iris": BEAR_FUR, "brow": fur.lerp(BEAR_FUR, 0.6), "lip": face.lerp(BEAR_FUR, 0.55), "nose": 0.45})
	# Muzzle: a soft swelling around the mouth, lighter than the face.
	_ball(k, "head", &"skin", _fp(c, r, jaw, 0.0, -0.4, -0.2), Vector3(0.46, 0.32, 0.3) * r, face.lerp(BROW_WHITE, 0.3), Basis.IDENTITY, 1)
	_put(k, "head", &"lacquer_local", _tube(PackedVector3Array([_fp(c, r, jaw, -0.22, -0.495, 0.085), _fp(c, r, jaw, 0.0, -0.515, 0.125), _fp(c, r, jaw, 0.22, -0.495, 0.085)]), PackedFloat32Array([0.01 * r, 0.026 * r, 0.01 * r]), 5, _rigid(face.lerp(BEAR_FUR, 0.7)), 3))
	_ball(k, "head", &"skin", _fp(c, r, jaw, 0.0, -0.24, 0.1), Vector3(0.12, 0.06, 0.06) * r, face.lerp(BEAR_FUR, 0.6))
	# Mane: over the crown and down the back of the head, with a brow ridge and ruffs along the jaw.
	_ball(k, "head", &"fur", c + Vector3(0.0, 0.12, 0.2) * r, Vector3(1.0, 1.08, 1.04) * r, fur, Basis.IDENTITY, 1)
	_ball(k, "head", &"fur", c + Vector3(0.0, 0.96, 0.0) * r, Vector3(0.52, 0.3, 0.78) * r, fur.lerp(Palette.NIGHT_INDIGO, 0.18), Basis.from_euler(Vector3(0.3, 0.0, 0.0)))
	_ball(k, "head", &"fur", _fp(c, r, jaw, 0.0, 0.66, -0.04), Vector3(0.62, 0.14, 0.22) * r, fur)
	for sx: float in [-1.0, 1.0]:
		_ball(k, "head", &"fur", c + Vector3(sx * 0.8, -0.38, 0.12) * r, Vector3(0.3, 0.56, 0.6) * r, fur.lerp(BROW_WHITE, 0.2), Basis.from_euler(Vector3(0.3, 0.0, sx * 0.2)))
		_ball(k, "head", &"skin", c + Vector3(sx * 0.95, 0.12, 0.1) * r, Vector3(0.1, 0.24, 0.18) * r, face.lerp(fur, 0.3))


static func _tail(k: Dictionary, h: float, fur: Color) -> void:
	var path: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.5, 0.07) * h, Vector3(0.0, 0.4, 0.22) * h, Vector3(0.0, 0.44, 0.4) * h, Vector3(0.0, 0.64, 0.5) * h,
		Vector3(0.0, 0.84, 0.44) * h, Vector3(0.0, 0.9, 0.31) * h, Vector3(0.0, 0.82, 0.25) * h])
	_put(k, "tail", &"fur", _tube(path, PackedFloat32Array([0.032 * h, 0.03 * h, 0.028 * h, 0.026 * h, 0.024 * h, 0.022 * h, 0.014 * h]), 9, _rigid(fur), 4, PackedFloat32Array(), Vector3.RIGHT, _rigid(fur.lerp(Palette.NIGHT_INDIGO, 0.25)), 0))
	_orb(k, "tail", &"fur", path[6], 0.028 * h, fur.lerp(BROW_WHITE, 0.2), 1)


static func _vanara(root: Node3D, seed_value: int) -> void:
	var furs: Array[Color] = [Palette.HANUMAN_FUR, Palette.BARK, VANARA_GREY, Palette.STONE]
	var cloths: Array[Color] = [Palette.GROVE_GREEN, Palette.SINDOOR, Palette.LEAF_DARK, Palette.DEEP_OCEAN]
	var n: int = absi(seed_value)
	var fur: Color = furs[n % furs.size()]
	var cloth: Color = cloths[(n / furs.size() + n) % cloths.size()]
	var h: float = 1.55 + 0.04 * float(n % 3)
	var k: Dictionary = {}
	_body(k, {"H": h, "w": 1.04, "skin": fur, "kind": &"fur", "cloth": cloth, "trim": Palette.STONE.lerp(Palette.GOLD, 0.5), "hem": 0.3})
	_vanara_head(k, Vector3(0.0, 0.868 * h, -0.012 * h), 0.082 * h, fur, Palette.STONE.lerp(fur, 0.25))
	_tail(k, h, fur)
	_sash(k, h, 1.04, cloth, cloth.lerp(Palette.NIGHT_INDIGO, 0.3))
	_necklace(k, h, 1.04, 0.03, Palette.STONE, cloth)
	_finish(root, k, h, 0.07, 3.2 + 0.15 * float(n % 4))


static func _angada(root: Node3D) -> void:
	var h: float = 1.75
	var fur: Color = Palette.HANUMAN_FUR
	var k: Dictionary = {}
	_body(k, {"H": h, "w": 1.08, "skin": fur, "kind": &"fur", "cloth": Palette.SINDOOR, "trim": Palette.GOLD, "armlets": true, "anklets": true, "hem": 0.24})
	var c: Vector3 = Vector3(0.0, 0.868 * h, -0.008 * h)
	_vanara_head(k, c, 0.082 * h, fur, Palette.STONE.lerp(fur, 0.2))
	# A prince's coronet, earrings, two necklaces and a silk sash.
	_kirita(k, "ornaments", c + Vector3(0.0, 0.058 * h, 0.006 * h), 0.062 * h, 0.15 * h)
	for sx: float in [-1.0, 1.0]:
		_orb(k, "ornaments", &"gold", c + Vector3(sx * 0.083 * h, -0.03 * h, 0.0), 0.016 * h, Palette.GOLD, 1)
	_necklace(k, h, 1.08, 0.03, Palette.GOLD, Palette.SINDOOR)
	_necklace(k, h, 1.08, 0.085, Palette.GOLD, EMERALD)
	_sash(k, h, 1.08, Palette.SAFFRON, Palette.SINDOOR)
	_tail(k, h, fur)
	_finish(root, k, h, 0.03, 3.4)


static func _jambavan(root: Node3D) -> void:
	var h: float = 1.85
	var w: float = 1.3
	var k: Dictionary = {}
	_body(k, {"H": h, "w": w, "skin": BEAR_FUR, "kind": &"fur", "cloth": Palette.BARK, "cloth_lo": BEAR_FUR, "trim": Palette.GOLD, "belly": 0.028, "arm_r": "hold", "hem": 0.22, "armlets": true})
	var r: float = 0.104 * h
	var c: Vector3 = Vector3(0.0, 0.872 * h, -0.03 * h)
	# Bear head: a broad skull, a long pale muzzle, small wise eyes under white brows, round ears.
	_ball(k, "head", &"fur", c, Vector3(1.05, 0.98, 1.02) * r, BEAR_FUR, Basis.IDENTITY, 2)
	_put(k, "head", &"fur", _tube(PackedVector3Array([c + Vector3(0.0, -0.1, -0.5) * r, c + Vector3(0.0, -0.2, -1.0) * r, c + Vector3(0.0, -0.26, -1.36) * r]), PackedFloat32Array([0.6 * r, 0.42 * r, 0.3 * r]), 12, _rigid(BEAR_MUZZLE), 3, PackedFloat32Array(), Vector3.RIGHT, _rigid(BEAR_MUZZLE.lerp(BROW_WHITE, 0.3)), 0))
	_ball(k, "head", &"lacquer_local", c + Vector3(0.0, -0.14, -1.6) * r, Vector3(0.17, 0.12, 0.1) * r, HAIR_BLACK)
	_put(k, "head", &"fur", _tube(PackedVector3Array([c + Vector3(-0.26, -0.46, -1.2) * r, c + Vector3(0.0, -0.52, -1.5) * r, c + Vector3(0.26, -0.46, -1.2) * r]), PackedFloat32Array([0.01 * r, 0.024 * r, 0.01 * r]), 5, _rigid(HAIR_BLACK), 3))
	for sx: float in [-1.0, 1.0]:
		_ball(k, "head", &"fur", c + Vector3(sx * 0.72, 0.78, 0.1) * r, Vector3(0.3, 0.3, 0.16) * r, BEAR_FUR)
		_ball(k, "head", &"fur", c + Vector3(sx * 0.72, 0.76, 0.04) * r, Vector3(0.17, 0.17, 0.1) * r, BEAR_MUZZLE)
		_ball(k, "head", &"lacquer_local", c + Vector3(sx * 0.36, 0.14, -0.9) * r, Vector3(0.075, 0.07, 0.05) * r, HAIR_BLACK)
		_orb(k, "head", &"lacquer_local", c + Vector3(sx * 0.345, 0.165, -0.945) * r, 0.02 * r, BROW_WHITE)
		_put(k, "head", &"fur", _tube(PackedVector3Array([c + Vector3(sx * 0.14, 0.3, -0.96) * r, c + Vector3(sx * 0.4, 0.38, -0.88) * r, c + Vector3(sx * 0.7, 0.2, -0.66) * r, c + Vector3(sx * 0.8, 0.0, -0.56) * r]),
			PackedFloat32Array([0.07 * r, 0.1 * r, 0.075 * r, 0.02 * r]), 7, _rigid(BROW_WHITE), 3))
		_ball(k, "head", &"fur", c + Vector3(sx * 0.74, -0.34, -0.3) * r, Vector3(0.42, 0.5, 0.5) * r, BEAR_FUR.lerp(ELDER_HAIR, 0.35))
	# White beard and a grizzled mane over the shoulders.
	var beard: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.02 * r, -1.75 * r), Vector2(0.2 * r, -1.4 * r), Vector2(0.36 * r, -0.95 * r), Vector2(0.3 * r, -0.55 * r)]), 3)
	_put(k, "head", &"fur", _lathe(beard, 12, _rigid(ELDER_HAIR), _rigid(BROW_WHITE), Vector2(1.0, 0.6), 6, 0.2), Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.0, -0.78 * r)))
	var mane: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.15 * w, 0.725) * h, Vector2(0.152 * w, 0.76) * h, Vector2(0.12 * w, 0.795) * h, Vector2(0.07, 0.83) * h]), 3)
	_put(k, "torso", &"fur", _lathe(mane, 20, _rigid(BEAR_FUR.lerp(ELDER_HAIR, 0.12)), _rigid(BEAR_FUR.lerp(ELDER_HAIR, 0.5)), Vector2(1.0, 0.78), 11, 0.12))
	# A king's circlet, a heavy necklace and his staff.
	var band: PackedVector2Array = PackedVector2Array([Vector2(0.84 * r, 0.56 * r), Vector2(0.9 * r, 0.6 * r), Vector2(0.86 * r, 0.74 * r), Vector2(0.74 * r, 0.8 * r)])
	_put(k, "ornaments", &"gold", _lathe(band, 16, GOLD_DARK, Palette.GOLD), Transform3D(Basis.IDENTITY, c))
	_ball(k, "ornaments", &"gold", c + Vector3(0.0, 0.84 * r, -0.74 * r), Vector3(0.2, 0.3, 0.08) * r, Palette.GOLD)
	_orb(k, "ornaments", &"lacquer_local", c + Vector3(0.0, 0.84 * r, -0.82 * r), 0.085 * r, EMERALD)
	_necklace(k, h, w, 0.1, Palette.GOLD, Palette.SINDOOR)
	var wrist: Vector3 = _arm_points(h, w, 1.0, "hold")[2]
	_staff(k, "prop", Vector3(wrist.x + 0.01, 0.0, wrist.z - 0.05 * h), 1.12 * h, Palette.BARK, Palette.GOLD, &"gold")
	_finish(root, k, h, 0.1, 4.4)


# ================================================================ Sita

static func _sita(root: Node3D) -> void:
	var k: Dictionary = {}
	var sari: Color = SARI_SOILED
	var hem: Color = SARI_HEM
	var border: Color = SARI_HEM.lerp(GOLD_DARK, 0.6)
	# Seated with her legs folded beneath her: the sari pools on the ground in soft pleats.
	var pool: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.47, 0.0), Vector2(0.455, 0.035), Vector2(0.39, 0.06), Vector2(0.3, 0.07)]), 3)
	_put(k, "lap", &"cloth", _lathe(pool, 24, border, hem, Vector2(1.0, 0.86), 13, 0.07, 0.25), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.03)))
	var lap: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.4, 0.03), Vector2(0.385, 0.1), Vector2(0.31, 0.19), Vector2(0.2, 0.26), Vector2(0.13, 0.3)]), 3)
	_put(k, "lap", &"cloth", _lathe(lap, 22, hem, sari, Vector2(1.0, 0.8), 11, 0.05, 0.0), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.01)))
	for sx: float in [-1.0, 1.0]:
		_ball(k, "lap", &"cloth", Vector3(sx * 0.23, 0.1, -0.12), Vector3(0.19, 0.1, 0.17), sari.lerp(hem, 0.2), Basis.from_euler(Vector3(0.0, sx * 0.5, 0.0)), 2)
	# Slender upright torso.
	var body: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.15, 0.22), Vector2(0.118, 0.36), Vector2(0.132, 0.46), Vector2(0.136, 0.53), Vector2(0.118, 0.585), Vector2(0.07, 0.618), Vector2(0.04, 0.63)]), 3)
	_put(k, "torso", &"cloth", _lathe(body, 20, _rigid(hem), _rigid(sari), Vector2(1.0, 0.66)))
	_put(k, "torso", &"skin", _tube(PackedVector3Array([Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.66, -0.006), Vector3(0.0, 0.71, -0.016)]), PackedFloat32Array([0.042, 0.033, 0.031]), 10, _rigid(HUMAN_SKIN), 2))
	# The sari's drape: pleats crossing from the right hip to the left shoulder, edged with a worn border.
	var cross: PackedVector3Array = PackedVector3Array([Vector3(0.13, 0.3, -0.06), Vector3(0.07, 0.41, -0.094), Vector3(-0.03, 0.51, -0.09), Vector3(-0.105, 0.59, -0.035), Vector3(-0.12, 0.61, 0.03)])
	var wide: PackedFloat32Array = PackedFloat32Array([3.6, 3.4, 3.0, 2.4, 2.0])
	_put(k, "torso", &"cloth", _tube(cross, PackedFloat32Array([0.017]), 8, _rigid(sari), 3, wide, Vector3(1.0, 1.0, 0.0), _rigid(sari.lerp(BROW_WHITE, 0.25)), 0))
	var edge: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in cross:
		edge.append(p + Vector3(0.05, 0.045, -0.012))
	_put(k, "torso", &"cloth", _tube(edge, PackedFloat32Array([0.007]), 6, _rigid(border), 3))
	# Arms folded down to the lap, hands resting one on the other.
	for sx: float in [-1.0, 1.0]:
		var s: Vector3 = Vector3(sx * 0.138, 0.578, 0.0)
		var e: Vector3 = Vector3(sx * 0.2, 0.41, -0.03)
		var wr: Vector3 = Vector3(sx * 0.055, 0.31, -0.215)
		_ball(k, "arms", &"cloth", s, Vector3(0.044, 0.042, 0.044), hem)
		_put(k, "arms", &"skin", _tube(PackedVector3Array([s, s.lerp(e, 0.5), e, e.lerp(wr, 0.5), wr]), PackedFloat32Array([0.036, 0.035, 0.03, 0.028, 0.021]), 10, _rigid(HUMAN_SKIN), 2))
		_put(k, "arms", &"cloth", _tube(PackedVector3Array([s, s.lerp(e, 0.4), s.lerp(e, 0.75)]), PackedFloat32Array([0.043, 0.042, 0.04]), 10, _rigid(hem), 2))
		_ball(k, "arms", &"skin", Vector3(sx * 0.018, 0.305 + 0.012 * sx, -0.235), Vector3(0.052, 0.017, 0.03), HUMAN_SKIN, Basis.from_euler(Vector3(0.0, sx * 0.35, 0.0)))
		_ball(k, "ornaments", &"gold", e.lerp(wr, 0.9), Vector3(0.026, 0.007, 0.026), GOLD_DARK, _basis_y(wr - e))
	# Head, a little bowed: a refined oval face, dark hair parted in the middle with sindoor in the parting.
	var r: float = 0.08
	var c: Vector3 = Vector3(0.0, 0.782, -0.022)
	var jaw: float = 0.6
	_head(k, "head", c, r, {"skin": HUMAN_SKIN, "jaw": jaw, "eyes": "none", "hair": HAIR_BLACK, "nose": 0.72})
	_put(k, "head", &"lacquer_local", _tube(PackedVector3Array([c + Vector3(0.0, 0.94, -0.56) * r, c + Vector3(0.0, 1.13, -0.2) * r, c + Vector3(0.0, 1.17, 0.1) * r]), PackedFloat32Array([0.016 * r, 0.02 * r, 0.012 * r]), 6, _rigid(Palette.SINDOOR), 2))
	# Braid resting over the back, under the pallu.
	_put(k, "head", &"fur", _tube(PackedVector3Array([c + Vector3(0.0, 0.3, 0.9) * r, Vector3(0.01, 0.6, 0.1), Vector3(0.02, 0.42, 0.135), Vector3(0.0, 0.26, 0.15)]), PackedFloat32Array([0.4 * r, 0.03, 0.026, 0.014]), 8, _rigid(HAIR_BLACK), 3))
	# The pallu: drawn over her head, framing the face, falling over both shoulders and down her back.
	_put(k, "pallu", &"cloth", _pallu(c, r, sari, hem, border))
	# Aura shell.
	var halo: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.05, 0.03), Vector2(0.62, 0.12), Vector2(0.76, 0.36), Vector2(0.66, 0.72), Vector2(0.46, 1.02), Vector2(0.22, 1.16), Vector2(0.03, 1.2)]), 3)
	_aura(root, "Sita_Aura", _lathe(halo, 16, _rigid(Palette.FIRE_CORE), _rigid(BROW_WHITE)), 0.5, 3.2)
	_emit(root, k, "lap", "Lap")
	var pivot: Vector3 = Vector3(0.0, 0.26, 0.0)
	var upper: Node3D = _upper(root, pivot)
	_emit(upper, k, "torso", "Torso", -pivot)
	_emit(upper, k, "arms", "Arms", -pivot)
	_emit(upper, k, "ornaments", "Ornaments", -pivot)
	_emit(upper, k, "pallu", "Sita_Pallu", -pivot)
	var head: MeshInstance3D = _emit(upper, k, "head", "Head", -pivot)
	# Lowered eyes: one soft dark lash line each. A small sindoor bindi between the brows.
	for sx: float in [-1.0, 1.0]:
		var lash: Dictionary = {}
		_put(lash, "e", &"fur", _tube(PackedVector3Array([_fp(c, r, jaw, sx * 0.17, 0.14, 0.012), _fp(c, r, jaw, sx * 0.33, 0.085, 0.022), _fp(c, r, jaw, sx * 0.49, 0.105, 0.012)]),
			PackedFloat32Array([0.012 * r, 0.03 * r, 0.012 * r]), 6, _rigid(HAIR_BLACK), 4))
		_emit(head, lash, "e", "Sita_Eye_L" if sx < 0.0 else "Sita_Eye_R")
	var bindi: Dictionary = {}
	_ball(bindi, "b", &"lacquer_local", _fp(c, r, jaw, 0.0, 0.4, 0.0), Vector3(0.05, 0.055, 0.02) * r, Palette.SINDOOR)
	_emit(head, bindi, "b", "Sita_Bindi")
	_idle(root, ["Upper"], Vector3(0.01, 0.006, 0.016), 4.2)


## The veil part of Sita's sari as a thin cloth shell (see _grid's `shell`).
static func _pallu(c: Vector3, r: float, sari: Color, hem: Color, border: Color) -> ArrayMesh:
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var top: float = c.y + 1.2 * r
	var rows: int = 22
	var n: int = 21
	var hr: float = 1.17 * r
	for i: int in rows + 1:
		var t: float = float(i) / float(rows)
		var y: float = lerpf(top - 0.002, 0.045, pow(t, 1.15))
		var rad: float = 0.0
		var open: float = 0.0
		var cz: float = c.z + 0.012
		var depth: float = 1.0
		if y > c.y - 0.5 * r:
			# Over the head: a dome a little larger than the hair.
			var dy: float = clampf((y - (c.y + 0.06 * r)) / (top - (c.y + 0.06 * r)), -1.0, 1.0)
			rad = hr * sqrt(maxf(1.0 - dy * dy, 0.0)) if dy > 0.0 else hr
			open = lerpf(0.86, 0.3, clampf(dy, 0.0, 1.0)) if dy > 0.0 else lerpf(0.86, 1.0, clampf(-dy * 3.0, 0.0, 1.0))
		else:
			# Falling from the head to the shoulders, then down the back to the ground.
			var d: float = clampf(((c.y - 0.5 * r) - y) / 0.14, 0.0, 1.0)
			var low: float = clampf((0.6 - y) / 0.55, 0.0, 1.0)
			rad = lerpf(hr, 0.19, smoothstep(0.0, 1.0, d)) + 0.14 * low
			open = lerpf(1.0, 1.08, d) + 0.5 * low
			cz = lerpf(c.z + 0.012, 0.03, d) + 0.05 * low
			depth = lerpf(1.0, 0.72, d)
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		var free: float = clampf((0.62 - y) / 0.57, 0.0, 1.0)
		for j: int in n:
			var u: float = float(j) / float(n - 1)
			var a: float = lerpf(open, TAU - open, u)
			var edge_w: float = 1.0 - clampf(minf(u, 1.0 - u) * 9.0, 0.0, 1.0)
			var fold: float = 1.0 + 0.06 * free * sin(a * 7.0 + y * 9.0)
			row.append(Vector3(sin(a) * rad * fold, y, cz - cos(a) * rad * fold * depth))
			var col: Color = sari.lerp(hem, 0.55 * free * (0.5 - 0.5 * sin(a * 7.0 + y * 9.0)) + 0.2 * free)
			col = col.lerp(border, smoothstep(0.55, 0.8, edge_w))
			if t > 0.94:
				col = col.lerp(border, 0.8)
			crow.append(_rigid(col, 0.32 * free * free + 0.08 * edge_w * free))
		pts.append(row)
		cols.append(crow)
	return _grid(pts, cols, false, 0.007)


# ================================================================ Lanka's women

static func _trijata(root: Node3D) -> void:
	var h: float = 1.6
	var k: Dictionary = {}
	var robe: Color = Palette.STONE
	_body(k, {"H": h, "w": 0.94, "skin": Palette.RAKSHASA_SKIN, "cloth": robe, "cloth_lo": robe.lerp(Palette.RAKSHASA_SKIN, 0.45), "lower": "robe", "top": robe, "top_kind": &"cloth", "sleeve": robe, "trim": GOLD_DARK, "arm_r": "hold"})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.076 * h
	_head(k, "head", c, r, {"skin": Palette.RAKSHASA_SKIN, "jaw": 0.7, "eyes": "open", "iris": Palette.NIGHT_INDIGO, "brow": ELDER_HAIR, "lip": Palette.RAKSHASA_SKIN.lerp(LIP_ROSE, 0.5), "hair": ELDER_HAIR})
	_ball(k, "head", &"fur", c + Vector3(0.0, 0.5, 0.95) * r, Vector3(0.48, 0.48, 0.44) * r, ELDER_HAIR, Basis.IDENTITY, 2)
	_ball(k, "ornaments", &"gold", c + Vector3(0.0, 0.5, 0.52) * r, Vector3(0.36, 0.36, 0.1) * r, GOLD_DARK)
	# A shawl over her shoulders.
	var shawl: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.15, 0.63) * h, Vector2(0.152, 0.69) * h, Vector2(0.142, 0.745) * h, Vector2(0.095, 0.787) * h, Vector2(0.055, 0.802) * h]), 3)
	_put(k, "torso", &"cloth", _lathe(shawl, 18, robe.lerp(Palette.RAKSHASA_SKIN, 0.4), robe, Vector2(1.0, 0.7), 9, 0.07, 0.25))
	_necklace(k, h, 0.94, 0.06, GOLD_DARK, Palette.MOON)
	var wrist: Vector3 = _arm_points(h, 0.94, 1.0, "hold")[2]
	_staff(k, "prop", Vector3(wrist.x + 0.01, 0.0, wrist.z - 0.05 * h), 1.0 * h, Palette.BARK, Palette.BARK, &"wood")
	_finish(root, k, h, 0.14, 4.6)


static func _rakshasi(root: Node3D) -> void:
	var h: float = 1.8
	var k: Dictionary = {}
	var cloth: Color = Palette.RAKSHASA_ARMOR
	_body(k, {"H": h, "w": 1.02, "skin": Palette.RAKSHASA_SKIN, "cloth": cloth, "lower": "robe", "hem": 0.08, "top": cloth, "top_kind": &"cloth", "trim": Palette.GOLD, "armlets": true, "arm_r": "hold"})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.076 * h
	_head(k, "head", c, r, {"skin": Palette.RAKSHASA_SKIN, "jaw": 0.78, "eyes": "glow", "brow": Palette.NIGHT_INDIGO, "lip": Palette.RAKSHASA_ARMOR, "hair": Palette.NIGHT_INDIGO})
	# A heavy mane of dark hair down the back, two pale horns.
	var mane: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.11, 0.6) * h, Vector2(0.13, 0.7) * h, Vector2(0.115, 0.82) * h, Vector2(0.09, 0.9) * h, Vector2(0.03, 0.945) * h]), 3)
	_put(k, "head", &"fur", _lathe(mane, 16, Palette.NIGHT_INDIGO, Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.3), Vector2(1.0, 0.7), 8, 0.12, 0.2), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.055 * h)))
	for sx: float in [-1.0, 1.0]:
		_put(k, "head", &"stone", _tube(PackedVector3Array([c + Vector3(sx * 0.5, 0.74, -0.2) * r, c + Vector3(sx * 0.78, 1.2, -0.24) * r, c + Vector3(sx * 0.7, 1.7, -0.1) * r]), PackedFloat32Array([0.17 * r, 0.12 * r, 0.015 * r]), 8, _rigid(Palette.STONE), 3, PackedFloat32Array(), Vector3.RIGHT, _rigid(BROW_WHITE), 0))
		_ball(k, "ornaments", &"gold", Vector3(sx * 0.158 * 1.02, 0.772, 0.0) * h, Vector3(0.05, 0.022, 0.05) * h, GOLD_DARK.lerp(Palette.BARK, 0.25))
		_orb(k, "ornaments", &"gold", c + Vector3(sx * 0.86, -0.34, 0.06) * r, 0.16 * r, Palette.GOLD, 1)
	_necklace(k, h, 1.02, 0.07, Palette.GOLD, Palette.FIRE_EDGE)
	# A guard's spear, planted beside her.
	var wrist: Vector3 = _arm_points(h, 1.02, 1.0, "hold")[2]
	var foot: Vector3 = Vector3(wrist.x + 0.01, 0.0, wrist.z - 0.05 * h)
	_put(k, "prop", &"wood", _tube(PackedVector3Array([foot, foot + Vector3(0.0, 1.06 * h, 0.0)]), PackedFloat32Array([0.022]), 8, _rigid(Palette.BARK), 1))
	_put(k, "prop", &"stone", _lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.06, 0.06), Vector2(0.03, 0.18), Vector2(0.004, 0.3)]), 8, _rigid(Palette.STONE), _rigid(BROW_WHITE), Vector2(1.0, 0.3)), Transform3D(Basis.IDENTITY, foot + Vector3(0.0, 1.06 * h, 0.0)))
	_ball(k, "prop", &"gold", foot + Vector3(0.0, 1.05 * h, 0.0), Vector3(0.036, 0.022, 0.036), Palette.GOLD)
	_finish(root, k, h, 0.03, 3.3)


# ================================================================ Lanka's court

## One of Ravana's faces: broad-jawed and calm, with a curled moustache, jewelled ears and a tiered gold crown.
static func _ravana_head(k: Dictionary, g: String, r: float, crown: float, lite: bool) -> void:
	var c: Vector3 = Vector3.ZERO
	_head(k, g, c, r, {"skin": Palette.RAKSHASA_SKIN, "jaw": 0.86, "eyes": "glow", "brow": HAIR_BLACK, "lip": Palette.RAKSHASA_ARMOR, "hair": HAIR_BLACK, "moustache": true, "tilak": Palette.FIRE_EDGE, "nose": 1.15, "lite": lite})
	if not lite:
		for sx: float in [-1.0, 1.0]:
			_orb(k, g, &"gold", c + Vector3(sx * 0.9, -0.34, 0.08) * r, 0.17 * r, Palette.GOLD, 1)
	_put(k, g, &"skin", _tube(PackedVector3Array([c + Vector3(0.0, -0.7, 0.1) * r, c + Vector3(0.0, -1.5, 0.2) * r]), PackedFloat32Array([0.55 * r, 0.6 * r]), 6 if lite else 10, _rigid(Palette.RAKSHASA_SKIN), 1))
	_kirita(k, g, c + Vector3(0.0, 0.66, 0.06) * r, 0.84 * r, crown * r, false, lite)


static func _ravana(root: Node3D) -> void:
	var h: float = 2.9
	var w: float = 1.45
	var k: Dictionary = {}
	var armor: Color = Palette.RAKSHASA_ARMOR
	_body(k, {"H": h, "w": w, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.35), "cloth_lo": Palette.NIGHT_INDIGO, "lower": "robe", "hem": 0.06, "top": armor, "top_kind": &"lacquer_local", "trim": Palette.GOLD, "armlets": true, "anklets": true})
	# Gold breastplate with a sun boss, broad pauldrons, a jewelled girdle with a hanging panel.
	_ball(k, "ornaments", &"gold", Vector3(0.0, 0.7, -0.062) * h, Vector3(0.12 * w, 0.08, 0.04) * h, GOLD_DARK, Basis.IDENTITY, 2)
	_orb(k, "ornaments", &"lacquer_local", Vector3(0.0, 0.705, -0.108) * h, 0.022 * h, Palette.SINDOOR, 1)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		_orb(k, "ornaments", &"gold", Vector3(sin(a) * 0.042, 0.705 + cos(a) * 0.042, -0.1) * h, 0.009 * h, Palette.FIRE_CORE)
	var collar: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.148 * w, 0.742) * h, Vector2(0.142 * w, 0.768) * h, Vector2(0.1 * w, 0.792) * h, Vector2(0.06 * w, 0.803) * h]), 3)
	_put(k, "ornaments", &"gold", _lathe(collar, 16, GOLD_DARK.lerp(Palette.BARK, 0.3), GOLD_DARK, Vector2(1.0, 0.56)))
	for sx: float in [-1.0, 1.0]:
		var sh: Vector3 = Vector3(sx * 0.17 * w, 0.765, 0.0) * h
		_ball(k, "ornaments", &"gold", sh, Vector3(0.072, 0.036, 0.066) * h, GOLD_DARK.lerp(Palette.BARK, 0.25), Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.35)))
		_ball(k, "ornaments", &"gold", sh + Vector3(sx * 0.03, -0.022, 0.0) * h, Vector3(0.078, 0.018, 0.07) * h, GOLD_DARK.lerp(Palette.BARK, 0.4), Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.5)))
		_put(k, "ornaments", &"gold", _lathe(PackedVector2Array([Vector2(0.02 * h, 0.0), Vector2(0.014 * h, 0.03 * h), Vector2(0.002 * h, 0.07 * h)]), 8, Palette.GOLD, Palette.FIRE_CORE), Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.6)), sh + Vector3(sx * 0.03, 0.03, 0.0) * h))
	var panel: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.05, 0.1) * h, Vector2(0.075, 0.16) * h, Vector2(0.06, 0.4) * h, Vector2(0.045, 0.56) * h]), 3)
	_put(k, "garment", &"cloth", _lathe(panel, 12, Palette.GOLD, armor, Vector2(1.0, 0.22), 0, 0.0, 0.3), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.128 * w * h)))
	var hem: PackedVector2Array = PackedVector2Array([Vector2(0.158 * w, 0.058) * h, Vector2(0.166 * w, 0.07) * h, Vector2(0.16 * w, 0.085) * h])
	_put(k, "garment", &"gold", _lathe(hem, 18, GOLD_DARK, Palette.GOLD, Vector2(1.0, 0.76)))
	_necklace(k, h, w, 0.05, Palette.GOLD, EMERALD)
	_cape(k, "drape", h, w, armor, Palette.NIGHT_INDIGO, 0.07, 0.4)
	# Sword of rank at the left hip, his hand resting near it.
	var hip: Vector3 = Vector3(-0.17 * w, 0.52, -0.02) * h
	var tip: Vector3 = Vector3(-0.2 * w, 0.14, 0.1) * h
	_put(k, "prop", &"lacquer_local", _tube(PackedVector3Array([hip, hip.lerp(tip, 0.6), tip]), PackedFloat32Array([0.016 * h, 0.014 * h, 0.006 * h]), 8, _rigid(Palette.NIGHT_INDIGO), 2, PackedFloat32Array([1.8, 1.8, 1.8]), Vector3.FORWARD))
	var grip: Vector3 = (hip - tip).normalized()
	_ball(k, "prop", &"gold", hip + grip * 0.004 * h, Vector3(0.04, 0.01, 0.022) * h, Palette.GOLD, _basis_y(grip))
	_put(k, "prop", &"gold", _tube(PackedVector3Array([hip, hip + grip * 0.07 * h]), PackedFloat32Array([0.011 * h]), 8, _rigid(Palette.GOLD), 1))
	_orb(k, "prop", &"lacquer_local", hip + grip * 0.08 * h, 0.016 * h, Palette.SINDOOR, 1)
	_ball(k, "prop", &"gold", tip, Vector3(0.012, 0.03, 0.012) * h, Palette.GOLD, _basis_y(grip))
	_finish(root, k, h, 0.0, 4.8)
	# Ten heads: the great central one, four smaller to each side in a rising arc and one above.
	var heads: Node3D = Node3D.new()
	heads.name = "Heads"
	root.add_child(heads)
	var big: Dictionary = {}
	_ravana_head(big, "h", 0.078 * h, 3.3, false)
	var small: Dictionary = {}
	_ravana_head(small, "h", 0.078 * h, 2.2, true)
	var small_mesh: ArrayMesh = MeshKit.multi(small["h"] as Dictionary)
	var main_head: Node3D = Node3D.new()
	main_head.name = "Head_main"
	main_head.position = Vector3(0.0, 0.875 * h, -0.012 * h)
	heads.add_child(main_head)
	_emit(main_head, big, "h", "Face")
	for i: int in 4:
		for sx: float in [-1.0, 1.0]:
			var fi: float = float(i)
			_side_head(heads, "Head_%s%d" % ["l" if sx > 0.0 else "r", i], small_mesh,
				Vector3(sx * (0.122 + 0.074 * fi) * h, (0.868 + 0.014 * fi + 0.005 * fi * fi) * h, (0.035 + 0.02 * fi) * h), 0.68 - 0.025 * fi, -sx * (0.14 + 0.09 * fi))
	_side_head(heads, "Head_top", small_mesh, Vector3(0.0, 1.0 * h, 0.085 * h), 0.66, 0.0)
	var player: AnimationPlayer = root.get_node("Idle") as AnimationPlayer
	var anim: Animation = player.get_animation(&"idle")
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Heads:scale"))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	anim.track_insert_key(track, 0.0, Vector3.ONE)
	anim.track_insert_key(track, anim.length * 0.5, Vector3(1.004, 1.005, 1.004))
	anim.track_insert_key(track, anim.length, Vector3.ONE)


static func _side_head(heads: Node3D, node_name: String, mesh: ArrayMesh, pos: Vector3, size: float, yaw: float) -> void:
	var head: Node3D = Node3D.new()
	head.name = node_name
	head.position = pos
	head.rotation.y = yaw
	head.scale = Vector3.ONE * size
	heads.add_child(head)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Face"
	mi.mesh = mesh
	head.add_child(mi)


static func _vibhishana(root: Node3D) -> void:
	var h: float = 2.05
	var k: Dictionary = {}
	var robe: Color = Palette.MOON
	var shade: Color = Palette.MOON.lerp(RAKSHASA_PALE, 0.55)
	_body(k, {"H": h, "w": 1.0, "skin": RAKSHASA_PALE, "cloth": robe, "cloth_lo": shade, "lower": "robe", "top": robe, "top_kind": &"cloth", "sleeve": robe, "trim": Palette.GOLD, "arm_l": "anjali", "arm_r": "anjali"})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.075 * h
	_head(k, "head", c, r, {"skin": RAKSHASA_PALE, "jaw": 0.7, "eyes": "open", "iris": Palette.NIGHT_INDIGO, "brow": Palette.NIGHT_INDIGO, "lip": RAKSHASA_PALE.lerp(LIP_ROSE, 0.5), "hair": Palette.NIGHT_INDIGO, "tilak": Palette.SAFFRON})
	_ball(k, "head", &"fur", c + Vector3(0.0, -0.5, 0.62) * r, Vector3(0.8, 0.8, 0.5) * r, Palette.NIGHT_INDIGO, Basis.IDENTITY, 2)
	# A modest crown, a saffron stole of devotion and a single necklace.
	_kirita(k, "ornaments", c + Vector3(0.0, 0.7, 0.06) * r, 0.8 * r, 1.7 * r)
	for sx: float in [-1.0, 1.0]:
		_orb(k, "ornaments", &"gold", c + Vector3(sx * 0.86, -0.34, 0.06) * r, 0.13 * r, Palette.GOLD, 1)
	_sash(k, h, 1.0, Palette.SAFFRON, Palette.SAFFRON.lerp(Palette.SINDOOR, 0.4))
	var tail_end: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.036, 0.34) * h, Vector2(0.034, 0.5) * h, Vector2(0.026, 0.76) * h]), 3)
	_put(k, "drape", &"cloth", _lathe(tail_end, 10, Palette.SAFFRON.lerp(Palette.SINDOOR, 0.4), Palette.SAFFRON, Vector2(1.0, 0.3), 4, 0.2, 0.45), Transform3D(Basis.IDENTITY, Vector3(-0.108, 0.0, 0.07) * h))
	_necklace(k, h, 1.0, 0.07, Palette.GOLD, Palette.MOON)
	_finish(root, k, h, 0.04, 4.0)


static func _indrajit(root: Node3D) -> void:
	var h: float = 2.1
	var w: float = 1.12
	var k: Dictionary = {}
	var armor: Color = Palette.RAKSHASA_ARMOR
	_body(k, {"H": h, "w": w, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.3), "cloth_lo": Palette.NIGHT_INDIGO, "top": armor, "top_kind": &"lacquer_local", "trim": Palette.GOLD, "armlets": true, "anklets": true, "arm_r": "hold", "hem": 0.2})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.075 * h
	_head(k, "head", c, r, {"skin": Palette.RAKSHASA_SKIN, "jaw": 0.8, "eyes": "glow", "brow": HAIR_BLACK, "lip": Palette.RAKSHASA_ARMOR, "hair": HAIR_BLACK})
	# Horned war helm with a gold crest.
	var helm: PackedVector2Array = _cr2(PackedVector2Array([Vector2(1.02 * r, 0.3 * r), Vector2(1.06 * r, 0.55 * r), Vector2(0.9 * r, 0.95 * r), Vector2(0.5 * r, 1.22 * r), Vector2(0.14 * r, 1.36 * r)]), 3)
	_put(k, "head", &"lacquer_local", _lathe(helm, 18, _rigid(armor.lerp(Palette.NIGHT_INDIGO, 0.3)), _rigid(armor), Vector2(0.96, 1.04)), Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.0, 0.1 * r)))
	var rim: PackedVector2Array = PackedVector2Array([Vector2(1.04 * r, 0.26 * r), Vector2(1.1 * r, 0.32 * r), Vector2(1.08 * r, 0.42 * r)])
	_put(k, "ornaments", &"gold", _lathe(rim, 18, GOLD_DARK, Palette.GOLD, Vector2(0.96, 1.04)), Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.0, 0.1 * r)))
	_put(k, "ornaments", &"gold", _lathe(PackedVector2Array([Vector2(0.16 * r, 1.3 * r), Vector2(0.1 * r, 1.5 * r), Vector2(0.16 * r, 1.62 * r), Vector2(0.02 * r, 2.2 * r)]), 10, Palette.GOLD, Palette.FIRE_CORE), Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.0, 0.1 * r)))
	for sx: float in [-1.0, 1.0]:
		_put(k, "head", &"stone", _tube(PackedVector3Array([c + Vector3(sx * 0.86, 0.7, 0.1) * r, c + Vector3(sx * 1.5, 1.0, 0.1) * r, c + Vector3(sx * 1.7, 1.6, 0.0) * r, c + Vector3(sx * 1.38, 2.2, -0.14) * r]), PackedFloat32Array([0.24 * r, 0.2 * r, 0.13 * r, 0.015 * r]), 9, _rigid(Palette.STONE), 3, PackedFloat32Array(), Vector3.RIGHT, _rigid(BROW_WHITE), 0))
		# Spiked pauldrons.
		var sh: Vector3 = Vector3(sx * 0.165 * w, 0.765, 0.0) * h
		_ball(k, "ornaments", &"gold", sh, Vector3(0.07, 0.038, 0.064) * h, GOLD_DARK.lerp(Palette.BARK, 0.25), Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.35)), 2)
		_put(k, "ornaments", &"gold", _lathe(PackedVector2Array([Vector2(0.022 * h, 0.0), Vector2(0.014 * h, 0.04 * h), Vector2(0.002 * h, 0.1 * h)]), 8, GOLD_DARK, Palette.GOLD), Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.7)), sh + Vector3(sx * 0.02, 0.025, 0.0) * h))
	# Breastplate, cape, quiver and the great bow in his right hand.
	_ball(k, "ornaments", &"gold", Vector3(0.0, 0.7, -0.058) * h, Vector3(0.105 * w, 0.072, 0.036) * h, GOLD_DARK, Basis.IDENTITY, 2)
	_orb(k, "ornaments", &"lacquer_local", Vector3(0.0, 0.705, -0.1) * h, 0.02 * h, Palette.FIRE_EDGE, 1)
	_necklace(k, h, w, 0.04, Palette.GOLD, Palette.FIRE_EDGE)
	_cape(k, "drape", h, w, Palette.NIGHT_INDIGO.lerp(armor, 0.5), Palette.NIGHT_INDIGO, 0.24, 0.45)
	_quiver(k, "prop", h, armor, Palette.FIRE_EDGE)
	var wrist: Vector3 = _arm_points(h, w, 1.0, "hold")[2]
	_bow(k, "prop", Vector3(wrist.x + 0.012 * h, wrist.y + 0.02 * h, wrist.z + 0.05 * h), 0.86 * h, armor.lerp(Palette.NIGHT_INDIGO, 0.4), Palette.GOLD)
	_finish(root, k, h, 0.0, 3.5)


static func _courtier(root: Node3D) -> void:
	var h: float = 1.85
	var w: float = 1.05
	var k: Dictionary = {}
	var coat: Color = Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.4)
	_body(k, {"H": h, "w": w, "skin": Palette.RAKSHASA_SKIN, "cloth": Palette.RAKSHASA_ARMOR, "lower": "robe", "top": coat, "top_kind": &"cloth", "sleeve": coat, "trim": Palette.GOLD, "belly": 0.012, "arm_l": "clasp", "arm_r": "clasp"})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.075 * h
	_head(k, "head", c, r, {"skin": Palette.RAKSHASA_SKIN, "jaw": 0.82, "eyes": "open", "iris": Palette.NIGHT_INDIGO, "brow": HAIR_BLACK, "lip": Palette.RAKSHASA_ARMOR, "hair": HAIR_BLACK, "moustache": true})
	# A wound turban with a jewelled aigrette, and a long gold stole.
	for i: int in 4:
		var fi: float = float(i)
		var ring: PackedVector3Array = PackedVector3Array()
		for j: int in 11:
			var a: float = TAU * float(j) / 10.0
			ring.append(c + Vector3(sin(a) * (1.02 - 0.12 * fi), 0.5 + 0.22 * fi + 0.09 * sin(a + fi * 1.3), 0.12 + cos(a) * (1.06 - 0.12 * fi)) * r)
		_put(k, "head", &"cloth", _tube(ring, PackedFloat32Array([0.19 * r]), 6, _rigid(Palette.RAKSHASA_ARMOR.lerp(Palette.NIGHT_INDIGO, 0.25 * float(i % 2))), 2))
	_ball(k, "head", &"cloth", c + Vector3(0.0, 1.16, 0.12) * r, Vector3(0.62, 0.3, 0.64) * r, Palette.RAKSHASA_ARMOR)
	_ball(k, "ornaments", &"gold", c + Vector3(0.0, 0.94, -0.92) * r, Vector3(0.16, 0.36, 0.07) * r, Palette.GOLD)
	_orb(k, "ornaments", &"lacquer_local", c + Vector3(0.0, 0.84, -1.0) * r, 0.09 * r, EMERALD)
	for sx: float in [-1.0, 1.0]:
		var stole: PackedVector3Array = PackedVector3Array([Vector3(sx * 0.07 * w, 0.775, 0.06) * h, Vector3(sx * 0.1 * w, 0.79, 0.0) * h, Vector3(sx * 0.085 * w, 0.72, -0.085) * h, Vector3(sx * 0.07 * w, 0.5, -0.118 * w) * h, Vector3(sx * 0.075 * w, 0.3, -0.13 * w) * h])
		_put(k, "drape", &"cloth", _tube(stole, PackedFloat32Array([0.011 * h]), 8, _rigid(Palette.GOLD), 3, PackedFloat32Array([3.0, 3.0, 3.0, 3.2, 3.6]), Vector3.RIGHT, _rigid(GOLD_DARK), 0, 0.35))
	_necklace(k, h, w, 0.06, Palette.GOLD, EMERALD)
	_finish(root, k, h, 0.05, 3.9)


# ================================================================ Rama (epilogue only)

static func _rama(root: Node3D) -> void:
	var h: float = 2.0
	var k: Dictionary = {}
	_body(k, {"H": h, "w": 1.0, "skin": RAMA_SKIN, "cloth": DHOTI_YELLOW, "cloth_lo": GOLD_DARK, "trim": Palette.GOLD, "armlets": true, "anklets": true, "hem": 0.1, "arm_r": "bless", "arm_l": "hold"})
	var c: Vector3 = Vector3(0.0, 0.868 * h, 0.0)
	var r: float = 0.075 * h
	_head(k, "head", c, r, {"skin": RAMA_SKIN, "jaw": 0.66, "eyes": "open", "iris": HAIR_BLACK, "brow": HAIR_BLACK, "lip": RAMA_SKIN.lerp(LIP_ROSE, 0.55), "hair": HAIR_BLACK, "tilak": Palette.SINDOOR, "nose": 0.9})
	# Dark locks to the shoulders, makara earrings.
	_ball(k, "head", &"fur", c + Vector3(0.0, -0.62, 0.52) * r, Vector3(0.86, 0.9, 0.56) * r, HAIR_BLACK, Basis.IDENTITY, 2)
	for sx: float in [-1.0, 1.0]:
		_put(k, "head", &"fur", _tube(PackedVector3Array([c + Vector3(sx * 0.8, 0.2, 0.2) * r, c + Vector3(sx * 0.94, -0.6, 0.26) * r, c + Vector3(sx * 0.98, -1.25, 0.1) * r]), PackedFloat32Array([0.2 * r, 0.22 * r, 0.1 * r]), 6, _rigid(HAIR_BLACK), 2))
		_ball(k, "ornaments", &"gold", c + Vector3(sx * 0.9, -0.36, 0.02) * r, Vector3(0.1, 0.2, 0.14) * r, Palette.GOLD)
		_orb(k, "ornaments", &"lacquer_local", c + Vector3(sx * 0.94, -0.6, 0.02) * r, 0.07 * r, Palette.SINDOOR)
	# The tall kirita.
	_kirita(k, "crown", c + Vector3(0.0, 0.64, 0.06) * r, 0.86 * r, 0.215 * h, true)
	# Necklaces, the sacred thread, a silk upper cloth and the long forest garland (vanamala).
	_necklace(k, h, 1.0, 0.03, Palette.GOLD, Palette.SINDOOR)
	_necklace(k, h, 1.0, 0.09, Palette.GOLD, EMERALD)
	_put(k, "ornaments", &"cloth", _tube(PackedVector3Array([Vector3(-0.1, 0.782, 0.0) * h, Vector3(-0.04, 0.72, -0.094) * h, Vector3(0.07, 0.62, -0.082) * h, Vector3(0.11, 0.59, 0.0) * h, Vector3(0.02, 0.68, 0.094) * h, Vector3(-0.1, 0.782, 0.0) * h]), PackedFloat32Array([0.0045 * h]), 4, _rigid(BROW_WHITE), 2))
	var silk: Color = Palette.SAFFRON
	for sx: float in [-1.0, 1.0]:
		var fall: PackedVector3Array = PackedVector3Array([Vector3(sx * 0.075, 0.78, 0.07) * h, Vector3(sx * 0.118, 0.795, 0.0) * h, Vector3(sx * 0.125, 0.74, -0.06) * h, Vector3(sx * 0.14, 0.6, -0.085) * h, Vector3(sx * 0.15, 0.42, -0.09) * h])
		_put(k, "drape", &"cloth", _tube(fall, PackedFloat32Array([0.011 * h]), 8, _rigid(silk), 3, PackedFloat32Array([2.2, 2.2, 2.2, 2.4, 3.0]), Vector3.RIGHT, _rigid(Palette.SAFFRON.lerp(Palette.SINDOOR, 0.45)), 0, 0.4))
	_put(k, "drape", &"cloth", _tube(PackedVector3Array([Vector3(-0.075, 0.78, 0.07) * h, Vector3(0.0, 0.765, 0.094) * h, Vector3(0.075, 0.78, 0.07) * h]), PackedFloat32Array([0.011 * h]), 8, _rigid(silk), 3, PackedFloat32Array([2.6, 2.6, 2.6]), Vector3.UP))
	var garland: Dictionary = {}
	var loop: PackedVector3Array = PackedVector3Array()
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		var front: float = 0.5 - 0.5 * cos(a)
		loop.append(Vector3(sin(a) * (0.085 + 0.045 * front), 0.79 - 0.4 * pow(front, 1.5), 0.05 - 0.175 * sqrt(front) + 0.02 * front) * h)
	_put(garland, "g", &"foliage", _tube(loop, PackedFloat32Array([0.016 * h]), 6, _rigid(Palette.GROVE_GREEN), 1, PackedFloat32Array(), Vector3.RIGHT, _rigid(Palette.LEAF_DARK), 2))
	for i: int in range(1, 24):
		var p: Vector3 = loop[i]
		if p.z > 0.02 * h:
			continue
		var bloom: Color = Palette.ASHOKA_RED if i % 3 == 0 else (BROW_WHITE if i % 3 == 1 else Palette.FIRE_CORE)
		_orb(garland, "g", &"cloth", p + Vector3(0.0, 0.0, -0.008 * h if p.z < 0.0 else 0.008 * h), 0.017 * h, bloom)
	# Quiver on the back; the bow Kodanda upright in the left hand.
	var quiver: Dictionary = {}
	_quiver(quiver, "q", h, Palette.BARK, Palette.GOLD)
	var wrist: Vector3 = _arm_points(h, 1.0, -1.0, "hold")[2]
	var bow: Dictionary = {}
	_bow(bow, "b", Vector3(wrist.x - 0.012 * h, 0.56 * h, wrist.z + 0.035 * h), 1.04 * h, GOLD_DARK, Palette.GOLD)
	var upper: Node3D = _finish(root, k, h, 0.0, 4.0)
	var pivot: Vector3 = upper.position
	_emit(upper, k, "crown", "Rama_Crown", -pivot)
	_emit(upper, k, "crown_peak", "Rama_Crown_Peak", -pivot)
	_emit(upper, k, "crown_point", "Rama_Crown_Point", -pivot)
	_emit(upper, k, "crown_gems", "Rama_Kirita_Gems", -pivot)
	_emit(upper, garland, "g", "Rama_Garland", -pivot)
	_emit(upper, quiver, "q", "Rama_Quiver", -pivot)
	_emit(upper, bow, "b", "Rama_Bow", -pivot)
	# Divine light: a soft halo behind the whole figure, brighter around the head.
	var halo: PackedVector2Array = _cr2(PackedVector2Array([Vector2(0.05, 0.04), Vector2(0.6, 0.25), Vector2(0.78, 0.7), Vector2(0.8, 1.4), Vector2(0.7, 2.0), Vector2(0.42, 2.45), Vector2(0.04, 2.62)]), 3)
	_aura(root, "Rama_Aura", _lathe(halo, 16, _rigid(Palette.FIRE_CORE), _rigid(BROW_WHITE)), 0.5, 3.2)


# ================================================================ set pieces

## Mainaka, the golden mountain that rises from the sea: three summits, ravines, groves on its lower slopes,
## surf at its foot and a soft glow.
static func _mainaka(root: Node3D) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 1108
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.55
	noise.fractal_octaves = 3
	var rings: int = 30
	var segs: int = 44
	var radius: float = 2.5
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i: int in rings + 1:
		var t: float = float(i) / float(rings)
		var rho: float = radius * pow(t, 0.85)
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var wobble: float = 1.0 + 0.12 * noise.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0) * t
			var x: float = sin(a) * rho * wobble
			var z: float = cos(a) * rho * wobble
			var y: float = _mainaka_height(noise, x, z)
			if i == rings:
				y = -0.35
			row.append(Vector3(x, y, z))
			var ravine: float = clampf(0.5 + 2.2 * noise.get_noise_3d(x * 2.2, y * 0.6, z * 2.2), 0.0, 1.0)
			var c: Color = GOLD_DARK.lerp(Palette.BARK, 0.35).lerp(GOLD_DARK, clampf(y / 2.6, 0.0, 1.0))
			c = c.lerp(GOLD_DARK.lerp(Palette.BARK, 0.5), 0.5 * (1.0 - ravine) * clampf(1.4 - y / 3.0, 0.0, 1.0))
			c = c.lerp(Palette.FIRE_CORE, smoothstep(3.8, 5.6, y) * 0.5)
			crow.append(_rigid(c))
		pts.append(row)
		cols.append(crow)
	var k: Dictionary = {}
	var split: int = 13
	_put(k, "peak", &"gold", _grid(pts.slice(0, split + 1), cols.slice(0, split + 1), true))
	_put(k, "peak", &"stone", _grid(pts.slice(split), cols.slice(split), true))
	_emit(root, k, "peak", "Peak")
	# Groves on the lower slopes.
	for i: int in 16:
		var a: float = 0.4 + float(i) * 2.399
		var rho: float = 1.25 + 0.75 * fposmod(float(i) * 0.618, 1.0)
		var x: float = sin(a) * rho
		var z: float = cos(a) * rho
		var y: float = _mainaka_height(noise, x, z)
		var size: float = 0.13 + 0.05 * fposmod(float(i) * 0.37, 1.0)
		_put(k, "groves", &"wood", _tube(PackedVector3Array([Vector3(x, y - 0.05, z), Vector3(x, y + size * 1.3, z)]), PackedFloat32Array([size * 0.2, size * 0.12]), 6, _rigid(Palette.BARK), 1))
		_ball(k, "groves", &"foliage", Vector3(x, y + size * 1.9, z), Vector3(size * 1.15, size, size * 1.15), Palette.GROVE_GREEN if i % 3 > 0 else Palette.LEAF_DARK)
		_ball(k, "groves", &"foliage", Vector3(x + size * 0.5, y + size * 1.5, z + size * 0.3), Vector3(size * 0.8, size * 0.7, size * 0.8), Palette.LEAF_DARK, Basis.IDENTITY, 0)
	_emit(root, k, "groves", "Groves")
	# Gold-veined boulders in the surf.
	for i: int in 7:
		var a: float = 0.9 + float(i) * 0.898
		var rho: float = 2.42 + 0.22 * fposmod(float(i) * 0.77, 1.0)
		var size: float = 0.16 + 0.12 * fposmod(float(i) * 0.41, 1.0)
		_ball(k, "rocks", &"stone", Vector3(sin(a) * rho, 0.04, cos(a) * rho), Vector3(size * 1.3, size * 0.8, size), GOLD_DARK.lerp(Palette.BARK, 0.45), Basis.from_euler(Vector3(0.2 * float(i), float(i), 0.0)))
		_ball(k, "rocks", &"gold", Vector3(sin(a) * rho, 0.04 + size * 0.5, cos(a) * rho), Vector3(size * 0.6, size * 0.4, size * 0.5), GOLD_DARK, Basis.from_euler(Vector3(0.0, float(i) * 1.7, 0.3)), 0)
	_emit(root, k, "rocks", "Rocks")
	# Golden pinnacles on the three summits.
	for s: Vector3 in [Vector3(0.0, 5.0, 0.0), Vector3(-1.05, 3.6, 0.4), Vector3(0.95, 3.2, -0.5)]:
		var spire: PackedVector2Array = PackedVector2Array([Vector2(0.11, -0.12), Vector2(0.15, 0.0), Vector2(0.06, 0.07), Vector2(0.09, 0.14), Vector2(0.02, 0.28), Vector2(0.004, 0.4)])
		_put(k, "spires", &"gold", _lathe(spire, 10, Palette.GOLD, Palette.FIRE_CORE), Transform3D(Basis.IDENTITY, Vector3(s.x, _mainaka_height(noise, s.x, s.z) + 0.02, s.z)))
	_emit(root, k, "spires", "Spires")
	# Surf where the mountain breaks the sea.
	var foam_pts: Array[PackedVector3Array] = []
	var foam_cols: Array[PackedColorArray] = []
	var widths: Array[float] = [0.9, 1.0, 1.12, 1.3]
	var alphas: Array[float] = [0.0, 0.75, 0.45, 0.0]
	for i: int in 4:
		var row: PackedVector3Array = PackedVector3Array()
		var crow: PackedColorArray = PackedColorArray()
		for j: int in segs:
			var a: float = TAU * float(j) / float(segs)
			var wobble: float = 1.0 + 0.12 * noise.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0)
			row.append(Vector3(sin(a) * radius * wobble * widths[i], 0.03 + 0.01 * float(i), cos(a) * radius * wobble * widths[i]))
			crow.append(Color(BROW_WHITE.r, BROW_WHITE.g, BROW_WHITE.b, alphas[i]))
		foam_pts.append(row)
		foam_cols.append(crow)
	_put(k, "surf", &"water_edge", _grid(foam_pts, foam_cols, true))
	_emit(root, k, "surf", "Surf")
	_aura(root, "Mainaka_Glow", MeshKit.with_wind(MeshKit.sphere(1.0, 12, 20, Palette.FIRE_CORE, true), 0.0), 0.28, 1.5).transform = Transform3D(Basis.from_scale(Vector3(3.6, 4.4, 3.6)), Vector3(0.0, 2.6, 0.0))
	_idle(root, ["Mainaka_Glow"], Vector3(0.04, 0.03, 0.04), 5.0)


static func _mainaka_height(noise: FastNoiseLite, x: float, z: float) -> float:
	var y: float = 0.0
	var peaks: Array[Vector3] = [Vector3(0.0, 5.0, 0.0), Vector3(-1.05, 3.6, 0.4), Vector3(0.95, 3.2, -0.5), Vector3(0.2, 2.3, 1.2), Vector3(-0.5, 2.1, -1.2)]
	var widths: Array[float] = [1.45, 0.75, 0.7, 0.7, 0.7]
	for i: int in peaks.size():
		var d: float = Vector2(x - peaks[i].x, z - peaks[i].z).length()
		# A sharp summit on a broad shoulder.
		var cone: float = peaks[i].y * (0.45 * pow(maxf(0.0, 1.0 - d / (widths[i] * 1.9)), 1.25) + 0.55 * exp(-d * d / (widths[i] * widths[i] * 1.1)))
		y = maxf(y, cone) + 0.12 * minf(y, cone)
	var rho: float = Vector2(x, z).length()
	var skirt: float = clampf(1.0 - rho / 2.5, 0.0, 1.0)
	var ridges: float = 1.0 - absf(noise.get_noise_2d(x * 1.7, z * 1.7)) * 2.0
	y = y * (0.72 + 0.28 * ridges) * pow(skirt, 0.42) + 0.25 * noise.get_noise_2d(x * 3.0 + 9.0, z * 3.0) * skirt
	return maxf(y, 0.0)


## Surasa, mother of the nagas: a great jewelled serpent coiled on the sea, her crowned hood raised.
static func _surasa(root: Node3D) -> void:
	var k: Dictionary = {}
	var scale_dark: Color = EMERALD.lerp(Palette.LEAF_DARK, 0.7)
	var belly: Color = EMERALD.lerp(Palette.FIRE_CORE, 0.6)
	# Coils: one long body winding upward, its tail tip resting outside the pile.
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var turns: float = 3.25
	var count: int = 80
	for i: int in count + 1:
		var u: float = float(i) / float(count)
		var a: float = u * TAU * turns + TAU * 0.75
		var rr: float = lerpf(1.3, 0.5, pow(u, 0.9)) + (0.7 * pow(1.0 - u / 0.1, 2.0) if u < 0.1 else 0.0)
		var thick: float = lerpf(0.05, 0.34, smoothstep(0.0, 0.2, u)) - 0.06 * smoothstep(0.75, 1.0, u)
		path.append(Vector3(sin(a) * rr, thick + 1.42 * pow(u, 1.15), cos(a) * rr))
		radii.append(thick)
	_put(k, "coil", &"lacquer_local", _tube(path, radii, 12, _rigid(EMERALD), 1, PackedFloat32Array(), Vector3.UP, _rigid(belly), -1))
	# Dark saddle bands and gold rings set with gems along the body.
	for i: int in range(8, count - 2, 10):
		var tangent: Vector3 = (path[i + 1] - path[i - 1]).normalized()
		var around: Basis = _basis_y(tangent)
		_ball(k, "jewels", &"gold", path[i], Vector3(radii[i] * 1.07, radii[i] * 0.2, radii[i] * 1.07), Palette.GOLD, around, 1)
		_orb(k, "jewels", &"lacquer_local", path[i] + Vector3(0.0, radii[i] * 1.02, 0.0), radii[i] * 0.22, Palette.SINDOOR, 0)
		var outward: Vector3 = Vector3(path[i].x, 0.0, path[i].z).normalized()
		_orb(k, "jewels", &"lacquer_local", path[i] + outward * radii[i] * 1.04, radii[i] * 0.2, Palette.FIRE_CORE, 0)
	_emit(root, k, "coil", "Coil")
	# Neck rising from the middle of the coil and flaring into the hood.
	var raised: Node3D = Node3D.new()
	raised.name = "Raised"
	root.add_child(raised)
	var neck: PackedVector3Array = PackedVector3Array([Vector3(0.0, 1.25, 0.5), Vector3(0.0, 1.95, 0.47), Vector3(0.0, 2.45, 0.38), Vector3(0.0, 2.95, 0.2), Vector3(0.0, 3.35, 0.04), Vector3(0.0, 3.7, -0.1), Vector3(0.0, 4.0, -0.2)])
	_put(k, "hood", &"lacquer_local", _tube(neck, PackedFloat32Array([0.28, 0.27, 0.25, 0.19, 0.15, 0.14, 0.06]), 16, _rigid(EMERALD), 4, PackedFloat32Array([1.0, 1.0, 1.3, 4.0, 6.2, 6.2, 3.4]), Vector3.RIGHT, _rigid(belly), -2))
	# Hood markings: ribs and the twin "eyes" of the cobra in gold, on the side that faces the traveller.
	for sx: float in [-1.0, 1.0]:
		_ball(k, "jewels", &"gold", Vector3(sx * 0.42, 3.3, -0.12), Vector3(0.16, 0.16, 0.03), Palette.GOLD, Basis.from_euler(Vector3(-0.35, 0.0, 0.0)), 1)
		_ball(k, "jewels", &"lacquer_local", Vector3(sx * 0.42, 3.3, -0.145), Vector3(0.085, 0.085, 0.025), EMERALD.lerp(Palette.LEAF_DARK, 0.6), Basis.from_euler(Vector3(-0.35, 0.0, 0.0)), 1)
		for j: int in 3:
			var fj: float = float(j)
			_put(k, "hood", &"lacquer_local", _tube(PackedVector3Array([Vector3(sx * 0.12, 3.0 + 0.24 * fj, 0.36 - 0.1 * fj), Vector3(sx * (0.4 + 0.08 * fj), 3.14 + 0.24 * fj, 0.3 - 0.1 * fj), Vector3(sx * (0.62 + 0.08 * fj), 3.36 + 0.2 * fj, 0.2 - 0.09 * fj)]), PackedFloat32Array([0.03, 0.035, 0.015]), 6, _rigid(scale_dark), 3))
	# Head: a broad serpent's skull with a blunt snout, calm gold eyes.
	_ball(k, "head", &"lacquer_local", Vector3(0.0, 3.68, -0.36), Vector3(0.36, 0.24, 0.4), EMERALD, Basis.from_euler(Vector3(0.18, 0.0, 0.0)), 2)
	_ball(k, "head", &"lacquer_local", Vector3(0.0, 3.6, -0.58), Vector3(0.26, 0.15, 0.24), EMERALD.lerp(belly, 0.25), Basis.from_euler(Vector3(0.18, 0.0, 0.0)), 2)
	_ball(k, "head", &"lacquer_local", Vector3(0.0, 3.5, -0.5), Vector3(0.23, 0.09, 0.25), belly, Basis.from_euler(Vector3(0.18, 0.0, 0.0)), 2)
	for sx: float in [-1.0, 1.0]:
		_ball(k, "eyes", &"gold", Vector3(sx * 0.25, 3.73, -0.56), Vector3(0.07, 0.055, 0.07), Palette.FIRE_CORE, Basis.IDENTITY, 1)
		_ball(k, "eyes", &"lacquer_local", Vector3(sx * 0.285, 3.73, -0.6), Vector3(0.018, 0.046, 0.032), HAIR_BLACK)
		_ball(k, "head", &"lacquer_local", Vector3(sx * 0.24, 3.8, -0.52), Vector3(0.11, 0.04, 0.13), scale_dark)
		_orb(k, "head", &"lacquer_local", Vector3(sx * 0.08, 3.63, -0.81), 0.016, HAIR_BLACK)
	_emit(raised, k, "hood", "Hood")
	_emit(raised, k, "head", "Head")
	_emit(raised, k, "eyes", "Eyes")
	_emit(raised, k, "jewels", "Jewels")
	# Crown and a jewelled collar.
	_kirita(k, "crown", Vector3(0.0, 3.86, -0.3), 0.22, 0.6)
	var collar: PackedVector2Array = PackedVector2Array([Vector2(0.27, -0.05), Vector2(0.3, 0.0), Vector2(0.27, 0.05)])
	_put(k, "crown", &"gold", _lathe(collar, 14, GOLD_DARK, Palette.GOLD), Transform3D(Basis.from_euler(Vector3(-0.2, 0.0, 0.0)), Vector3(0.02, 2.6, 0.32)))
	_emit(raised, k, "crown", "Crown")
	_idle(root, ["Raised"], Vector3(0.012, 0.01, 0.02), 5.2)
