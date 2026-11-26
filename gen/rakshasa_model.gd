class_name RakshasaModel
extends RefCounted
## Rakshasa foes, art direction v2 (docs/ART.md "Characters"; DESIGN §9 M08, A2, B2).
##
## Smooth sculpted bodies: every form is a swept tube with an elliptical, varying cross-section (limbs with muscle
## profiles, torsos, curved horns and tusks), an ellipsoid, or a cone spike, all with smooth normals. Each bone
## carries ONE MeshInstance3D named "Part" on a BoneAttachment3D (rigid parts, no skinning) whose mesh has one
## surface per material kind (Materials: skin, lacquer armour, gold and bronze, cloth with wind weights, fur, wood)
## plus a small emissive "glow" surface for the eyes. Meshes are cached per variant.
##
## Forward is -Z. Variants, distinct by silhouette:
##   spear   - the guard: bronze helm with a crimson crest, tall swept horns, cuirass, cape, long spear;
##   archer  - lean: cloth head-wrap, swept-back horns, bandolier, quiver, tall recurved bow;
##   brute   - the kinkara: enormous, hunched, bull horns, fur mantle, spiked yoke, studded club;
##   lankini - the tall guardian of Lanka: tiered gold crown, lyre horns, gold armour, long hair, trident.
## Pose names match HanumanModel: idle, walk_a, walk_b, attack_wind, attack_strike ("walk" and "attack" are aliases).
## set_pose() applies a pose at once. Inside the scene tree the child node "Animator" then eases toward it, adds
## breathing, and plays a walk cycle by itself whenever an idle model is being moved. The child "EmberGlow" is
## a small shadowless warm light that keeps the dark figures readable at night.
##
## The sculpting helpers grid_surface(), tube(), ring(), cloth_panel(), ellipsoid(), spike() and glow_material()
## are public: SimhikaModel and ChariotModel are built with them.

const POSES: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike"]
const VARIANTS: Array[StringName] = [&"spear", &"archer", &"brute", &"lankini"]
## Name of the emissive eye surface in a head mesh.
const GLOW_SURFACE: String = "glow"

## Energy of the small warm light every rakshasa carries (the child node "EmberGlow").
const EMBER_ENERGY: float = 0.5
const _ANIM_BONES: Array[String] = [
	"hips", "spine", "chest", "head", "upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r", "weapon_socket",
]

