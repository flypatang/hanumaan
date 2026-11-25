class_name NatureKit
extends RefCounted
## Procedural nature props (DESIGN §9, M10). Every function takes a seed and is deterministic: the same seed
## returns the same geometry. Each tree is built from MeshKit primitives and stays well under 1500 triangles.
## Colours come from Palette only (DESIGN §6.1).

const OCEAN_SHADER_CODE: String = """shader_type spatial;

uniform vec4 deep_colour : source_color = vec4(0.0549, 0.2314, 0.3608, 1.0);
uniform vec4 crest_colour : source_color = vec4(0.2, 0.42, 0.55, 1.0);
uniform float wave_height : hint_range(0.0, 2.0) = 0.25;
uniform float wave_speed = 1.2;
uniform float wave_frequency = 0.8;

varying float crest;

void vertex() {
	float t = TIME * wave_speed;
	float kx = wave_frequency;
	float kz = wave_frequency * 0.7;
	float a = VERTEX.x * kx + t;
	float b = VERTEX.z * kz - t * 0.8;
	float h = sin(a) * 0.6 + sin(b) * 0.4;
	VERTEX.y += h * wave_height;
	float dhdx = cos(a) * 0.6 * kx * wave_height;
	float dhdz = cos(b) * 0.4 * kz * wave_height;
	NORMAL = normalize(vec3(-dhdx, 1.0, -dhdz));
	crest = clamp(h, 0.0, 1.0);
}

void fragment() {
	ALBEDO = mix(deep_colour.rgb, crest_colour.rgb, crest * 0.5);
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
"""


## Ashoka: a dense green canopy of rounded clusters, studded with ASHOKA_RED blossom clusters.
static func ashoka_tree(rng_seed: int, height: float = 6.0) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.cylinder(height * 0.035, height * 0.06, height * 0.6, 8, Palette.STONE),
		Vector3(0.0, height * 0.3, 0.0)))
	var centres: Array[Vector3] = []
	var radii: Array[float] = []
	for i: int in range(6):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.0, height * 0.18)
		var centre: Vector3 = Vector3(cos(angle) * dist, height * (0.6 + rng.randf_range(-0.08, 0.08)),
			sin(angle) * dist)
		var radius: float = height * rng.randf_range(0.22, 0.3)
		centres.append(centre)
		radii.append(radius)
		parts.append(_part(MeshKit.sphere(radius, 6, 9, Palette.GROVE_GREEN), centre))
	for i: int in range(10):
		var k: int = rng.randi() % centres.size()
		var dir: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0))
		if dir.length_squared() < 0.01:
			dir = Vector3.UP
		var pos: Vector3 = centres[k] + dir.normalized() * radii[k] * 0.95
		parts.append(_part(MeshKit.sphere(height * 0.05, 4, 5, Palette.ASHOKA_RED), pos))
	return _wrap(MeshKit.merge(parts), "AshokaTree")


## Shimshapa: a taller trunk with three spreading limbs and a flattened, pale-green crown. No blossoms.
static func shimshapa_tree(rng_seed: int, height: float = 7.0) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.cylinder(height * 0.03, height * 0.05, height * 0.5, 8, Palette.STONE),
		Vector3(0.0, height * 0.25, 0.0)))
	var base: Vector3 = Vector3(0.0, height * 0.45, 0.0)
	var limb_len: float = height * 0.35
	var start_angle: float = rng.randf_range(0.0, TAU)
	for i: int in range(3):
		var yaw: float = start_angle + TAU * float(i) / 3.0
		var outward: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var axis: Vector3 = Vector3.UP.cross(outward).normalized()
		var tilt: Vector3 = Vector3.UP.rotated(axis, 0.6)
		var branch_centre: Vector3 = base + tilt * limb_len * 0.5
		parts.append({
			"mesh": MeshKit.cylinder(height * 0.012, height * 0.018, limb_len, 6, Palette.STONE),
			"transform": Transform3D(Basis(axis, 0.6), branch_centre),
		})
		var tip: Vector3 = base + tilt * limb_len
		parts.append(_part_scaled(MeshKit.sphere(height * rng.randf_range(0.16, 0.2), 6, 9, Palette.GROVE_GREEN),
			tip, Vector3(1.1, 0.7, 1.1)))
	parts.append(_part_scaled(MeshKit.sphere(height * 0.22, 6, 9, Palette.GROVE_GREEN),
		Vector3(0.0, height * 0.7, 0.0), Vector3(1.2, 0.75, 1.2)))
	return _wrap(MeshKit.merge(parts), "ShimshapaTree")


