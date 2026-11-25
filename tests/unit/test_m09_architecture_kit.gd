extends GdUnitTestSuite
## Acceptance tests for M09 (gen/architecture_kit.gd), DESIGN §9.
## Same seed gives the same result; every prop has collision shapes; cornices use GOLD and walls use STONE;
## flammable/protected metadata defaults to false and can be set through opts.


const SIZE: Vector3 = Vector3(4.0, 6.0, 4.0)
const SEED: int = 42


func _mesh_of(root: Node3D) -> ArrayMesh:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh as ArrayMesh
	return null


func _colliders_of(root: Node3D) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for body_node: Node in root.find_children("*", "StaticBody3D", true, false):
		for shape_node: Node in body_node.get_children():
			if shape_node is CollisionShape3D:
				found.append(shape_node as CollisionShape3D)
	return found


func _has_color(mesh: ArrayMesh, color: Color) -> bool:
	if mesh == null:
		return false
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			if c.is_equal_approx(color):
				return true
	return false


func _signature(root: Node3D) -> Array:
	## A comparable summary of the mesh vertices and collision shapes of a built prop.
	var mesh: ArrayMesh = _mesh_of(root)
	var verts: PackedVector3Array = PackedVector3Array()
	if mesh != null:
		for s: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			verts.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var shapes: Array = []
	for cs: CollisionShape3D in _colliders_of(root):
		shapes.append(cs.position)
		shapes.append((cs.shape as BoxShape3D).size if cs.shape is BoxShape3D else Vector3.ZERO)
	return [verts, shapes]


func test_wall_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.wall(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.wall(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_tier_house_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.tier_house(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.tier_house(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_pillar_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.pillar(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.pillar(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_gopuram_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_stairs_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.stairs(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.stairs(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_rooftop_same_seed_same_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.rooftop(SIZE, SEED))
	var b: Node3D = auto_free(ArchitectureKit.rooftop(SIZE, SEED))
	assert_array(_signature(a)).is_equal(_signature(b))


func test_wall_different_seed_different_result() -> void:
	var a: Node3D = auto_free(ArchitectureKit.wall(SIZE, 1))
	var b: Node3D = auto_free(ArchitectureKit.wall(SIZE, 2))
	assert_bool(_signature(a) == _signature(b)).is_false()


func test_every_prop_returns_node3d_with_mesh_and_collision() -> void:
	var props: Array[Node3D] = [
		auto_free(ArchitectureKit.wall(SIZE, SEED)),
		auto_free(ArchitectureKit.tier_house(SIZE, SEED)),
		auto_free(ArchitectureKit.pillar(SIZE, SEED)),
		auto_free(ArchitectureKit.gopuram(SIZE, SEED)),
		auto_free(ArchitectureKit.stairs(SIZE, SEED)),
		auto_free(ArchitectureKit.rooftop(SIZE, SEED)),
	]
	for prop: Node3D in props:
		assert_object(prop).is_not_null()
		assert_object(_mesh_of(prop)).is_not_null()
		var shapes: Array[CollisionShape3D] = _colliders_of(prop)
		assert_int(shapes.size()).is_greater(0)
		for cs: CollisionShape3D in shapes:
			assert_object(cs.shape).is_not_null()


func test_wall_collision_matches_size() -> void:
	var wall: Node3D = auto_free(ArchitectureKit.wall(SIZE, SEED))
	var shapes: Array[CollisionShape3D] = _colliders_of(wall)
	assert_int(shapes.size()).is_greater(0)
	var first: BoxShape3D = shapes[0].shape as BoxShape3D
	assert_object(first).is_not_null()
	assert_float(first.size.y).is_equal_approx(SIZE.y, 0.01)


func test_wall_mesh_bounds_match_size() -> void:
	var wall: Node3D = auto_free(ArchitectureKit.wall(SIZE, SEED))
	var aabb: AABB = _mesh_of(wall).get_aabb()
	assert_float(aabb.size.y).is_equal_approx(SIZE.y, 0.01)
	assert_float(aabb.size.x).is_equal_approx(SIZE.x, 0.01)


func test_tier_house_has_gold_cornice() -> void:
	var house: Node3D = auto_free(ArchitectureKit.tier_house(SIZE, SEED))
	assert_bool(_has_color(_mesh_of(house), Palette.GOLD)).is_true()


func test_gopuram_has_gold_cornice() -> void:
	var tower: Node3D = auto_free(ArchitectureKit.gopuram(SIZE, SEED))
	assert_bool(_has_color(_mesh_of(tower), Palette.GOLD)).is_true()


func test_walls_use_stone() -> void:
	var wall: Node3D = auto_free(ArchitectureKit.wall(SIZE, SEED))
	var house: Node3D = auto_free(ArchitectureKit.tier_house(SIZE, SEED))
	assert_bool(_has_color(_mesh_of(wall), Palette.STONE)).is_true()
	assert_bool(_has_color(_mesh_of(house), Palette.STONE)).is_true()


func test_flags_default_to_false() -> void:
	var props: Array[Node3D] = [
		auto_free(ArchitectureKit.wall(SIZE, SEED)),
		auto_free(ArchitectureKit.tier_house(SIZE, SEED)),
		auto_free(ArchitectureKit.pillar(SIZE, SEED)),
		auto_free(ArchitectureKit.gopuram(SIZE, SEED)),
		auto_free(ArchitectureKit.stairs(SIZE, SEED)),
		auto_free(ArchitectureKit.rooftop(SIZE, SEED)),
	]
	for prop: Node3D in props:
		assert_bool(prop.get_meta("flammable", true) as bool).is_false()
		assert_bool(prop.get_meta("protected", true) as bool).is_false()


func test_flags_can_be_set_through_opts() -> void:
	var opts: Dictionary = {"flammable": true, "protected": true}
	var wood: Node3D = auto_free(ArchitectureKit.pillar(SIZE, SEED, opts))
	assert_bool(wood.get_meta("flammable", false) as bool).is_true()
	assert_bool(wood.get_meta("protected", false) as bool).is_true()