## Pose tables: bone name -> Euler angles (radians, x = pitch, y = twist, z = roll) applied on top of the rest
## pose. Positive pitch swings a hanging limb forward (-Z) and tips the upright torso backward.
## "weapon_socket" is different: x is the weapon's pitch in MODEL space (0 = upright, -PI/2 = pointing forward),
## solved against the arm so a spear stays level through a thrust.
const _WALK_A: Dictionary = {
	"upper_leg_l": Vector3(0.6, 0.0, 0.0), "lower_leg_l": Vector3(-0.25, 0.0, 0.0),
	"upper_leg_r": Vector3(-0.5, 0.0, 0.0), "lower_leg_r": Vector3(-0.5, 0.0, 0.0),
	"upper_arm_l": Vector3(-0.45, 0.0, 0.1), "lower_arm_l": Vector3(0.25, 0.0, 0.0),
	"chest": Vector3(-0.05, 0.08, 0.0), "hips": Vector3(0.0, -0.08, 0.03),
}
const _WALK_B: Dictionary = {
	"upper_leg_l": Vector3(-0.5, 0.0, 0.0), "lower_leg_l": Vector3(-0.5, 0.0, 0.0),
	"upper_leg_r": Vector3(0.6, 0.0, 0.0), "lower_leg_r": Vector3(-0.25, 0.0, 0.0),
	"upper_arm_l": Vector3(0.45, 0.0, 0.1), "lower_arm_l": Vector3(0.45, 0.0, 0.0),
	"chest": Vector3(-0.05, -0.08, 0.0), "hips": Vector3(0.0, 0.08, -0.03),
}
const _POLEARM: Dictionary = {
	"idle": {
		"chest": Vector3(0.02, 0.0, 0.0), "upper_arm_l": Vector3(0.0, 0.0, 0.12), "lower_arm_l": Vector3(0.2, 0.0, 0.0),
		"upper_arm_r": Vector3(0.25, 0.0, -0.14), "lower_arm_r": Vector3(0.55, 0.0, 0.0),
		"weapon_socket": Vector3(-0.1, 0.0, 0.0),
	},
	"carry": {
		"upper_arm_r": Vector3(0.3, 0.0, -0.14), "lower_arm_r": Vector3(0.6, 0.0, 0.0),
		"weapon_socket": Vector3(-0.22, 0.0, 0.0),
	},
	"attack_wind": {
		"chest": Vector3(0.1, -0.45, 0.0), "hips": Vector3(0.0, -0.15, 0.0),
		"upper_arm_r": Vector3(-0.75, 0.0, -0.3), "lower_arm_r": Vector3(1.5, 0.0, 0.0),
		"upper_arm_l": Vector3(0.9, 0.0, 0.1), "lower_arm_l": Vector3(0.4, 0.0, 0.0),
		"upper_leg_l": Vector3(0.3, 0.0, 0.0), "lower_leg_l": Vector3(-0.3, 0.0, 0.0),
		"upper_leg_r": Vector3(-0.25, 0.0, 0.0), "lower_leg_r": Vector3(-0.2, 0.0, 0.0),
		"weapon_socket": Vector3(-1.5, 0.0, 0.0),
	},
	"attack_strike": {
		"chest": Vector3(-0.28, 0.4, 0.0), "hips": Vector3(0.0, 0.12, 0.0),
		"upper_arm_r": Vector3(1.35, 0.0, -0.05), "lower_arm_r": Vector3(0.15, 0.0, 0.0),
		"upper_arm_l": Vector3(-0.55, 0.0, 0.18), "lower_arm_l": Vector3(0.5, 0.0, 0.0),
		"upper_leg_l": Vector3(0.65, 0.0, 0.0), "lower_leg_l": Vector3(-0.6, 0.0, 0.0),
		"upper_leg_r": Vector3(-0.45, 0.0, 0.0), "lower_leg_r": Vector3(-0.1, 0.0, 0.0),
		"weapon_socket": Vector3(-1.62, 0.0, 0.0),
	},
}
const _CLUB: Dictionary = {
	"idle": {
		"chest": Vector3(0.02, 0.0, 0.0), "upper_arm_l": Vector3(0.12, 0.0, 0.2), "lower_arm_l": Vector3(0.3, 0.0, 0.0),
		"upper_arm_r": Vector3(0.2, 0.0, -0.2), "lower_arm_r": Vector3(0.3, 0.0, 0.0),
		"weapon_socket": Vector3(-2.25, 0.0, 0.0),
	},
	"carry": {
		"upper_arm_r": Vector3(0.25, 0.0, -0.2), "lower_arm_r": Vector3(0.5, 0.0, 0.0),
		"weapon_socket": Vector3(-2.0, 0.0, 0.0),
	},
	"attack_wind": {
		"chest": Vector3(0.3, -0.3, 0.0), "head": Vector3(-0.15, 0.0, 0.0),
		"upper_arm_r": Vector3(-2.5, 0.0, -0.25), "lower_arm_r": Vector3(0.5, 0.0, 0.0),
		"upper_arm_l": Vector3(0.7, 0.0, 0.25), "lower_arm_l": Vector3(0.5, 0.0, 0.0),
		"upper_leg_l": Vector3(0.3, 0.0, 0.0), "lower_leg_l": Vector3(-0.3, 0.0, 0.0),
		"weapon_socket": Vector3(0.75, 0.0, 0.0),
	},
	"attack_strike": {
		"chest": Vector3(-0.45, 0.3, 0.0), "head": Vector3(0.2, 0.0, 0.0),
		"upper_arm_r": Vector3(1.0, 0.0, -0.1), "lower_arm_r": Vector3(0.35, 0.0, 0.0),
		"upper_arm_l": Vector3(-0.5, 0.0, 0.3), "lower_arm_l": Vector3(0.6, 0.0, 0.0),
		"upper_leg_l": Vector3(0.55, 0.0, 0.0), "lower_leg_l": Vector3(-0.55, 0.0, 0.0),
		"upper_leg_r": Vector3(-0.35, 0.0, 0.0), "lower_leg_r": Vector3(-0.15, 0.0, 0.0),
		"weapon_socket": Vector3(-2.15, 0.0, 0.0),
	},
}
const _BOW: Dictionary = {
	"idle": {
		"chest": Vector3(0.02, 0.0, 0.0), "upper_arm_l": Vector3(0.0, 0.0, 0.12), "lower_arm_l": Vector3(0.25, 0.0, 0.0),
		"upper_arm_r": Vector3(0.2, 0.0, -0.3), "lower_arm_r": Vector3(0.5, 0.0, 0.0),
		"weapon_socket": Vector3(-0.18, 0.0, -0.4),
	},
	"carry": {
		"upper_arm_r": Vector3(0.25, 0.0, -0.3), "lower_arm_r": Vector3(0.6, 0.0, 0.0),
		"weapon_socket": Vector3(-0.3, 0.0, -0.4),
	},
	"attack_wind": {
		"chest": Vector3(0.06, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0),
		"upper_arm_r": Vector3(1.5, 0.0, -0.1), "lower_arm_r": Vector3(0.05, 0.0, 0.0),
		"upper_arm_l": Vector3(1.2, 0.0, 0.5), "lower_arm_l": Vector3(1.75, 0.0, 0.0),
		"upper_leg_l": Vector3(0.2, 0.0, 0.0), "upper_leg_r": Vector3(-0.2, 0.0, 0.0),
		"weapon_socket": Vector3(0.0, 0.0, 0.0),
	},
	"attack_strike": {
		"chest": Vector3(0.12, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"upper_arm_r": Vector3(1.55, 0.0, -0.1), "lower_arm_r": Vector3(0.0, 0.0, 0.0),
		"upper_arm_l": Vector3(0.75, 0.0, 0.75), "lower_arm_l": Vector3(1.1, 0.0, 0.0),
		"upper_leg_l": Vector3(0.2, 0.0, 0.0), "upper_leg_r": Vector3(-0.2, 0.0, 0.0),
		"weapon_socket": Vector3(-0.12, 0.0, 0.0),
	},
}

static var _mesh_cache: Dictionary = {}
static var _glow_material: ShaderMaterial = null


## Eases the skeleton toward the pose last given to RakshasaModel.set_pose(), breathes, and walks by itself while
## an idle model is carried across the ground. It only runs inside the scene tree.
class Animator extends Node:
	var skeleton: Skeleton3D = null
	var style: Dictionary = {}
	var stride: float = 1.5
	var target: StringName = &"idle"
	var _shown: Dictionary = {}
	var _time: float = 0.0
	var _phase: float = 0.0
	var _walk: float = 0.0
	var _last_pos: Vector3 = Vector3.ZERO
	var _has_last: bool = false

	func _ready() -> void:
		# Each model breathes on its own beat.
		_time = fmod(float(get_instance_id() % 997) * 0.37, 20.0)

	func _process(delta: float) -> void:
		if skeleton == null or delta <= 0.0:
			return
		var parent: Node3D = get_parent() as Node3D
		if parent == null or not parent.is_visible_in_tree():
			return
		_time += delta
		var pos: Vector3 = parent.global_position
		var dist: float = 0.0
		if _has_last:
			dist = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
		_last_pos = pos
		_has_last = true
		var speed: float = minf(dist / delta, 12.0)
		var moving: float = smoothstep(0.25, 1.1, speed) if target == &"idle" else 0.0
		_walk = lerpf(_walk, moving, 1.0 - exp(-8.0 * delta))
		_phase = fmod(_phase + minf(dist, 0.5) / maxf(stride, 0.1) * TAU, TAU)
		var goal: Dictionary = RakshasaModel._pose_eulers(style, target)
		var swing: float = 0.5 + 0.5 * sin(_phase)
		var step_a: Dictionary = RakshasaModel._pose_eulers(style, &"walk_a")
		var step_b: Dictionary = RakshasaModel._pose_eulers(style, &"walk_b")
		var rate: float = 26.0 if target == &"attack_strike" else 13.0
		var k: float = 1.0 - exp(-rate * delta)
		var breath: float = sin(_time * 1.9)
		var out: Dictionary = {}
		for bone: String in RakshasaModel._ANIM_BONES:
			var want: Vector3 = goal.get(bone, Vector3.ZERO) as Vector3
			if _walk > 0.001:
				var a: Vector3 = step_a.get(bone, Vector3.ZERO) as Vector3
				var b: Vector3 = step_b.get(bone, Vector3.ZERO) as Vector3
				want = want.lerp(a.lerp(b, swing), _walk)
			var cur: Vector3 = _shown.get(bone, want) as Vector3
			cur = cur.lerp(want, k)
			_shown[bone] = cur
			out[bone] = cur
		# Breathing: the chest lifts, the shoulders spread and the head settles against it.
		out["chest"] = (out["chest"] as Vector3) + Vector3(0.022 * breath, 0.0, 0.0)
		out["head"] = (out["head"] as Vector3) + Vector3(-0.018 * breath, 0.0, 0.0)
		out["upper_arm_l"] = (out["upper_arm_l"] as Vector3) + Vector3(0.0, 0.0, 0.02 * breath)
		out["upper_arm_r"] = (out["upper_arm_r"] as Vector3) + Vector3(0.0, 0.0, -0.02 * breath)
		var bob: float = -absf(cos(_phase)) * 0.035 * _walk * stride
		RakshasaModel._apply_eulers(skeleton, out, bob)


## Builds a rakshasa of the given variant. Returns the root Node3D; its child "Skeleton3D" holds the bones and
## BoneAttachment3D parts, its child "Animator" the idle and walk motion. Unknown variants fall back to spear.
static func build(variant: StringName) -> Node3D:
	var known: StringName = variant if VARIANTS.has(variant) else &"spear"
	var spec: Dictionary = _spec(known)
	var root: Node3D = Node3D.new()
	root.name = "Rakshasa_" + String(variant)
	root.set_meta(&"variant", known)
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	_add_bones(skeleton, spec)
	var meshes: Dictionary = _meshes_for(known, spec)
	for bone_key: Variant in meshes:
		var bone: String = bone_key as String
		var attach: BoneAttachment3D = BoneAttachment3D.new()
		attach.name = "Attach_" + bone
		attach.bone_name = bone
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Part"
		mi.mesh = meshes[bone] as ArrayMesh
		attach.add_child(mi)
		skeleton.add_child(attach)
	# A faint ember glow, as if lit by their own eyes: it keeps the dark figures readable in Lanka's night and
	# pools a little warm light at their feet.
	var ember: OmniLight3D = OmniLight3D.new()
	ember.name = "EmberGlow"
	ember.light_color = Palette.FIRE_CORE.lerp(Palette.FIRE_EDGE, 0.45)
	ember.light_energy = EMBER_ENERGY
	ember.omni_range = 2.3 * (spec["h"] as float) * (0.8 + 0.2 * (spec["w"] as float))
	ember.omni_attenuation = 2.0
	ember.shadow_enabled = false
	ember.light_specular = 0.0
	ember.position = Vector3(0.0, 1.5 * (spec["h"] as float), -0.9)
	root.add_child(ember)
	var animator: Animator = Animator.new()
	animator.name = "Animator"
	animator.skeleton = skeleton
	animator.style = _style(spec["weapon"] as StringName)
	animator.stride = 1.5 * (spec["h"] as float)
	root.add_child(animator)
	set_pose(root, &"idle")
	return root


## Applies a named pose to the Skeleton3D inside `root`, at once. Unknown pose names give the idle pose.
static func set_pose(root: Node3D, pose: StringName) -> void:
	var skeleton: Skeleton3D = _find_skeleton(root)
	if skeleton == null:
		return
	var variant: StringName = root.get_meta(&"variant", &"spear") as StringName
	var style: Dictionary = _style(_spec(variant)["weapon"] as StringName)
	var name: StringName = _canonical(pose)
	_apply_eulers(skeleton, _pose_eulers(style, name), 0.0)
	var animator: Animator = root.get_node_or_null("Animator") as Animator
	if animator != null:
		animator.target = name


## Pose of a bone in model (skeleton) space, composed from the local bone poses. Unlike
## Skeleton3D.get_bone_global_pose() it is up to date outside the scene tree too.
static func bone_pose_in_model(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var idx: int = bone
	while idx >= 0:
		xf = skeleton.get_bone_pose(idx) * xf
		idx = skeleton.get_bone_parent(idx)
	return xf


## Number of triangles in every mesh of a built model.
static func triangle_count(root: Node) -> int:
	var total: int = 0
	var mi: MeshInstance3D = root as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s: int in range(mi.mesh.get_surface_count()):
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			total += verts.size() / 3
	for child: Node in root.get_children():
		total += triangle_count(child)
	return total


# ---- sculpting helpers (shared with SimhikaModel and ChariotModel) -----------------------------------

## Unshaded emissive material for eyes: vertex colour, pushed above the glow threshold so it blooms.
static func glow_material() -> ShaderMaterial:
	if _glow_material == null:
		var shader: Shader = Shader.new()
		shader.code = "shader_type spatial;\nrender_mode unshaded;\nuniform float energy = 3.2;\nvoid fragment() {\n\tvec3 c = pow(COLOR.rgb, vec3(2.2));\n\tfloat core = pow(clamp(dot(normalize(NORMAL), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 2.0);\n\tALBEDO = c * energy * (0.55 + 0.75 * core) + vec3(core * core) * 0.6;\n}\n"
		_glow_material = ShaderMaterial.new()
		_glow_material.resource_name = GLOW_SURFACE
		_glow_material.shader = shader
	return _glow_material


## Smooth surface through a grid of points: rows[i][j]. With `wrap` every row is a closed loop (a tube) and the
## normals point away from the row's centre; otherwise the surface is an open sheet whose normals face
## `side_hint`. Normals come from central differences, so tapers and bulges shade correctly. A row collapsed to a
## single point closes the surface (an end cap). `colors` is a gradient along the rows (one colour = uniform); its
## alpha is the wind weight.
static func grid_surface(rows: Array[PackedVector3Array], colors: PackedColorArray, wrap: bool, side_hint: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var nrows: int = rows.size()
	if nrows < 2:
		return ArrayMesh.new()
	var ncols: int = rows[0].size()
	var cents: PackedVector3Array = PackedVector3Array()
	for row: PackedVector3Array in rows:
		var sum: Vector3 = Vector3.ZERO
		for p: Vector3 in row:
			sum += p
		cents.append(sum / float(ncols))
	var normals: Array[PackedVector3Array] = []
	var row_cols: PackedColorArray = PackedColorArray()
	for i: int in range(nrows):
		row_cols.append(gradient(colors, float(i) / float(nrows - 1)))
		var out: PackedVector3Array = PackedVector3Array()
		out.resize(ncols)
		var up: int = mini(i + 1, nrows - 1)
		var down: int = maxi(i - 1, 0)
		for j: int in range(ncols):
			var jn: int = (j + 1) % ncols if wrap else mini(j + 1, ncols - 1)
			var jp: int = (j - 1 + ncols) % ncols if wrap else maxi(j - 1, 0)
			var n: Vector3 = (rows[i][jn] - rows[i][jp]).cross(rows[up][j] - rows[down][j])
			var ref: Vector3 = rows[i][j] - cents[i] if wrap else side_hint
			if n.length_squared() < 1e-14:
				n = cents[i] - cents[up] if i == 0 else cents[i] - cents[down]
				ref = n
				if n.length_squared() < 1e-14:
					n = side_hint if side_hint != Vector3.ZERO else Vector3.UP
			n = n.normalized()
			if ref.length_squared() > 1e-12 and n.dot(ref) < 0.0:
				n = -n
			out[j] = n
		normals.append(out)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var last_col: int = ncols if wrap else ncols - 1
	for i: int in range(nrows - 1):
		for j: int in range(last_col):
			var j2: int = (j + 1) % ncols
			count += _emit(st, rows[i][j], rows[i][j2], rows[i + 1][j2], normals[i][j], normals[i][j2], normals[i + 1][j2], row_cols[i], row_cols[i], row_cols[i + 1])
			count += _emit(st, rows[i][j], rows[i + 1][j2], rows[i + 1][j], normals[i][j], normals[i + 1][j2], normals[i + 1][j], row_cols[i], row_cols[i + 1], row_cols[i + 1])
	if count == 0:
		return ArrayMesh.new()
	return st.commit()


## Smooth tube swept along `points` (control points, resampled `subdiv` times per span with a Catmull-Rom
## spline). `radii` gives the elliptical cross-section per control point: x across the tube (sideways), y along
## `hint` (one entry = uniform). `colors` is a gradient along the tube. Open ends with a radius are closed.
## For an upright tube with the default hint, radii are (x half-width, z half-depth).
static func tube(points: PackedVector3Array, radii: PackedVector2Array, sides: int, colors: PackedColorArray, subdiv: int = 1, hint: Vector3 = Vector3.BACK, capped: bool = true) -> ArrayMesh:
	var n: int = points.size()
	if n < 2 or radii.size() == 0:
		return ArrayMesh.new()
	var steps: int = maxi(subdiv, 1)
	var path: PackedVector3Array = PackedVector3Array()
	var rad: PackedVector2Array = PackedVector2Array()
	for i: int in range(n - 1):
		var i0: int = maxi(i - 1, 0)
		var i3: int = mini(i + 2, n - 1)
		for s: int in range(steps):
			var t: float = float(s) / float(steps)
			path.append(points[i].cubic_interpolate(points[i + 1], points[i0], points[i3], t))
			rad.append(_radius_at(radii, i, i + 1, i0, i3, t))
	path.append(points[n - 1])
	rad.append(_radius_at(radii, n - 1, n - 1, n - 1, n - 1, 0.0))
	var count: int = path.size()
	var rows: Array[PackedVector3Array] = []
	var cols: PackedColorArray = PackedColorArray()
	var normal: Vector3 = Vector3.ZERO
	for i: int in range(count):
		var tangent: Vector3 = (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
		if i == 0:
			normal = hint - tangent * hint.dot(tangent)
			if normal.length_squared() < 1e-6:
				normal = Vector3.RIGHT - tangent * tangent.x
			if normal.length_squared() < 1e-6:
				normal = Vector3.UP
		else:
			normal = normal - tangent * normal.dot(tangent)
		normal = normal.normalized()
		var side: Vector3 = tangent.cross(normal)
		var ring_points: PackedVector3Array = PackedVector3Array()
		for k: int in range(maxi(sides, 3)):
			var a: float = TAU * float(k) / float(maxi(sides, 3))
			ring_points.append(path[i] + side * (cos(a) * rad[i].x) + normal * (sin(a) * rad[i].y))
		rows.append(ring_points)
		cols.append(gradient(colors, float(i) / float(count - 1)))
	if capped:
		if rad[0].length() > 1e-4:
			rows.insert(0, _point_row(path[0], maxi(sides, 3)))
			cols.insert(0, cols[0])
		if rad[count - 1].length() > 1e-4:
			rows.append(_point_row(path[count - 1], maxi(sides, 3)))
			cols.append(cols[cols.size() - 1])
	return grid_surface(rows, cols, true)


## Torus: a tube of radius `thickness` around the ellipse centre + axis_u * cos + axis_v * sin.
static func ring(center: Vector3, axis_u: Vector3, axis_v: Vector3, thickness: float, segments: int, sides: int, color: Color) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	var axis: Vector3 = axis_u.cross(axis_v).normalized()
	for i: int in range(segments + 1):
		var a: float = TAU * float(i % segments) / float(segments)
		var radial: Vector3 = axis_u * cos(a) + axis_v * sin(a)
		var out_dir: Vector3 = radial.normalized()
		var row: PackedVector3Array = PackedVector3Array()
		for k: int in range(sides):
			var b: float = TAU * float(k) / float(sides)
			row.append(center + radial + out_dir * (cos(b) * thickness) + axis * (sin(b) * thickness))
		rows.append(row)
	return grid_surface(rows, PackedColorArray([color]), true)


## Hanging cloth: a sheet from `top` (centre of the pinned edge) down `length`, `across` being the direction of
## its width. It widens from width_top to width_bottom, bulges along `bulge` (a vector, largest mid-way), curls
## around the body by `wrap_depth`, and its wind weight rises from 0 at the pinned edge to `wind` at the hem.
## `colors` is a gradient from the pinned edge to the hem (alpha is replaced by the wind weight).
static func cloth_panel(top: Vector3, across: Vector3, length: float, width_top: float, width_bottom: float, bulge: Vector3, wrap_depth: float, colors: PackedColorArray, wind: float, rows_n: int = 6, cols_n: int = 5) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	var cols: PackedColorArray = PackedColorArray()
	var side: Vector3 = across.normalized()
	var facing: Vector3 = bulge.normalized() if bulge.length_squared() > 1e-10 else side.cross(Vector3.UP)
	for i: int in range(rows_n):
		var t: float = float(i) / float(rows_n - 1)
		var centre: Vector3 = top + Vector3.DOWN * (length * t) + bulge * sin(t * PI * 0.8)
		var half: float = lerpf(width_top, width_bottom, t) * 0.5
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in range(cols_n):
			var u: float = float(j) / float(cols_n - 1) * 2.0 - 1.0
			# A soft fold pattern that deepens toward the hem.
			var fold: float = sin(u * 5.5 + t * 2.0) * 0.012 * t * (length + 0.3)
			row.append(centre + side * (u * half) - facing * (u * u * wrap_depth) + facing * fold)
		rows.append(row)
		var c: Color = gradient(colors, t)
		c.a = wind * pow(t, 1.4)
		cols.append(c)
	return grid_surface(rows, cols, false, facing)


## merge() part: a smooth ellipsoid with the given radii.
static func ellipsoid(color: Color, radii: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY, rings: int = 5, segments: int = 8) -> Dictionary:
	return {"mesh": MeshKit.sphere_smooth(1.0, rings, segments, color), "transform": Transform3D(basis * Basis.from_scale(radii), pos)}


## merge() part: a smooth cone spike whose base centre is at `base`, pointing along `dir`.
static func spike(color: Color, radius: float, length: float, base: Vector3, dir: Vector3, sides: int = 7) -> Dictionary:
	var d: Vector3 = dir.normalized()
	return {"mesh": MeshKit.cone_smooth(radius, length, sides, color), "transform": Transform3D(aim(d), base + d * (length * 0.5))}


## merge() part from a mesh already in place.
static func part(mesh: ArrayMesh, xf: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	return {"mesh": mesh, "transform": xf}


## Basis whose Y axis points along `dir`.
static func aim(dir: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	if d.dot(Vector3.UP) > 0.9999:
		return Basis.IDENTITY
	if d.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))


## Samples a colour gradient at u in 0..1 (one colour = uniform).
static func gradient(colors: PackedColorArray, u: float) -> Color:
	var n: int = colors.size()
	if n == 0:
		return Color.WHITE
	if n == 1:
		return colors[0]
	var x: float = clampf(u, 0.0, 1.0) * float(n - 1)
	var i: int = mini(int(floorf(x)), n - 2)
	return colors[i].lerp(colors[i + 1], x - float(i))


static func _radius_at(radii: PackedVector2Array, a: int, b: int, pre: int, post: int, t: float) -> Vector2:
	var m: int = radii.size() - 1
	var r: Vector2 = radii[mini(a, m)].cubic_interpolate(radii[mini(b, m)], radii[mini(pre, m)], radii[mini(post, m)], t)
	return Vector2(maxf(r.x, 0.0), maxf(r.y, 0.0))


static func _point_row(p: Vector3, n: int) -> PackedVector3Array:
	var row: PackedVector3Array = PackedVector3Array()
	for i: int in range(n):
		row.append(p)
	return row


## Adds one smooth triangle, wound so its front faces along the vertex normals. Returns the vertices added.
static func _emit(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> int:
	var face: Vector3 = (b - a).cross(c - a)
	if face.length_squared() < 1e-16:
		return 0
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(a)
	if face.dot(na + nb + nc) > 0.0:
		st.set_normal(nc)
		st.set_color(cc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.set_color(cb)
		st.add_vertex(b)
	else:
		st.set_normal(nb)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.set_color(cc)
		st.add_vertex(c)
	return 3


# ---- poses -------------------------------------------------------------------------------------------

static func _canonical(pose: StringName) -> StringName:
	match pose:
		&"walk":
			return &"walk_a"
		&"attack":
			return &"attack_strike"
		&"walk_a", &"walk_b", &"attack_wind", &"attack_strike":
			return pose
		_:
			return &"idle"


static func _style(weapon: StringName) -> Dictionary:
	match weapon:
		&"club":
			return _CLUB
		&"bow":
			return _BOW
		_:
			return _POLEARM


## Bone -> Euler table of a pose for a weapon style. The walk poses are the shared leg cycle over the style's
## carrying arm.
static func _pose_eulers(style: Dictionary, pose: StringName) -> Dictionary:
	match pose:
		&"walk_a":
			var a: Dictionary = _WALK_A.duplicate()
			a.merge(style["carry"] as Dictionary)
			return a
		&"walk_b":
			var b: Dictionary = _WALK_B.duplicate()
			b.merge(style["carry"] as Dictionary)
			return b
		&"attack_wind", &"attack_strike":
			return style[String(pose)] as Dictionary
		_:
			return style["idle"] as Dictionary


## Writes a bone -> Euler table to the skeleton on top of the rest pose, then solves the weapon socket so the
## weapon has its model-space pitch. `bob` lowers the hips (walk cycle).
static func _apply_eulers(skeleton: Skeleton3D, eulers: Dictionary, bob: float) -> void:
	skeleton.reset_bone_poses()
	for bone_key: Variant in eulers:
		var bone: String = bone_key as String
		if bone == "weapon_socket":
			continue
		var idx: int = skeleton.find_bone(bone)
		if idx < 0:
			continue
		var rest: Quaternion = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(idx, rest * Basis.from_euler(eulers[bone] as Vector3).get_rotation_quaternion())
	var hips: int = skeleton.find_bone("hips")
	if hips >= 0 and bob != 0.0:
		skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin + Vector3(0.0, bob, 0.0))
	var socket: int = skeleton.find_bone("weapon_socket")
	var arm: int = skeleton.find_bone("lower_arm_r")
	if socket >= 0 and arm >= 0 and eulers.has("weapon_socket"):
		var want: Basis = Basis.from_euler(eulers["weapon_socket"] as Vector3)
		var parent: Basis = bone_pose_in_model(skeleton, arm).basis.orthonormalized()
		skeleton.set_bone_pose_rotation(socket, (parent.inverse() * want).get_rotation_quaternion())


static func _find_skeleton(root: Node3D) -> Skeleton3D:
	for child: Node in root.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
	return null


# ---- skeleton ----------------------------------------------------------------------------------------

## h = height scale, w = body width scale (torso, limbs), hunch = forward chest tilt (radians).
static func _spec(variant: StringName) -> Dictionary:
	match variant:
		&"archer":
			return {"h": 1.0, "w": 0.82, "hunch": 0.08, "weapon": &"bow", "gold": false, "pauldron": 0.72}
		&"brute":
			return {"h": 0.98, "w": 1.75, "hunch": 0.42, "weapon": &"club", "gold": false, "pauldron": 1.15}
		&"lankini":
			return {"h": 1.15, "w": 0.9, "hunch": 0.0, "weapon": &"trident", "gold": true, "pauldron": 0.95}
		_:
			return {"h": 1.0, "w": 1.0, "hunch": 0.12, "weapon": &"spear", "gold": false, "pauldron": 1.0}


static func _add_bones(skeleton: Skeleton3D, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var hunch: float = spec["hunch"] as float
	var sx: float = 0.25 * w + 0.11
	_add_bone(skeleton, "root", "", Vector3.ZERO, 0.0)
	_add_bone(skeleton, "hips", "root", Vector3(0.0, 0.95 * h, 0.0), 0.0)
	_add_bone(skeleton, "spine", "hips", Vector3(0.0, 0.12 * h, 0.0), -hunch * 0.4)
	_add_bone(skeleton, "chest", "spine", Vector3(0.0, 0.28 * h, 0.0), -hunch * 0.6)
	_add_bone(skeleton, "head", "chest", Vector3(0.0, 0.36 * h, -0.05 * h * (1.0 + hunch)), hunch * 0.75)
	_add_bone(skeleton, "upper_arm_l", "chest", Vector3(sx, 0.2 * h, 0.0), hunch * 0.8)
	_add_bone(skeleton, "lower_arm_l", "upper_arm_l", Vector3(0.0, -0.32 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_arm_r", "chest", Vector3(-sx, 0.2 * h, 0.0), hunch * 0.8)
	_add_bone(skeleton, "lower_arm_r", "upper_arm_r", Vector3(0.0, -0.32 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_l", "hips", Vector3(0.13 * w + 0.05, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_l", "upper_leg_l", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_r", "hips", Vector3(-0.13 * w - 0.05, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_r", "upper_leg_r", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	# The socket rests in the idle carry of the weapon (see _pose_eulers): a canted bow, a trailing club.
	var carry: Vector3 = (_style(spec["weapon"] as StringName)["idle"] as Dictionary)["weapon_socket"] as Vector3
	var socket: int = skeleton.add_bone("weapon_socket")
	skeleton.set_bone_parent(socket, skeleton.find_bone("lower_arm_r"))
	skeleton.set_bone_rest(socket, Transform3D(Basis.from_euler(carry), Vector3(0.0, -0.3 * h, 0.0)))
	skeleton.reset_bone_poses()


static func _add_bone(skeleton: Skeleton3D, bone: String, parent: String, offset: Vector3, pitch: float) -> void:
	var idx: int = skeleton.add_bone(bone)
	if parent != "":
		skeleton.set_bone_parent(idx, skeleton.find_bone(parent))
	skeleton.set_bone_rest(idx, Transform3D(Basis(Vector3.RIGHT, pitch), offset))


# ---- colours -----------------------------------------------------------------------------------------

static func _skin() -> Color:
	return Palette.RAKSHASA_SKIN


static func _skin_dark() -> Color:
	return Palette.RAKSHASA_SKIN.lerp(Palette.NIGHT_INDIGO, 0.55)


static func _skin_light() -> Color:
	return Palette.RAKSHASA_SKIN.lerp(Palette.FIRE_EDGE, 0.16).lightened(0.08)


static func _armor() -> Color:
	return Palette.RAKSHASA_ARMOR


static func _armor_dark() -> Color:
	return Palette.RAKSHASA_ARMOR.lerp(Palette.NIGHT_INDIGO, 0.5)


static func _bronze() -> Color:
	return Palette.GOLD.lerp(Palette.RAKSHASA_ARMOR, 0.5).darkened(0.38)


static func _ivory() -> Color:
	return Palette.MOON.lerp(Palette.STONE, 0.55)


static func _horn_dark() -> Color:
	return Palette.NIGHT_INDIGO.lerp(Palette.BARK, 0.35)


static func _cloth() -> Color:
	return Palette.RAKSHASA_ARMOR.lerp(Palette.SINDOOR, 0.45)


static func _cloth_dark() -> Color:
	return Palette.RAKSHASA_ARMOR.lerp(Palette.NIGHT_INDIGO, 0.35)


# ---- mesh assembly -----------------------------------------------------------------------------------

## Bone name -> ArrayMesh for a variant (cached: every model of a variant shares its meshes).
static func _meshes_for(variant: StringName, spec: Dictionary) -> Dictionary:
	if _mesh_cache.has(variant):
		return _mesh_cache[variant] as Dictionary
	var b: Dictionary = {}
	_build_torso(b, variant, spec)
	_build_head(b, variant, spec)
	_build_arms(b, variant, spec)
	_build_legs(b, variant, spec)
	_build_weapon(b, variant, spec)
	var out: Dictionary = {}
	for bone_key: Variant in b:
		var kinds: Dictionary = (b[bone_key] as Dictionary).duplicate()
		var glow: Array = kinds.get(&"glow", []) as Array
		kinds.erase(&"glow")
		var mesh: ArrayMesh = MeshKit.multi(kinds)
		if not glow.is_empty():
			var typed: Array[Dictionary] = []
			for g: Variant in glow:
				typed.append(g as Dictionary)
			var glow_mesh: ArrayMesh = MeshKit.merge(typed)
			var index: int = mesh.get_surface_count()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, glow_mesh.surface_get_arrays(0))
			mesh.surface_set_name(index, GLOW_SURFACE)
			mesh.surface_set_material(index, glow_material())
		out[bone_key] = mesh
	_mesh_cache[variant] = out
	return out


static func _put(b: Dictionary, bone: String, kind: StringName, piece: Dictionary) -> void:
	if not b.has(bone):
		b[bone] = {}
	var kinds: Dictionary = b[bone] as Dictionary
	if not kinds.has(kind):
		kinds[kind] = []
	(kinds[kind] as Array).append(piece)


static func _v3(points: Array[Vector3]) -> PackedVector3Array:
	return PackedVector3Array(points)


static func _v2(points: Array[Vector2]) -> PackedVector2Array:
	return PackedVector2Array(points)


static func _c(colors: Array[Color]) -> PackedColorArray:
	return PackedColorArray(colors)


## Upright tube part: `stations` are Vector3(y, x half-width, z half-depth); `z_offsets` shifts each station in Z.
static func _column(stations: Array[Vector3], colors: Array[Color], sides: int = 9, subdiv: int = 2, z_offsets: Array[float] = []) -> Dictionary:
	var pts: PackedVector3Array = PackedVector3Array()
	var rad: PackedVector2Array = PackedVector2Array()
	for i: int in range(stations.size()):
		var s: Vector3 = stations[i]
		pts.append(Vector3(0.0, s.x, z_offsets[i] if i < z_offsets.size() else 0.0))
		rad.append(Vector2(s.y, s.z))
	return part(tube(pts, rad, sides, PackedColorArray(colors), subdiv))


static func _build_torso(b: Dictionary, variant: StringName, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var gold_plate: bool = spec["gold"] as bool
	var skin: Color = _skin()
	var metal: Color = Palette.GOLD if gold_plate else _bronze()
	var gold: Color = Palette.GOLD
	var lacq: StringName = &"lacquer_local"

	# Hips: pelvis, a heavy belt with a boss, tassets over the thighs, loincloth front and back.
	_put(b, "hips", &"skin", ellipsoid(skin, Vector3(0.25 * w, 0.17 * h, 0.19 * w), Vector3(0.0, -0.02 * h, 0.0)))
	_put(b, "hips", &"gold", _column([Vector3(0.04 * h, 0.265 * w, 0.21 * w), Vector3(0.135 * h, 0.255 * w, 0.2 * w)], [metal], 14, 1))
	_put(b, "hips", &"gold", part(ring(Vector3(0.0, 0.04 * h, 0.0), Vector3(0.27 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.215 * w), 0.014 * h, 14, 3, gold)))
	_put(b, "hips", &"gold", part(ring(Vector3(0.0, 0.135 * h, 0.0), Vector3(0.26 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.205 * w), 0.014 * h, 14, 3, gold)))
	_put(b, "hips", &"gold", ellipsoid(gold, Vector3(0.075 * h, 0.075 * h, 0.035 * h), Vector3(0.0, 0.085 * h, -0.21 * w), Basis.IDENTITY, 4, 8))
	_put(b, "hips", lacq, ellipsoid(Palette.SINDOOR, Vector3(0.035 * h, 0.035 * h, 0.03 * h), Vector3(0.0, 0.085 * h, -0.21 * w - 0.02 * h), Basis.IDENTITY, 4, 8))
	for sgn: float in [-1.0, 1.0]:
		var tilt: Basis = Basis(Vector3.BACK, sgn * 0.22)
		_put(b, "hips", lacq, ellipsoid(_armor(), Vector3(0.05 * w + 0.03, 0.15 * h, 0.12 * w + 0.03), Vector3(sgn * (0.24 * w + 0.07), -0.08 * h, 0.0), tilt, 5, 7))
		_put(b, "hips", &"gold", ellipsoid(gold, Vector3(0.04 * w + 0.03, 0.05 * h, 0.1 * w + 0.03), Vector3(sgn * (0.265 * w + 0.08), -0.19 * h, 0.0), tilt, 4, 6))
	var cloth_grad: PackedColorArray = _c([_cloth(), _cloth(), _cloth_dark(), gold])
	var front_len: float = (0.62 if variant == &"lankini" else 0.44) * h
	_put(b, "hips", &"cloth", part(cloth_panel(Vector3(0.0, 0.05 * h, -0.2 * w - 0.01), Vector3.RIGHT, front_len, 0.24 * w + 0.04, 0.2 * w + 0.03, Vector3(0.0, 0.0, -0.05 * h), 0.04 * w, cloth_grad, 0.8)))
	_put(b, "hips", &"cloth", part(cloth_panel(Vector3(0.0, 0.05 * h, 0.19 * w + 0.01), Vector3.RIGHT, front_len * 1.12, 0.3 * w + 0.04, 0.3 * w + 0.03, Vector3(0.0, 0.0, 0.06 * h), 0.05 * w, cloth_grad, 0.9)))

	# Abdomen with a cloth sash.
	_put(b, "spine", &"skin", _column([
		Vector3(-0.1 * h, 0.235 * w, 0.175 * w), Vector3(0.06 * h, 0.215 * w, 0.16 * w),
		Vector3(0.2 * h, 0.25 * w, 0.18 * w), Vector3(0.32 * h, 0.27 * w, 0.18 * w)], [skin], 10, 2))
	_put(b, "spine", &"cloth", _column([Vector3(-0.015 * h, 0.245 * w, 0.185 * w), Vector3(0.075 * h, 0.228 * w, 0.172 * w)], [Color(_cloth(), 0.0)], 12, 1))
	if variant == &"brute":
		_put(b, "spine", &"skin", ellipsoid(skin, Vector3(0.2 * w, 0.16 * h, 0.12 * w), Vector3(0.0, 0.08 * h, -0.075 * w)))

	# Ribcage, pectorals, trapezius, neck.
	_put(b, "chest", &"skin", _column([
		Vector3(-0.09 * h, 0.25 * w, 0.175 * w), Vector3(0.04 * h, 0.31 * w, 0.205 * w),
		Vector3(0.15 * h, 0.33 * w, 0.2 * w), Vector3(0.24 * h, 0.25 * w, 0.16 * w),
		Vector3(0.3 * h, 0.1 * w + 0.02, 0.1 * w + 0.02)], [skin], 10, 2))
	for sgn2: float in [-1.0, 1.0]:
		_put(b, "chest", &"skin", ellipsoid(skin, Vector3(0.17 * w, 0.08 * h, 0.055 * w), Vector3(sgn2 * 0.15 * w, 0.135 * h, -0.14 * w), Basis(Vector3.BACK, sgn2 * 0.2)))
		_put(b, "chest", &"skin", ellipsoid(skin, Vector3(0.2 * w, 0.075 * h, 0.12 * w), Vector3(sgn2 * 0.16 * w, 0.245 * h, 0.03 * w), Basis(Vector3.BACK, -sgn2 * 0.35)))
	var neck_r: float = 0.085 * h * (0.75 + 0.25 * w)
	_put(b, "chest", &"skin", part(tube(_v3([Vector3(0.0, 0.22 * h, 0.0), Vector3(0.0, 0.38 * h, -0.05 * h)]), _v2([Vector2(neck_r * 1.25, neck_r * 1.2), Vector2(neck_r, neck_r)]), 10, _c([skin]), 2)))

	match variant:
		&"brute":
			# Fur mantle over the hunched back, a spiked bronze yoke, crossed straps with a boss.
			_put(b, "chest", &"fur", ellipsoid(_horn_dark().darkened(0.25), Vector3(0.3 * w, 0.13 * h, 0.17 * w), Vector3(0.0, 0.2 * h, 0.1 * w), Basis(Vector3.RIGHT, 0.35), 6, 10))
			_put(b, "chest", &"fur", ellipsoid(_horn_dark().darkened(0.1), Vector3(0.27 * w, 0.13 * h, 0.15 * w), Vector3(0.0, 0.06 * h, 0.12 * w), Basis(Vector3.RIGHT, 0.2), 6, 10))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, 0.27 * h, 0.0), Vector3(0.17 * w, 0.0, 0.0), Vector3(0.0, 0.03 * h, 0.14 * w), 0.035 * h, 10, 5, metal)))
			for i: int in range(7):
				var a: float = TAU * (float(i) + 0.5) / 7.0
				var dir: Vector3 = Vector3(cos(a), 0.45, sin(a) * 0.9)
				_put(b, "chest", &"gold", spike(metal, 0.03 * h, 0.13 * h, Vector3(cos(a) * 0.17 * w, 0.275 * h + sin(a) * 0.03 * h, sin(a) * 0.14 * w), dir, 6))
			for sgn3: float in [-1.0, 1.0]:
				_put(b, "chest", lacq, part(ring(Vector3(0.0, 0.1 * h, 0.0), Vector3(0.325 * w, sgn3 * 0.17 * h, 0.0), Vector3(0.0, 0.0, 0.215 * w), 0.022 * h, 12, 4, _armor_dark())))
			_put(b, "chest", &"gold", ellipsoid(metal, Vector3(0.08 * h, 0.08 * h, 0.035 * h), Vector3(0.0, 0.1 * h, -0.215 * w), Basis.IDENTITY, 5, 10))
			_put(b, "chest", &"gold", spike(metal, 0.03 * h, 0.09 * h, Vector3(0.0, 0.1 * h, -0.215 * w - 0.02 * h), Vector3.FORWARD, 6))
		&"archer":
			# Bandolier, gold torque, and the quiver across the back with fletched arrows.
			_put(b, "chest", lacq, part(ring(Vector3(0.0, 0.08 * h, 0.0), Vector3(0.315 * w, 0.2 * h, 0.0), Vector3(0.0, 0.0, 0.215 * w), 0.024 * h, 12, 4, _armor())))
			_put(b, "chest", &"gold", ellipsoid(gold, Vector3(0.045 * h, 0.045 * h, 0.025 * h), Vector3(-0.04 * w, 0.055 * h, -0.21 * w), Basis.IDENTITY, 4, 8))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, 0.265 * h, -0.01), Vector3(0.14 * w, 0.0, 0.0), Vector3(0.0, -0.04 * h, 0.13 * w), 0.016 * h, 12, 5, gold)))
			var qb: Basis = Basis(Vector3.BACK, 0.42) * Basis(Vector3.RIGHT, 0.12)
			var qc: Vector3 = Vector3(0.03 * h, 0.1 * h, 0.2 * w + 0.07 * h)
			_put(b, "chest", lacq, part(tube(_v3([qc - qb.y * 0.3 * h, qc + qb.y * 0.26 * h]), _v2([Vector2(0.055 * h, 0.05 * h), Vector2(0.075 * h, 0.065 * h)]), 9, _c([_armor_dark(), _armor()]), 2)))
			_put(b, "chest", &"gold", part(ring(qc + qb.y * 0.26 * h, qb.x * 0.078 * h, qb.z * 0.068 * h, 0.012 * h, 10, 5, gold)))
			_put(b, "chest", &"gold", part(ring(qc - qb.y * 0.05 * h, qb.x * 0.07 * h, qb.z * 0.062 * h, 0.01 * h, 10, 5, gold)))
			for k: int in range(4):
				var off: Vector3 = qb.x * (0.03 * h * (float(k) - 1.5)) + qb.z * (0.015 * h * float(k % 2))
				var tipb: Vector3 = qc + qb.y * 0.26 * h + off
				_put(b, "chest", &"wood_local", part(tube(_v3([tipb, tipb + qb.y * 0.2 * h]), _v2([Vector2(0.007 * h, 0.007 * h)]), 4, _c([Palette.BARK]))))
				_put(b, "chest", &"cloth", part(tube(_v3([tipb + qb.y * 0.1 * h, tipb + qb.y * 0.15 * h, tipb + qb.y * 0.21 * h]), _v2([Vector2(0.004, 0.004), Vector2(0.026 * h, 0.006), Vector2(0.012 * h, 0.004)]), 4, _c([Color(Palette.SINDOOR, 0.0)]), 1, qb.z)))
		&"lankini":
			# Antique gold cuirass with a sun medallion, a jewelled collar and a long crimson stole.
			var plate: Color = gold.lerp(_bronze(), 0.45)
			_put(b, "chest", &"gold", _column([
				Vector3(-0.1 * h, 0.262 * w, 0.187 * w), Vector3(0.04 * h, 0.325 * w, 0.22 * w),
				Vector3(0.15 * h, 0.345 * w, 0.215 * w), Vector3(0.2 * h, 0.31 * w, 0.19 * w)], [plate], 10, 2))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, 0.2 * h, 0.0), Vector3(0.312 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.192 * w), 0.016 * h, 12, 4, gold)))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, -0.1 * h, 0.0), Vector3(0.264 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.189 * w), 0.014 * h, 12, 4, gold)))
			_put(b, "chest", &"gold", ellipsoid(gold, Vector3(0.09 * h, 0.09 * h, 0.03 * h), Vector3(0.0, 0.05 * h, -0.225 * w), Basis.IDENTITY, 5, 10))
			for i4: int in range(10):
				var a4: float = TAU * float(i4) / 10.0
				_put(b, "chest", &"gold", spike(gold, 0.016 * h, 0.06 * h, Vector3(cos(a4) * 0.08 * h, 0.05 * h + sin(a4) * 0.08 * h, -0.225 * w - 0.005), Vector3(cos(a4), sin(a4), -0.25), 4))
			_put(b, "chest", lacq, ellipsoid(Palette.SINDOOR, Vector3(0.036 * h, 0.036 * h, 0.03 * h), Vector3(0.0, 0.05 * h, -0.225 * w - 0.018 * h), Basis.IDENTITY, 4, 8))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, 0.245 * h, -0.01), Vector3(0.2 * w, 0.0, 0.0), Vector3(0.0, -0.05 * h, 0.16 * w), 0.028 * h, 10, 5, gold)))
			_put(b, "chest", lacq, ellipsoid(Palette.SINDOOR, Vector3(0.04 * h, 0.05 * h, 0.03 * h), Vector3(0.0, 0.2 * h, -0.2 * w), Basis.IDENTITY, 4, 8))
			_put(b, "chest", &"cloth", part(cloth_panel(Vector3(0.0, 0.2 * h, 0.2 * w + 0.02), Vector3.RIGHT, 0.95 * h, 0.5 * w, 0.62 * w, Vector3(0.0, 0.0, 0.1 * h), 0.08 * w, _c([_cloth_dark(), _cloth(), _cloth(), gold]), 1.0, 8, 6)))
		_:
			# The guard: bronze cuirass with gold rims and a sun medallion, a gorget, a short crimson cape.
			_put(b, "chest", &"gold", _column([
				Vector3(-0.1 * h, 0.262 * w, 0.187 * w), Vector3(0.04 * h, 0.325 * w, 0.22 * w),
				Vector3(0.16 * h, 0.345 * w, 0.215 * w)], [metal], 10, 2))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, 0.16 * h, 0.0), Vector3(0.347 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.218 * w), 0.016 * h, 12, 4, gold)))
			_put(b, "chest", &"gold", part(ring(Vector3(0.0, -0.09 * h, 0.0), Vector3(0.268 * w, 0.0, 0.0), Vector3(0.0, 0.0, 0.192 * w), 0.014 * h, 12, 4, gold)))
			_put(b, "chest", &"gold", ellipsoid(gold, Vector3(0.075 * h, 0.075 * h, 0.03 * h), Vector3(0.0, 0.06 * h, -0.222 * w), Basis.IDENTITY, 5, 10))
			_put(b, "chest", lacq, ellipsoid(Palette.SINDOOR, Vector3(0.032 * h, 0.032 * h, 0.03 * h), Vector3(0.0, 0.06 * h, -0.222 * w - 0.015 * h), Basis.IDENTITY, 4, 8))
			for i2: int in range(8):
				var a2: float = TAU * float(i2) / 8.0
				_put(b, "chest", &"gold", spike(gold, 0.014 * h, 0.05 * h, Vector3(cos(a2) * 0.065 * h, 0.06 * h + sin(a2) * 0.065 * h, -0.222 * w - 0.005), Vector3(cos(a2), sin(a2), -0.25), 4))
			_put(b, "chest", lacq, part(ring(Vector3(0.0, 0.25 * h, -0.005), Vector3(0.19 * w, 0.0, 0.0), Vector3(0.0, -0.04 * h, 0.15 * w), 0.03 * h, 10, 5, _armor())))
			_put(b, "chest", &"cloth", part(cloth_panel(Vector3(0.0, 0.22 * h, 0.19 * w + 0.03), Vector3.RIGHT, 0.62 * h, 0.52 * w, 0.66 * w, Vector3(0.0, 0.0, 0.1 * h), 0.09 * w, _c([_cloth_dark(), _cloth(), _cloth(), gold]), 1.0, 7, 6)))


