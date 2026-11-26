extends GdUnitTestSuite
## Acceptance tests for the tile surfaces of world/level_builder.gd (DESIGN §9 M15b, reworked by B6 for
## docs/ART.md "Geometry"). Tiles render as one continuous top per tile type, with side faces only where a
## neighbour is lower or missing, and solid merged blocks for walls. Colliders and navmesh are unchanged.
## B6 changed the numbers: tops are subdivided and gently uneven, faces are bevelled stone or rocky cliffs.

const UP: Vector3 = Vector3(0.0, 1.0, 0.0)
const EAST: Vector3 = Vector3(1.0, 0.0, 0.0)
const WEST: Vector3 = Vector3(-1.0, 0.0, 0.0)
## A vertex belongs to a top when its normal points at least this much upwards; to a face when it leans past it.
const TOP_DOT: float = 0.9
const FACE_DOT: float = 0.75


func _level(tiles: Array) -> Dictionary:
	return {"id": "m15b_level", "nav": true, "tiles": tiles, "props": [], "spawns": [], "triggers": [], "shrines": []}


func _tile(x: int, z: int, tile_type: String, step: int) -> Dictionary:
	return {"x": x, "z": z, "type": tile_type, "step": step}


func _type_mesh(root: Node3D, tile_type: String) -> MeshInstance3D:
	var group: Node = root.get_node_or_null("Tiles")
	return group.get_node_or_null("Tiles_" + tile_type) as MeshInstance3D


func _verts(mesh_node: MeshInstance3D) -> PackedVector3Array:
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


func _normals(mesh_node: MeshInstance3D) -> PackedVector3Array:
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array


func _colours(mesh_node: MeshInstance3D) -> PackedColorArray:
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_COLOR] as PackedColorArray


## Counts the vertices of faces looking toward `wanted` that lie within `reach` of the plane x = plane_x.
func _count_facing_near_x(mesh_node: MeshInstance3D, wanted: Vector3, plane_x: float, reach: float) -> int:
	var count: int = 0
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	for i: int in range(verts.size()):
		if norms[i].dot(wanted) > FACE_DOT and absf(verts[i].x - plane_x) <= reach:
			count += 1
	return count


func _side_vertices(mesh_node: MeshInstance3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	for i: int in range(verts.size()):
		if absf(norms[i].y) < 0.5:
			out.append(verts[i])
	return out


func test_flat_field_is_one_continuous_top() -> void:
	var tiles: Array = []
	for x: int in range(1, 4):
		for z: int in range(1, 4):
			tiles.append(_tile(x, z, "ground", 0))
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "ground")
	assert_object(mesh_node).is_not_null()
	# Nine tops, each a grid of TOP_SUBDIVISIONS squared cells of two triangles, and no side faces at all.
	var cells: int = LevelBuilder.TOP_SUBDIVISIONS * LevelBuilder.TOP_SUBDIVISIONS
	assert_int(_verts(mesh_node).size()).is_equal(9 * cells * 6)
	assert_int(_side_vertices(mesh_node).size()).is_equal(0)
	for n: Vector3 in _normals(mesh_node):
		assert_bool(n.dot(UP) > TOP_DOT).is_true()
	assert_int(mesh_node.mesh.get_surface_count()).is_equal(1)


func test_every_triangle_is_front_facing_for_godot() -> void:
	# Godot draws clockwise triangles (seen from outside) as front faces, so each triangle's right-hand cross
	# product must point against its stored normals. Otherwise the tiles render inside-out.
	var tiles: Array = [
		_tile(0, 0, "ground", 2), _tile(1, 0, "ground", 0), _tile(0, 1, "wall", 0), _tile(1, 1, "grass", 1),
		_tile(2, 0, "stone_floor", 3), _tile(2, 1, "water", 0), _tile(2, 2, "sand", 0),
	]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	for tile_type: String in ["ground", "wall", "grass", "stone_floor", "water", "sand"]:
		var mesh_node: MeshInstance3D = _type_mesh(root, tile_type)
		var verts: PackedVector3Array = _verts(mesh_node)
		var norms: PackedVector3Array = _normals(mesh_node)
		assert_int(verts.size() % 3).is_equal(0)
		var wrong: int = 0
		var i: int = 0
		while i + 2 < verts.size():
			var geometric: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
			if geometric.dot(norms[i] + norms[i + 1] + norms[i + 2]) >= 0.0:
				wrong += 1
			i += 3
		assert_int(wrong).is_equal(0)


