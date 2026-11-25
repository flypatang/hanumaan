class_name MeshKit
extends RefCounted
## Procedural flat-shaded primitives (DESIGN §9, M05). Every triangle gets its own three vertices and one
## face normal, so shading is flat. Colours are stored as vertex colours and read by flat_material().
## All solids are centred on the origin, which lets triangle winding and normals be made outward-facing.


static var _flat_material: StandardMaterial3D = null


static func flat_material() -> StandardMaterial3D:
	if _flat_material == null:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.roughness = 1.0
		_flat_material = material
	return _flat_material


static func box(size: Vector3, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var origin: Vector3 = Vector3.ZERO
	# +X
	_quad(st, Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz), color, origin)
	# -X
	_quad(st, Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz), color, origin)
	# +Y
	_quad(st, Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), color, origin)
	# -Y
	_quad(st, Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), color, origin)
	# +Z
	_quad(st, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), color, origin)
	# -Z
	_quad(st, Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), color, origin)
	return st.commit()


## Truncated cone along Y, centred on the origin. A zero radius turns the top or bottom into an apex.
static func cylinder(r_top: float, r_bottom: float, h: float, sides: int, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = h * 0.5
	var origin: Vector3 = Vector3.ZERO
	var top_centre: Vector3 = Vector3(0.0, half, 0.0)
	var bottom_centre: Vector3 = Vector3(0.0, -half, 0.0)
	for i: int in range(sides):
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var t0: Vector3 = Vector3(sin(a0) * r_top, half, cos(a0) * r_top)
		var t1: Vector3 = Vector3(sin(a1) * r_top, half, cos(a1) * r_top)
		var b0: Vector3 = Vector3(sin(a0) * r_bottom, -half, cos(a0) * r_bottom)
		var b1: Vector3 = Vector3(sin(a1) * r_bottom, -half, cos(a1) * r_bottom)
		if r_top > 0.0 and r_bottom > 0.0:
			_quad(st, b0, b1, t1, t0, color, origin)
		elif r_top > 0.0:
			_tri(st, bottom_centre, t0, t1, color, origin)
		elif r_bottom > 0.0:
			_tri(st, top_centre, b0, b1, color, origin)
		if r_top > 0.0:
			_tri(st, top_centre, t0, t1, color, origin)
		if r_bottom > 0.0:
			_tri(st, bottom_centre, b0, b1, color, origin)
	return st.commit()


static func cone(r: float, h: float, sides: int, color: Color) -> ArrayMesh:
	return cylinder(0.0, r, h, sides, color)


## UV sphere with `rings` latitude bands (rings >= 2) and `segments` longitude slices (segments >= 3).
static func sphere(r: float, rings: int, segments: int, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin: Vector3 = Vector3.ZERO
	for i: int in range(rings):
		for k: int in range(segments):
			var a: Vector3 = _sphere_point(r, rings, segments, i, k)
			var b: Vector3 = _sphere_point(r, rings, segments, i, k + 1)
			var c: Vector3 = _sphere_point(r, rings, segments, i + 1, k + 1)
			var d: Vector3 = _sphere_point(r, rings, segments, i + 1, k)
			if i == 0:
				_tri(st, a, c, d, color, origin)
			elif i == rings - 1:
				_tri(st, a, b, c, color, origin)
			else:
				_quad(st, a, b, c, d, color, origin)
	return st.commit()


## Cylinder body with a full sphere at each end; `h` is the total height including the caps.
static func capsule(r: float, h: float, color: Color) -> ArrayMesh:
	var body_h: float = maxf(0.0, h - 2.0 * r)
	var end_offset: float = body_h * 0.5
	var parts: Array[Dictionary] = [
		{"mesh": cylinder(r, r, body_h, 12, color), "transform": Transform3D(Basis(), Vector3.ZERO)},
		{"mesh": sphere(r, 6, 12, color), "transform": Transform3D(Basis(), Vector3(0.0, end_offset, 0.0))},
		{"mesh": sphere(r, 6, 12, color), "transform": Transform3D(Basis(), Vector3(0.0, -end_offset, 0.0))},
	]
	return merge(parts)


## Combines meshes into one flat-shaded ArrayMesh. Each part is {"mesh": ArrayMesh, "transform": Transform3D}.
## Vertices get the part transform, normals get its rotation (non-uniform scale is not corrected).
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for part: Dictionary in parts:
		var mesh: ArrayMesh = part["mesh"] as ArrayMesh
		var xf: Transform3D = part["transform"] as Transform3D
		if mesh == null:
			continue
		var basis: Basis = xf.basis
		for s: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			for vi: int in range(verts.size()):
				var n: Vector3 = norms[vi] if norms.size() > vi else Vector3.UP
				var c: Color = cols[vi] if cols.size() > vi else Color.WHITE
				st.set_normal((basis * n).normalized())
				st.set_color(c)
				st.add_vertex(xf * verts[vi])
				count += 1
	if count == 0:
		return ArrayMesh.new()
	return st.commit()


static func _sphere_point(r: float, rings: int, segments: int, row: int, col: int) -> Vector3:
	var phi: float = PI * float(row) / float(rings)
	var theta: float = TAU * float(col) / float(segments)
	var rad: float = r * sin(phi)
	return Vector3(rad * sin(theta), r * cos(phi), rad * cos(theta))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, interior: Vector3) -> void:
	_tri(st, a, b, c, color, interior)
	_tri(st, a, c, d, color, interior)


## Adds one flat triangle. The winding is flipped if needed so the normal points away from `interior`.
## Degenerate triangles are dropped.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, interior: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var centroid: Vector3 = (a + b + c) / 3.0
	var p1: Vector3 = b
	var p2: Vector3 = c
	if n.dot(centroid - interior) < 0.0:
		p1 = c
		p2 = b
		n = -n
	var normal: Vector3 = n.normalized()
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(p2)