static func _build_head(b: Dictionary, variant: StringName, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var skin: Color = _skin()
	var dark: Color = _skin_dark()
	var gold: Color = Palette.GOLD
	var ivory: Color = _ivory()
	var lacq: StringName = &"lacquer_local"
	var hr: float = 0.16 * h * (0.72 + 0.28 * w)
	var c: Vector3 = Vector3(0.0, 0.085 * h, 0.0)
	var jaw: float = 1.3 if variant == &"brute" else (0.92 if variant == &"lankini" else 1.08)

	# Skull, heavy underslung jaw, muzzle, nose, brow ridge, cheekbones.
	_put(b, "head", &"skin", ellipsoid(skin, Vector3(hr * 0.9, hr, hr * 0.98), c, Basis.IDENTITY, 7, 10))
	_put(b, "head", &"skin", ellipsoid(skin, Vector3(hr * 0.86 * jaw, hr * 0.46 * jaw, hr * 0.74), c + Vector3(0.0, -hr * 0.62, -hr * 0.42), Basis(Vector3.RIGHT, 0.15), 5, 8))
	_put(b, "head", &"skin", ellipsoid(skin, Vector3(hr * 0.42, hr * 0.3, hr * 0.36), c + Vector3(0.0, -hr * 0.16, -hr * 0.74), Basis(Vector3.RIGHT, -0.35), 5, 8))
	_put(b, "head", &"skin", ellipsoid(dark, Vector3(hr * 0.24, hr * 0.09, hr * 0.12), c + Vector3(0.0, -hr * 0.2, -hr * 1.04), Basis.IDENTITY, 4, 6))
	_put(b, "head", &"skin", ellipsoid(dark, Vector3(hr * 0.5, hr * 0.1, hr * 0.2), c + Vector3(0.0, -hr * 0.62, -hr * 0.98), Basis.IDENTITY, 4, 8))
	for sgn: float in [-1.0, 1.0]:
		_put(b, "head", &"skin", ellipsoid(skin, Vector3(hr * 0.26, hr * 0.2, hr * 0.3), c + Vector3(sgn * hr * 0.58, -hr * 0.12, -hr * 0.6), Basis.IDENTITY, 4, 6))
		# Heavy brow ridges, drawn down toward the nose in a scowl.
		_put(b, "head", &"skin", ellipsoid(dark, Vector3(hr * 0.52, hr * 0.17, hr * 0.36), c + Vector3(sgn * hr * 0.4, hr * 0.3, -hr * 0.72), Basis(Vector3.BACK, sgn * 0.42) * Basis(Vector3.RIGHT, 0.3), 4, 7))
		# Glowing slanted eyes under the brow.
		_put(b, "head", &"glow", ellipsoid(Palette.FIRE_CORE, Vector3(hr * 0.2, hr * 0.075, hr * 0.1), c + Vector3(sgn * hr * 0.42, hr * 0.1, -hr * 0.84), Basis(Vector3.BACK, sgn * 0.42), 3, 6))
		# Tusks curving up from the corners of the jaw, and upper fangs.
		var t0: Vector3 = c + Vector3(sgn * hr * 0.5 * jaw, -hr * 0.6, -hr * 0.9)
		_put(b, "head", &"skin", part(tube(_v3([t0, t0 + Vector3(sgn * hr * 0.22, hr * 0.3, -hr * 0.2) * jaw, t0 + Vector3(sgn * hr * 0.26, hr * 0.9, -hr * 0.1) * jaw]), _v2([Vector2(hr * 0.14, hr * 0.14) * jaw, Vector2(hr * 0.11, hr * 0.11) * jaw, Vector2.ZERO]), 5, _c([ivory]), 2)))
		_put(b, "head", &"skin", spike(ivory, hr * 0.05, hr * 0.2, c + Vector3(sgn * hr * 0.2, -hr * 0.3, -hr * 1.05), Vector3(0.0, -1.0, -0.15), 5))
		# Pointed ears with a gold ring.
		_put(b, "head", &"skin", {"mesh": MeshKit.cone_smooth(hr * 0.22, hr * 0.85, 6, dark), "transform": Transform3D(aim(Vector3(sgn * 0.85, 0.5, 0.35)) * Basis.from_scale(Vector3(0.45, 1.0, 1.0)), c + Vector3(sgn * hr * 1.12, hr * 0.22, hr * 0.2))})
		_put(b, "head", &"gold", part(ring(c + Vector3(sgn * hr * 0.95, -hr * 0.28, hr * 0.08), Vector3(0.0, hr * 0.14, 0.0), Vector3(0.0, 0.0, hr * 0.14), hr * 0.035, 8, 3, gold)))
		_put(b, "head", &"skin", part(_horn(variant, sgn, hr, c)))
		if variant == &"spear" or variant == &"lankini":
			var hb: Vector3 = _horn_points(variant, sgn, hr, c)[0]
			var hd: Vector3 = (_horn_points(variant, sgn, hr, c)[1] - hb).normalized()
			var hu: Vector3 = hd.cross(Vector3.BACK).normalized()
			_put(b, "head", &"gold", part(ring(hb + hd * hr * 0.28, hu * hr * 0.25, hd.cross(hu) * hr * 0.25, hr * 0.05, 8, 3, gold)))

	match variant:
		&"brute":
			# Bare scarred head: a nose ring, a ridge of bony knobs.
			_put(b, "head", &"gold", part(ring(c + Vector3(0.0, -hr * 0.28, -hr * 1.2), Vector3(hr * 0.16, 0.0, 0.0), Vector3(0.0, hr * 0.16, 0.0), hr * 0.035, 10, 3, gold)))
			for i: int in range(4):
				var a: float = -0.5 + 0.55 * float(i)
				_put(b, "head", &"skin", spike(_horn_dark(), hr * 0.13, hr * 0.3, c + Vector3(0.0, cos(a) * hr * 0.92, sin(a) * hr * 0.9), Vector3(0.0, cos(a), sin(a)), 6))
		&"archer":
			# Cloth head-wrap with a gold circlet and a tail streaming behind.
			_put(b, "head", &"cloth", ellipsoid(Color(_cloth(), 0.0), Vector3(hr * 0.96, hr * 0.72, hr * 1.04), c + Vector3(0.0, hr * 0.42, hr * 0.06), Basis(Vector3.RIGHT, -0.12), 6, 10))
			_put(b, "head", &"gold", part(ring(c + Vector3(0.0, hr * 0.42, 0.0), Vector3(hr * 0.93, 0.0, 0.0), Vector3(0.0, -hr * 0.14, hr * 0.98), hr * 0.05, 10, 3, gold)))
			_put(b, "head", lacq, ellipsoid(Palette.SINDOOR, Vector3(hr * 0.1, hr * 0.13, hr * 0.06), c + Vector3(0.0, hr * 0.58, -hr * 0.96), Basis.IDENTITY, 4, 6))
			_put(b, "head", &"cloth", part(cloth_panel(c + Vector3(0.0, hr * 0.5, hr * 1.0), Vector3.RIGHT, 0.5 * h, hr * 0.5, hr * 0.8, Vector3(0.0, 0.0, 0.07 * h), 0.02, _c([_cloth(), _cloth(), _cloth_dark()]), 1.0, 6, 4)))
		&"lankini":
			# Tiered gold crown with a ring of points and a brow jewel, heavy earrings, long hair down the back.
			var base: float = c.y + hr * 0.62
			_put(b, "head", &"gold", _column([
				Vector3(base - hr * 0.2, hr * 0.86, hr * 0.92), Vector3(base + hr * 0.1, hr * 0.84, hr * 0.88),
				Vector3(base + hr * 0.3, hr * 0.62, hr * 0.64), Vector3(base + hr * 0.5, hr * 0.66, hr * 0.68),
				Vector3(base + hr * 0.8, hr * 0.42, hr * 0.44), Vector3(base + hr * 1.0, hr * 0.46, hr * 0.48),
				Vector3(base + hr * 1.3, hr * 0.2, hr * 0.2), Vector3(base + hr * 1.5, hr * 0.24, hr * 0.24),
				Vector3(base + hr * 1.85, 0.0, 0.0)], [gold], 9, 1))
			for i2: int in range(8):
				var a2: float = TAU * float(i2) / 8.0
				_put(b, "head", &"gold", spike(gold, hr * 0.1, hr * 0.42, Vector3(sin(a2) * hr * 0.82, base + hr * 0.1, cos(a2) * hr * 0.86), Vector3(sin(a2) * 0.35, 1.0, cos(a2) * 0.35), 5))
			_put(b, "head", lacq, ellipsoid(Palette.SINDOOR, Vector3(hr * 0.13, hr * 0.17, hr * 0.08), Vector3(0.0, base - hr * 0.02, -hr * 0.9), Basis.IDENTITY, 4, 8))
			for sgn2: float in [-1.0, 1.0]:
				_put(b, "head", &"gold", ellipsoid(gold, Vector3(hr * 0.13, hr * 0.2, hr * 0.13), c + Vector3(sgn2 * hr * 0.95, -hr * 0.5, hr * 0.08), Basis.IDENTITY, 5, 7))
			var hair: Color = Palette.NIGHT_INDIGO.lerp(Palette.RAKSHASA_SKIN, 0.2)
			_put(b, "head", &"fur", part(tube(_v3([c + Vector3(0.0, hr * 0.5, hr * 0.6), c + Vector3(0.0, -hr * 0.2, hr * 1.05), c + Vector3(0.0, -hr * 1.6, hr * 1.25), c + Vector3(0.0, -hr * 3.2, hr * 1.5)]), _v2([Vector2(hr * 0.75, hr * 0.4), Vector2(hr * 0.85, hr * 0.42), Vector2(hr * 0.7, hr * 0.3), Vector2(hr * 0.1, hr * 0.05)]), 8, _c([hair, hair, hair.lightened(0.12)]), 3)))
		_:
			# Bronze helm: dome, gold brim, nasal bar, cheek guards, and a crimson crest in a gold holder.
			var metal: Color = _bronze()
			_put(b, "head", &"gold", ellipsoid(metal, Vector3(hr * 0.97, hr * 0.74, hr * 1.05), c + Vector3(0.0, hr * 0.4, hr * 0.04), Basis(Vector3.RIGHT, -0.1), 6, 10))
			_put(b, "head", &"gold", part(ring(c + Vector3(0.0, hr * 0.4, 0.02), Vector3(hr * 0.95, 0.0, 0.0), Vector3(0.0, -hr * 0.12, hr * 1.02), hr * 0.055, 10, 3, gold)))
			_put(b, "head", &"gold", part(tube(_v3([c + Vector3(0.0, hr * 0.6, -hr * 0.95), c + Vector3(0.0, hr * 0.1, -hr * 1.08), c + Vector3(0.0, -hr * 0.12, -hr * 1.14)]), _v2([Vector2(hr * 0.1, hr * 0.05), Vector2(hr * 0.07, hr * 0.04), Vector2(hr * 0.03, hr * 0.02)]), 5, _c([gold]), 2, Vector3.FORWARD)))
			for sgn3: float in [-1.0, 1.0]:
				_put(b, "head", &"gold", ellipsoid(metal, Vector3(hr * 0.1, hr * 0.42, hr * 0.34), c + Vector3(sgn3 * hr * 0.86, -hr * 0.1, -hr * 0.12), Basis(Vector3.BACK, sgn3 * 0.12), 5, 8))
			_put(b, "head", &"gold", part(tube(_v3([c + Vector3(0.0, hr * 0.85, -hr * 0.8), c + Vector3(0.0, hr * 1.2, 0.0), c + Vector3(0.0, hr * 0.8, hr * 0.95)]), _v2([Vector2(hr * 0.07, hr * 0.06)]), 5, _c([gold]), 3, Vector3.UP)))
			var plume: Array[Vector3] = []
			var plume_r: Array[Vector2] = []
			for i3: int in range(6):
				var u: float = float(i3) / 5.0
				var ang: float = lerpf(-0.8, 1.5, u)
				var rr: float = hr * (1.3 + 0.28 * sin(u * PI) + 0.5 * u * u)
				plume.append(c + Vector3(0.0, hr * 0.12 + cos(ang) * rr, sin(ang) * rr))
				plume_r.append(Vector2(hr * 0.13, hr * (0.12 + 0.3 * sin(minf(u * 1.3, 1.0) * PI))))
			_put(b, "head", &"cloth", part(tube(PackedVector3Array(plume), PackedVector2Array(plume_r), 6, _c([Color(_cloth(), 0.0), Color(Palette.SINDOOR, 0.25), Color(Palette.SINDOOR, 0.9)]), 2, Vector3.UP)))


static func _horn_points(variant: StringName, sgn: float, hr: float, c: Vector3) -> Array[Vector3]:
	var raw: Array[Vector3] = []
	match variant:
		&"archer":
			raw = [Vector3(0.52, 0.62, 0.25), Vector3(0.8, 0.98, 0.6), Vector3(0.86, 1.22, 1.1), Vector3(0.7, 1.3, 1.6)]
		&"brute":
			raw = [Vector3(0.62, 0.5, 0.05), Vector3(1.35, 0.55, -0.05), Vector3(1.85, 0.95, -0.35), Vector3(1.75, 1.6, -0.7)]
		&"lankini":
			raw = [Vector3(0.6, 0.45, 0.25), Vector3(1.25, 0.9, 0.35), Vector3(1.2, 1.75, 0.3), Vector3(1.55, 2.5, 0.2)]
		_:
			raw = [Vector3(0.6, 0.55, 0.1), Vector3(1.15, 0.95, 0.25), Vector3(1.3, 1.65, 0.05), Vector3(1.0, 2.3, -0.4)]
	var out: Array[Vector3] = []
	for p: Vector3 in raw:
		out.append(c + Vector3(p.x * sgn, p.y, p.z) * hr)
	return out


static func _horn(variant: StringName, sgn: float, hr: float, c: Vector3) -> ArrayMesh:
	var thick: float = hr * (0.34 if variant == &"brute" else (0.2 if variant == &"archer" else 0.24))
	var radii: PackedVector2Array = _v2([Vector2(thick, thick), Vector2(thick * 0.82, thick * 0.82), Vector2(thick * 0.5, thick * 0.5), Vector2.ZERO])
	return tube(PackedVector3Array(_horn_points(variant, sgn, hr, c)), radii, 6, _c([_horn_dark(), _horn_dark(), _horn_dark().lerp(_ivory(), 0.55), _ivory()]), 2)


static func _build_arms(b: Dictionary, variant: StringName, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var pauld: float = spec["pauldron"] as float
	var gold_plate: bool = spec["gold"] as bool
	var skin: Color = _skin()
	var gold: Color = Palette.GOLD
	var metal: Color = gold.lerp(_bronze(), 0.45) if gold_plate else _bronze()
	var lacq: StringName = &"lacquer_local"
	var ar: float = 0.075 * h * w * 0.9 + 0.022
	for side: String in ["l", "r"]:
		var sgn: float = 1.0 if side == "l" else -1.0
		var up: String = "upper_arm_" + side
		var lo: String = "lower_arm_" + side
		# Deltoid, biceps and triceps.
		_put(b, up, &"skin", ellipsoid(skin, Vector3(ar * 1.45, ar * 1.5, ar * 1.5), Vector3(sgn * ar * 0.1, -0.015 * h, 0.0)))
		_put(b, up, &"skin", _column([
			Vector3(0.0, ar * 1.1, ar * 1.2), Vector3(-0.12 * h, ar * 1.22, ar * 1.38),
			Vector3(-0.24 * h, ar * 0.98, ar * 1.05), Vector3(-0.32 * h, ar * 0.9, ar * 0.92)], [skin], 8, 2))
		# Layered pauldron: lacquer dome, a lower lame, gold rim, spikes.
		var ps: float = h * pauld
		var dome: Color = gold.lerp(_bronze(), 0.3) if gold_plate else _armor().darkened(0.12)
		var dome_kind: StringName = &"gold" if gold_plate else lacq
		var tilt: Basis = Basis(Vector3.BACK, -sgn * 0.5)
		var pc: Vector3 = Vector3(sgn * 0.035 * ps, 0.045 * ps, 0.0)
		_put(b, up, dome_kind, ellipsoid(dome, Vector3(0.175 * ps, 0.095 * ps, 0.18 * ps), pc, tilt, 6, 10))
		_put(b, up, &"gold", ellipsoid(gold, Vector3(0.192 * ps, 0.024 * ps, 0.198 * ps), pc + tilt * Vector3(0.0, -0.034 * ps, 0.0), tilt, 4, 10))
		_put(b, up, dome_kind, ellipsoid(dome.darkened(0.2), Vector3(0.15 * ps, 0.085 * ps, 0.165 * ps), pc + tilt * Vector3(0.0, -0.085 * ps, 0.0), tilt, 5, 10))
		_put(b, up, &"gold", ellipsoid(gold, Vector3(0.164 * ps, 0.02 * ps, 0.178 * ps), pc + tilt * Vector3(0.0, -0.125 * ps, 0.0), tilt, 4, 10))
		match variant:
			&"brute":
				for i: int in range(3):
					var a: float = (float(i) - 1.0) * 0.85
					var d: Vector3 = tilt * Vector3(0.0, cos(a) * 0.9, sin(a)).normalized()
					_put(b, up, &"gold", spike(metal, 0.05 * ps, 0.23 * ps, pc + d * 0.1 * ps, d, 7))
			&"lankini":
				var wing: Vector3 = tilt * Vector3(0.0, 1.0, 0.0)
				_put(b, up, &"gold", part(tube(_v3([pc + wing * 0.08 * ps, pc + wing * 0.2 * ps + Vector3(sgn * 0.09 * ps, 0.03 * ps, 0.0), pc + wing * 0.27 * ps + Vector3(sgn * 0.13 * ps, 0.16 * ps, 0.0)]), _v2([Vector2(0.03 * ps, 0.11 * ps), Vector2(0.022 * ps, 0.07 * ps), Vector2.ZERO]), 6, _c([gold]), 3)))
			&"archer":
				_put(b, up, &"gold", spike(metal, 0.035 * ps, 0.1 * ps, pc + tilt * Vector3(0.0, 0.1 * ps, 0.0), tilt * Vector3.UP, 6))
			_:
				var d0: Vector3 = tilt * Vector3.UP
				_put(b, up, &"gold", spike(metal, 0.045 * ps, 0.2 * ps, pc + d0 * 0.1 * ps, d0, 7))
				for sz: float in [-1.0, 1.0]:
					var d1: Vector3 = tilt * Vector3(0.0, 0.75, sz * 0.7).normalized()
					_put(b, up, &"gold", spike(metal, 0.03 * ps, 0.11 * ps, pc + d1 * 0.115 * ps, d1, 6))
		# Elbow, forearm, bracer with gold rims, fist.
		_put(b, lo, &"skin", ellipsoid(skin, Vector3(ar * 1.0, ar * 1.05, ar * 1.1), Vector3.ZERO, Basis.IDENTITY, 4, 6))
		_put(b, lo, &"skin", _column([
			Vector3(0.0, ar * 0.95, ar * 1.0), Vector3(-0.08 * h, ar * 1.18, ar * 1.22),
			Vector3(-0.2 * h, ar * 0.9, ar * 0.95), Vector3(-0.3 * h, ar * 0.72, ar * 0.78)], [skin], 8, 2))
		_put(b, lo, &"gold", _column([
			Vector3(-0.1 * h, ar * 1.3, ar * 1.34), Vector3(-0.18 * h, ar * 1.12, ar * 1.16),
			Vector3(-0.265 * h, ar * 0.95, ar * 1.0)], [metal], 8, 1))
		_put(b, lo, &"gold", part(ring(Vector3(0.0, -0.1 * h, 0.0), Vector3(ar * 1.32, 0.0, 0.0), Vector3(0.0, 0.0, ar * 1.36), ar * 0.14, 10, 3, gold)))
		_put(b, lo, &"gold", part(ring(Vector3(0.0, -0.265 * h, 0.0), Vector3(ar * 0.97, 0.0, 0.0), Vector3(0.0, 0.0, ar * 1.02), ar * 0.12, 10, 3, gold)))
		if variant == &"brute":
			for k: int in range(3):
				_put(b, lo, &"gold", spike(metal, ar * 0.3, ar * 1.0, Vector3(sgn * ar * 1.1, -0.13 * h - 0.05 * h * float(k), 0.0), Vector3(sgn, 0.25, 0.0), 6))
		_put(b, lo, &"skin", ellipsoid(_skin_dark().lerp(skin, 0.5), Vector3(ar * 1.05, ar * 1.2, ar * 1.25), Vector3(0.0, -0.315 * h, -ar * 0.15), Basis.IDENTITY, 5, 7))
		_put(b, lo, &"skin", ellipsoid(_skin_dark().lerp(skin, 0.5), Vector3(ar * 0.45, ar * 0.7, ar * 0.5), Vector3(-sgn * ar * 0.8, -0.3 * h, -ar * 0.7), Basis.IDENTITY, 4, 6))


static func _build_legs(b: Dictionary, variant: StringName, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var gold_plate: bool = spec["gold"] as bool
	var skin: Color = _skin()
	var gold: Color = Palette.GOLD
	var metal: Color = gold.lerp(_bronze(), 0.6) if gold_plate else _bronze()
	var lr: float = 0.1 * h * w * 0.88 + 0.022
	for side: String in ["l", "r"]:
		var up: String = "upper_leg_" + side
		var lo: String = "lower_leg_" + side
		# Thigh and knee.
		_put(b, up, &"skin", _column([
			Vector3(0.03 * h, lr * 1.2, lr * 1.25), Vector3(-0.14 * h, lr * 1.3, lr * 1.38),
			Vector3(-0.34 * h, lr * 1.0, lr * 1.05), Vector3(-0.45 * h, lr * 0.9, lr * 0.95)], [skin], 8, 2))
		# Calf (bulging to the back), bronze greave with a spiked knee cop, anklet, clawed foot.
		_put(b, lo, &"skin", ellipsoid(skin, Vector3(lr * 0.98, lr * 1.0, lr * 1.05), Vector3.ZERO, Basis.IDENTITY, 4, 6))
		_put(b, lo, &"skin", _column([
			Vector3(0.0, lr * 0.92, lr * 0.98), Vector3(-0.12 * h, lr * 1.02, lr * 1.2),
			Vector3(-0.3 * h, lr * 0.68, lr * 0.74), Vector3(-0.42 * h, lr * 0.62, lr * 0.68)], [skin], 8, 2, [0.0, lr * 0.2, 0.0, 0.0]))
		_put(b, lo, &"gold", _column([
			Vector3(-0.05 * h, lr * 1.06, lr * 1.12), Vector3(-0.14 * h, lr * 1.1, lr * 1.2),
			Vector3(-0.3 * h, lr * 0.78, lr * 0.84), Vector3(-0.37 * h, lr * 0.74, lr * 0.8)], [metal], 8, 1, [0.0, lr * 0.12, 0.0, 0.0]))
		_put(b, lo, &"gold", ellipsoid(metal, Vector3(lr * 0.85, lr * 0.95, lr * 0.6), Vector3(0.0, 0.0, -lr * 0.75), Basis.IDENTITY, 4, 7))
		_put(b, lo, &"gold", spike(gold, lr * 0.3, lr * 1.0, Vector3(0.0, lr * 0.2, -lr * 1.15), Vector3(0.0, 0.55, -1.0), 6))
		_put(b, lo, &"gold", part(ring(Vector3(0.0, -0.375 * h, 0.0), Vector3(lr * 0.8, 0.0, 0.0), Vector3(0.0, 0.0, lr * 0.86), lr * 0.14, 10, 3, gold)))
		var foot: Color = _skin_dark().lerp(skin, 0.4)
		_put(b, lo, &"skin", ellipsoid(foot, Vector3(lr * 0.95, 0.05 * h, 0.15 * h), Vector3(0.0, -0.405 * h, -0.06 * h), Basis.IDENTITY, 5, 8))
		_put(b, lo, &"skin", ellipsoid(foot, Vector3(lr * 0.75, 0.06 * h, lr * 0.8), Vector3(0.0, -0.39 * h, 0.01 * h), Basis.IDENTITY, 4, 6))
		for t: int in range(3):
			var tx: float = (float(t) - 1.0) * lr * 0.55
			_put(b, lo, &"skin", spike(_ivory(), lr * 0.2, 0.07 * h, Vector3(tx, -0.415 * h, -0.19 * h), Vector3(tx * 1.2, -0.25, -1.0), 5))
	if variant == &"brute":
		# Fur leggings over the thighs.
		for side2: String in ["l", "r"]:
			_put(b, "upper_leg_" + side2, &"fur", _column([
				Vector3(0.0, lr * 1.3, lr * 1.36), Vector3(-0.12 * h, lr * 1.42, lr * 1.5),
				Vector3(-0.22 * h, lr * 1.25, lr * 1.3)], [_horn_dark().lightened(0.06)], 10, 2))


static func _build_weapon(b: Dictionary, variant: StringName, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var gold: Color = Palette.GOLD
	var bronze: Color = _bronze()
	var wood: Color = Palette.BARK.lerp(Palette.NIGHT_INDIGO, 0.35)
	var ws: String = "weapon_socket"
	var woodk: StringName = &"wood_local"
	# The grip sits in front of the fist.
	var g: Vector3 = Vector3(0.0, 0.0, -(0.075 * h * w * 0.9 + 0.022) * 0.95)
	match spec["weapon"] as StringName:
		&"spear":
			_put(b, ws, woodk, part(tube(_v3([g + Vector3(0.0, -0.98 * h, 0.0), g + Vector3(0.0, 1.37 * h, 0.0)]), _v2([Vector2(0.022 * h, 0.022 * h)]), 7, _c([wood, wood.lightened(0.1)]), 2)))
			_put(b, ws, &"gold", spike(bronze, 0.03 * h, 0.12 * h, g + Vector3(0.0, -0.96 * h, 0.0), Vector3.DOWN, 6))
			# Leaf blade with a mid-rib, on a gold socket with a crimson tassel.
			_put(b, ws, &"gold", part(tube(_v3([g + Vector3(0.0, 1.35 * h, 0.0), g + Vector3(0.0, 1.45 * h, 0.0), g + Vector3(0.0, 1.6 * h, 0.0), g + Vector3(0.0, 1.85 * h, 0.0)]), _v2([Vector2(0.03 * h, 0.025 * h), Vector2(0.085 * h, 0.014 * h), Vector2(0.065 * h, 0.012 * h), Vector2.ZERO]), 8, _c([bronze, bronze.lightened(0.15)]), 3)))
			_put(b, ws, &"gold", part(tube(_v3([g + Vector3(0.0, 1.38 * h, 0.0), g + Vector3(0.0, 1.82 * h, 0.0)]), _v2([Vector2(0.016 * h, 0.024 * h), Vector2.ZERO]), 5, _c([gold]), 2)))
			_put(b, ws, &"gold", _column_at(g + Vector3(0.0, 1.29 * h, 0.0), [Vector3(0.0, 0.03 * h, 0.03 * h), Vector3(0.04 * h, 0.042 * h, 0.042 * h), Vector3(0.09 * h, 0.03 * h, 0.03 * h)], gold, 8))
			for i: int in range(4):
				var a: float = TAU * float(i) / 4.0 + 0.4
				_put(b, ws, &"cloth", part(cloth_panel(g + Vector3(cos(a) * 0.03 * h, 1.29 * h, sin(a) * 0.03 * h), Vector3(-sin(a), 0.0, cos(a)), 0.2 * h, 0.03 * h, 0.05 * h, Vector3(cos(a), 0.0, sin(a)) * 0.03 * h, 0.0, _c([Palette.SINDOOR, _cloth()]), 1.0, 4, 3)))
		&"trident":
			_put(b, ws, &"gold", part(tube(_v3([g + Vector3(0.0, -1.0 * h, 0.0), g + Vector3(0.0, 0.95 * h, 0.0)]), _v2([Vector2(0.02 * h, 0.02 * h)]), 7, _c([gold.darkened(0.15), gold]), 2)))
			_put(b, ws, &"gold", ellipsoid(gold, Vector3(0.04 * h, 0.05 * h, 0.04 * h), g + Vector3(0.0, -1.0 * h, 0.0), Basis.IDENTITY, 5, 8))
			for y: float in [0.5, 0.86]:
				_put(b, ws, &"gold", _column_at(g + Vector3(0.0, y * h, 0.0), [Vector3(0.0, 0.022 * h, 0.022 * h), Vector3(0.03 * h, 0.04 * h, 0.04 * h), Vector3(0.06 * h, 0.022 * h, 0.022 * h)], gold, 8))
			# Three blades: a straight middle tine and two side tines sweeping out and up.
			var tb: Vector3 = g + Vector3(0.0, 0.94 * h, 0.0)
			_put(b, ws, &"gold", part(tube(_v3([tb, tb + Vector3(0.0, 0.12 * h, 0.0), tb + Vector3(0.0, 0.44 * h, 0.0)]), _v2([Vector2(0.03 * h, 0.02 * h), Vector2(0.05 * h, 0.014 * h), Vector2.ZERO]), 7, _c([gold]), 3)))
			for sgn: float in [-1.0, 1.0]:
				_put(b, ws, &"gold", part(tube(_v3([tb, tb + Vector3(sgn * 0.15 * h, 0.03 * h, 0.0), tb + Vector3(sgn * 0.19 * h, 0.16 * h, 0.0), tb + Vector3(sgn * 0.15 * h, 0.36 * h, 0.0)]), _v2([Vector2(0.024 * h, 0.018 * h), Vector2(0.03 * h, 0.016 * h), Vector2(0.034 * h, 0.012 * h), Vector2.ZERO]), 6, _c([gold]), 3)))
			for i2: int in range(3):
				var a2: float = TAU * float(i2) / 3.0
				_put(b, ws, &"cloth", part(cloth_panel(g + Vector3(cos(a2) * 0.03 * h, 0.86 * h, sin(a2) * 0.03 * h), Vector3(-sin(a2), 0.0, cos(a2)), 0.26 * h, 0.03 * h, 0.06 * h, Vector3(cos(a2), 0.0, sin(a2)) * 0.03 * h, 0.0, _c([Palette.SINDOOR, _cloth()]), 1.0, 4, 3)))
		&"club":
			# A gnarled club: wooden haft swelling into a bronze-banded, spiked head.
			_put(b, ws, woodk, part(tube(_v3([g + Vector3(0.0, -0.16 * h, 0.0), g + Vector3(0.0, 0.3 * h, 0.0), g + Vector3(0.0, 0.7 * h, 0.01 * h), g + Vector3(0.0, 0.98 * h, 0.0), g + Vector3(0.0, 1.12 * h, 0.0)]), _v2([Vector2(0.045 * h, 0.045 * h), Vector2(0.055 * h, 0.055 * h), Vector2(0.13 * h, 0.13 * h), Vector2(0.17 * h, 0.17 * h), Vector2(0.07 * h, 0.07 * h)]), 9, _c([wood, wood.lightened(0.08)]), 3)))
			_put(b, ws, &"gold", ellipsoid(bronze, Vector3(0.06 * h, 0.05 * h, 0.06 * h), g + Vector3(0.0, -0.17 * h, 0.0), Basis.IDENTITY, 5, 8))
			for y2: float in [0.62, 0.82, 1.0]:
				var rr: float = (0.115 if y2 < 0.7 else (0.158 if y2 < 0.9 else 0.168)) * h
				_put(b, ws, &"gold", part(ring(g + Vector3(0.0, y2 * h, 0.0), Vector3(rr, 0.0, 0.0), Vector3(0.0, 0.0, rr), 0.022 * h, 12, 5, bronze)))
				for k: int in range(5):
					var a3: float = TAU * float(k) / 5.0 + y2 * 3.0
					_put(b, ws, &"gold", spike(gold if y2 > 0.9 else bronze, 0.035 * h, 0.13 * h, g + Vector3(cos(a3) * rr, y2 * h, sin(a3) * rr), Vector3(cos(a3), 0.15, sin(a3)), 6))
			_put(b, ws, &"gold", spike(gold, 0.05 * h, 0.16 * h, g + Vector3(0.0, 1.1 * h, 0.0), Vector3.UP, 6))
		&"bow":
			# Tall recurved bow in the plane of the shot: the belly bulges forward (-Z), the string runs behind.
			var big: float = 0.9 * h
			for sgn2: float in [-1.0, 1.0]:
				_put(b, ws, &"lacquer_local", part(tube(_v3([
					g + Vector3(0.0, sgn2 * 0.05 * h, -0.02 * h), g + Vector3(0.0, sgn2 * big * 0.4, 0.07 * h),
					g + Vector3(0.0, sgn2 * big * 0.78, 0.3 * h), g + Vector3(0.0, sgn2 * big * 0.96, 0.25 * h),
					g + Vector3(0.0, sgn2 * big * 1.06, 0.14 * h)]),
					_v2([Vector2(0.034 * h, 0.03 * h), Vector2(0.04 * h, 0.022 * h), Vector2(0.03 * h, 0.016 * h), Vector2(0.02 * h, 0.014 * h), Vector2(0.008 * h, 0.008 * h)]), 6, _c([_armor(), _armor_dark()]), 3)))
				_put(b, ws, &"gold", part(tube(_v3([g + Vector3(0.0, sgn2 * big * 0.96, 0.25 * h), g + Vector3(0.0, sgn2 * big * 1.07, 0.13 * h)]), _v2([Vector2(0.024 * h, 0.018 * h), Vector2(0.012 * h, 0.012 * h)]), 6, _c([gold]), 1)))
				_put(b, ws, &"gold", part(ring(g + Vector3(0.0, sgn2 * big * 0.4, 0.07 * h), Vector3(0.042 * h, 0.0, 0.0), Vector3(0.0, 0.0, 0.026 * h), 0.008 * h, 8, 3, gold)))
			_put(b, ws, &"gold", _column_at(g + Vector3(0.0, -0.07 * h, -0.02 * h), [Vector3(0.0, 0.04 * h, 0.036 * h), Vector3(0.14 * h, 0.04 * h, 0.036 * h)], gold, 7))
			_put(b, ws, &"skin", part(tube(_v3([g + Vector3(0.0, -big * 1.0, 0.21 * h), g + Vector3(0.0, big * 1.0, 0.21 * h)]), _v2([Vector2(0.005 * h, 0.005 * h)]), 4, _c([_ivory()]), 1)))
		_:
			pass


## Upright tube part at `origin`; stations as in _column().
static func _column_at(origin: Vector3, stations: Array[Vector3], color: Color, sides: int) -> Dictionary:
	var piece: Dictionary = _column(stations, [color], sides, 2)
	piece["transform"] = Transform3D(Basis.IDENTITY, origin)
	return piece