func test_no_side_faces_between_equal_neighbours() -> void:
	var tiles: Array = [_tile(0, 0, "ground", 1), _tile(1, 0, "ground", 1)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "ground")
	# The shared boundary at x = 2 must produce no faces; the outer ends at x = 0 and x = 4 do.
	assert_int(_count_facing_near_x(mesh_node, EAST, 2.0, 0.5)).is_equal(0)
	assert_int(_count_facing_near_x(mesh_node, WEST, 2.0, 0.5)).is_equal(0)
	assert_int(_count_facing_near_x(mesh_node, EAST, 4.0, 0.5)).is_greater(0)
	assert_int(_count_facing_near_x(mesh_node, WEST, 0.0, 0.5)).is_greater(0)


func test_lone_tile_cliffs_down_to_ground_level() -> void:
	# A single tile at step 4 (top y = 2.0) with void all round: four cliff faces falling to y = 0.
	var tiles: Array = [_tile(0, 0, "ground", 4)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "ground")
	var sides: PackedVector3Array = _side_vertices(mesh_node)
	assert_int(sides.size()).is_greater(4 * 6 - 1)
	var low: float = 1000.0
	var high: float = -1000.0
	for v: Vector3 in sides:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	assert_float(low).is_equal_approx(0.0, 0.001)
	assert_float(high).is_equal_approx(2.0, 0.001)
	for dir: Vector3 in [EAST, WEST, Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)]:
		var facing: int = 0
		for n: Vector3 in _normals(mesh_node):
			if n.dot(dir) > FACE_DOT:
				facing += 1
		assert_int(facing).is_greater(0)


func test_step_up_produces_cliff_face_over_the_height_difference() -> void:
	# (0,0) is at step 2 (y = 1.0). Its east neighbour (1,0) is at step 0, so an east face spans y 0..1 at x = 2.
	# The lower tile must not draw a west face toward the higher one.
	var tiles: Array = [_tile(0, 0, "ground", 2), _tile(1, 0, "ground", 0)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "ground")
	assert_int(_count_facing_near_x(mesh_node, EAST, 2.0, 0.3)).is_greater(5)
	assert_int(_count_facing_near_x(mesh_node, WEST, 2.0, 0.3)).is_equal(0)
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var low: float = 1000.0
	var high: float = -1000.0
	for i: int in range(verts.size()):
		if norms[i].dot(EAST) > FACE_DOT and absf(verts[i].x - 2.0) < 0.3:
			low = minf(low, verts[i].y)
			high = maxf(high, verts[i].y)
	assert_float(low).is_equal_approx(0.0, 0.001)
	assert_float(high).is_equal_approx(1.0, 0.001)


func test_top_faces_sit_at_the_tile_height() -> void:
	var tiles: Array = [_tile(0, 0, "grass", 3), _tile(1, 0, "grass", 3)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "grass")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var tops: int = 0
	for i: int in range(verts.size()):
		if norms[i].dot(UP) > TOP_DOT:
			tops += 1
			# Visual height noise only: never more than HEIGHT_AMPLITUDE away from the collider's top.
			assert_float(verts[i].y).is_equal_approx(1.5, LevelBuilder.HEIGHT_AMPLITUDE + 0.001)
	assert_int(tops).is_greater(0)


func test_wall_is_a_solid_block_with_no_bottom() -> void:
	var tiles: Array = [_tile(0, 0, "wall", 0)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "wall")
	var verts: PackedVector3Array = _verts(mesh_node)
	var norms: PackedVector3Array = _normals(mesh_node)
	var top: float = -1000.0
	var bottom: float = 1000.0
	for i: int in range(verts.size()):
		top = maxf(top, verts[i].y)
		bottom = minf(bottom, verts[i].y)
		# Nothing looks down at ground level: the block has no bottom face.
		assert_bool(norms[i].y < -0.5 and verts[i].y < 0.2).is_false()
	assert_float(top).is_equal_approx(2.0, 0.001)
	assert_float(bottom).is_equal_approx(0.0, 0.001)
	for dir: Vector3 in [EAST, WEST, Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), UP]:
		var facing: int = 0
		for n: Vector3 in norms:
			if n.dot(dir) > 0.999:
				facing += 1
		assert_int(facing).is_greater(0)