## Irregular stone block with its surface jittered by the seed.
static func rock(size: Vector3, rng_seed: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	return _wrap(_lumpy(size, rng, Palette.STONE, 6, 10, 0.18), "Rock")


## A rock mass rising from y = 0, with a lumpier, taller silhouette than rock().
static func cliff(size: Vector3, rng_seed: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var mesh: ArrayMesh = _lumpy(size, rng, Palette.STONE, 7, 10, 0.25)
	var mi: MeshInstance3D = _wrap(mesh, "Cliff")
	# Lift the instance so the lowest jittered vertex sits exactly on y = 0.
	mi.position = Vector3(0.0, -mesh.get_aabb().position.y, 0.0)
	return mi


## Animated ocean plane in the DEEP_OCEAN colour family, moved by a shader created here from a string.
static func ocean_plane(size: Vector2) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	var shader: Shader = Shader.new()
	shader.code = OCEAN_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("deep_colour", Palette.DEEP_OCEAN)
	material.set_shader_parameter("crest_colour", Palette.DEEP_OCEAN.lerp(Palette.MOON, 0.3))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ocean"
	mi.mesh = plane
	mi.material_override = material
	return mi


## A clump of thin, double-sided grass blades within `radius` of the origin.
static func grass_patch(rng_seed: int, radius: float = 1.5, blades: int = 24) -> MeshInstance3D:
	var rng: RandomNumberGenerator = _rng(rng_seed)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(blades):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = sqrt(rng.randf()) * radius
		var pos: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var height: float = rng.randf_range(0.25, 0.6)
		var yaw: float = rng.randf_range(0.0, TAU)
		var side: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * 0.035
		var lean: Vector3 = Vector3(rng.randf_range(-0.12, 0.12), height, rng.randf_range(-0.12, 0.12))
		var tip: Vector3 = pos + lean
		var colour: Color = Palette.GROVE_GREEN.lerp(Palette.GOLD, rng.randf_range(0.0, 0.2))
		_emit_tri(st, pos - side, pos + side, tip, colour)
		_emit_tri(st, pos + side, pos - side, tip, colour)
	return _wrap(st.commit(), "GrassPatch")


static func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


static func _part(mesh: ArrayMesh, pos: Vector3) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY, pos)}


static func _part_scaled(mesh: ArrayMesh, pos: Vector3, scale: Vector3) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY.scaled(scale), pos)}


static func _wrap(mesh: ArrayMesh, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	return mi


## Jittered sphere scaled to `size`: each grid vertex gets a random radius factor, poles stay single points.
static func _lumpy(size: Vector3, rng: RandomNumberGenerator, color: Color, rings: int, segments: int,
		jitter: float) -> ArrayMesh:
	var half: Vector3 = size * 0.5
	var points: Array[PackedVector3Array] = []
	for i: int in range(rings):
		var theta: float = PI * float(i) / float(rings - 1)
		var is_pole: bool = i == 0 or i == rings - 1
		var pole_factor: float = 1.0 + rng.randf_range(-jitter, jitter)
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in range(segments):
			var phi: float = TAU * float(j) / float(segments)
			var factor: float = pole_factor if is_pole else 1.0 + rng.randf_range(-jitter, jitter)
			var dir: Vector3 = Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			row.append(dir * half * factor)
		points.append(row)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(rings - 1):
		var upper: PackedVector3Array = points[i]
		var lower: PackedVector3Array = points[i + 1]
		for j: int in range(segments):
			var jn: int = (j + 1) % segments
			var a: Vector3 = upper[j]
			var b: Vector3 = upper[jn]
			var c: Vector3 = lower[jn]
			var d: Vector3 = lower[j]
			var shade: float = rng.randf_range(0.88, 1.05)
			var colour: Color = Color(color.r * shade, color.g * shade, color.b * shade, 1.0)
			_emit_outward(st, a, b, c, colour)
			_emit_outward(st, a, c, d, colour)
	return st.commit()


## Adds a triangle with its face normal pointing away from the origin.
static func _emit_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var p1: Vector3 = b
	var p2: Vector3 = c
	if n.dot((a + b + c) / 3.0) < 0.0:
		p1 = c
		p2 = b
		n = -n
	_emit_tri(st, a, p1, p2, colour)


## Adds a triangle whose normal follows its winding order.
static func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var normal: Vector3 = n.normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(normal)
		st.set_color(colour)
		st.add_vertex(v)