func test_adjacent_walls_share_no_faces() -> void:
	var tiles: Array = [_tile(0, 0, "wall", 0), _tile(1, 0, "wall", 0)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "wall")
	assert_int(_count_facing_near_x(mesh_node, EAST, 2.0, 0.5)).is_equal(0)
	assert_int(_count_facing_near_x(mesh_node, WEST, 2.0, 0.5)).is_equal(0)
	assert_int(_count_facing_near_x(mesh_node, EAST, 4.0, 0.5)).is_greater(0)


func test_wall_beside_ground_shows_its_exposed_face() -> void:
	var tiles: Array = [_tile(0, 0, "wall", 0), _tile(1, 0, "ground", 0)]
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var wall_node: MeshInstance3D = _type_mesh(root, "wall")
	var ground_node: MeshInstance3D = _type_mesh(root, "ground")
	# The wall's east face runs from the ground top (0) up to its roof (2), so it is drawn.
	assert_int(_count_facing_near_x(wall_node, EAST, 2.0, 0.3)).is_greater(5)
	# The ground's west face would be buried in the wall, so it is not drawn.
	assert_int(_count_facing_near_x(ground_node, WEST, 2.0, 0.5)).is_equal(0)


func test_colour_variation_is_gentle_and_varies_across_tiles() -> void:
	var tiles: Array = []
	for x: int in range(8):
		for z: int in range(8):
			tiles.append(_tile(x, z, "ground", 0))
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var mesh_node: MeshInstance3D = _type_mesh(root, "ground")
	var cols: PackedColorArray = _colours(mesh_node)
	var low: float = 10.0
	var high: float = 0.0
	var distinct: Dictionary = {}
	for c: Color in cols:
		low = minf(low, c.v)
		high = maxf(high, c.v)
		distinct[snappedf(c.v, 0.01)] = true
	# Painted variation, not noise: a visible spread, but well inside one colour family.
	assert_bool(high / low < 1.6).is_true()
	assert_bool(high / low > 1.03).is_true()
	assert_int(distinct.size()).is_greater(3)


func test_colours_are_deterministic() -> void:
	var tiles: Array = [_tile(0, 0, "sand", 0), _tile(1, 0, "sand", 0), _tile(0, 1, "sand", 0)]
	var first: Node3D = LevelBuilder.build(_level(tiles))
	var second: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(first)
	auto_free(second)
	var first_cols: PackedColorArray = _colours(_type_mesh(first, "sand"))
	var second_cols: PackedColorArray = _colours(_type_mesh(second, "sand"))
	assert_int(first_cols.size()).is_equal(second_cols.size())
	for i: int in range(first_cols.size()):
		assert_bool(first_cols[i].is_equal_approx(second_cols[i])).is_true()


func test_colliders_are_unchanged_one_box_per_tile() -> void:
	var tiles: Array = []
	for x: int in range(3):
		for z: int in range(3):
			tiles.append(_tile(x, z, "ground", 0))
	var root: Node3D = LevelBuilder.build(_level(tiles))
	auto_free(root)
	var floor_body: StaticBody3D = root.get_node("Tiles/Floor") as StaticBody3D
	assert_object(floor_body).is_not_null()
	assert_int(floor_body.get_child_count()).is_equal(9)
	var shape_node: CollisionShape3D = floor_body.get_child(0) as CollisionShape3D
	assert_object(shape_node.shape).is_instanceof(BoxShape3D)
	assert_vector((shape_node.shape as BoxShape3D).size).is_equal_approx(Vector3(2.0, 1.0, 2.0), Vector3.ONE * 0.001)
	assert_float(shape_node.position.y).is_equal_approx(-0.5, 0.001)
