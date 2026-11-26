extends GdUnitTestSuite
## Acceptance tests for B4 (Lanka architecture v2, docs/ART.md "Geometry"): painterly material surfaces, opulent
## trims (gold, red lacquer, stone), a 7-tier gopuram with niches and a barrel-vault crown, palatial houses,
## flat rooftops with awnings and pots, the 6k triangle budget, and the unchanged collision/metadata API.

const BUDGET: int = 6000


func _visual(root: Node3D) -> MeshInstance3D:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _mesh_of(root: Node3D) -> ArrayMesh:
	var visual: MeshInstance3D = _visual(root)
	return visual.mesh as ArrayMesh if visual != null else null


func _surface_names(mesh: ArrayMesh) -> Array[String]:
	var names: Array[String] = []
	for s: int in range(mesh.get_surface_count()):
		names.append(mesh.surface_get_name(s))
	return names


@warning_ignore("integer_division")
func _tri_count(mesh: ArrayMesh) -> int:
	var total: int = 0
	for s: int in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _has_color(mesh: ArrayMesh, surface_name: String, color: Color) -> bool:
	for s: int in range(mesh.get_surface_count()):
		if mesh.surface_get_name(s) != surface_name:
			continue
		var cols: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			if is_equal_approx(c.r, color.r) and is_equal_approx(c.g, color.g) and is_equal_approx(c.b, color.b):
				return true
	return false


func _bodies(root: Node3D) -> Array[Node]:
	return root.find_children("*", "StaticBody3D", true, false)


func _all_props() -> Array[Node3D]:
	var props: Array[Node3D] = [
		auto_free(ArchitectureKit.wall(Vector3(2, 3, 6), 11)),
		auto_free(ArchitectureKit.wall(Vector3(12, 4, 1), 12)),
		auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 13)),
		auto_free(ArchitectureKit.tier_house(Vector3(7, 8, 7), 14)),
		auto_free(ArchitectureKit.pillar(Vector3(1, 5, 1), 15)),
		auto_free(ArchitectureKit.pillar(Vector3(1, 7, 1), 16)),
		auto_free(ArchitectureKit.gopuram(Vector3(6, 12, 4), 17)),
		auto_free(ArchitectureKit.gopuram(Vector3(8, 14, 6), 18)),
		auto_free(ArchitectureKit.stairs(Vector3(4, 2, 4), 19)),
		auto_free(ArchitectureKit.rooftop(Vector3(7, 2, 7), 20)),
	]
	return props


func test_every_surface_uses_a_painterly_material_kind() -> void:
	for prop: Node3D in _all_props():
		var visual: MeshInstance3D = _visual(prop)
		assert_object(visual).is_not_null()
		assert_object(visual.material_override).is_null()
		var mesh: ArrayMesh = visual.mesh as ArrayMesh
		assert_int(mesh.get_surface_count()).is_greater(1)
		for s: int in range(mesh.get_surface_count()):
			var kind: StringName = StringName(mesh.surface_get_name(s))
			assert_bool(Materials.has_kind(kind)).is_true()
			assert_object(mesh.surface_get_material(s)).is_same(Materials.get_material(kind))


func test_lanka_is_stone_gold_and_red_lacquer() -> void:
	for prop: Node3D in _all_props():
		var mesh: ArrayMesh = _mesh_of(prop)
		assert_bool(_has_color(mesh, "stone", Palette.STONE)).is_true()
		assert_bool(_has_color(mesh, "gold", Palette.GOLD)).is_true()
		assert_bool(_has_color(mesh, "lacquer", Palette.SINDOOR)).is_true()


func test_every_prop_is_under_the_triangle_budget() -> void:
	for prop: Node3D in _all_props():
		assert_int(_tri_count(_mesh_of(prop))).is_less(BUDGET)


func test_props_are_richly_detailed() -> void:
	var gopuram: Node3D = auto_free(ArchitectureKit.gopuram(Vector3(6, 12, 4), 1))
	var house: Node3D = auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 1))
	var pillar: Node3D = auto_free(ArchitectureKit.pillar(Vector3(1, 5, 1), 1))
	var roof: Node3D = auto_free(ArchitectureKit.rooftop(Vector3(7, 2, 7), 1))
	assert_int(_tri_count(_mesh_of(gopuram))).is_greater(2500)
	assert_int(_tri_count(_mesh_of(house))).is_greater(1500)
	assert_int(_tri_count(_mesh_of(pillar))).is_greater(400)
	assert_int(_tri_count(_mesh_of(roof))).is_greater(800)


func test_gopuram_always_has_seven_tiers() -> void:
	for s: int in range(1, 9):
		var tower: Node3D = auto_free(ArchitectureKit.gopuram(Vector3(6, 12, 4), s))
		var bodies: Array[Node] = _bodies(tower)
		assert_array(bodies).has_size(7)
		var last_width: float = INF
		for body: Node in bodies:
			var shape: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
			assert_float(shape.size.x).is_less(last_width)
			last_width = shape.size.x


func test_gopuram_fills_its_size_and_is_crowned_in_gold() -> void:
	var size: Vector3 = Vector3(6, 12, 4)
	var mesh: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.gopuram(size, 4)) as Node3D)
	var aabb: AABB = mesh.get_aabb()
	assert_float(aabb.size.y).is_equal_approx(size.y, 0.05)
	assert_float(aabb.size.x).is_equal_approx(size.x, 0.1)
	# The topmost geometry (the kalasha finials) is gold.
	var top_gold: float = -INF
	var top_other: float = -INF
	for s: int in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for v: Vector3 in verts:
			if mesh.surface_get_name(s) == "gold":
				top_gold = maxf(top_gold, v.y)
			else:
				top_other = maxf(top_other, v.y)
	assert_float(top_gold).is_greater(top_other)
	assert_float(top_gold).is_equal_approx(size.y * 0.5, 0.02)


func test_gopuram_long_side_may_be_x_or_z() -> void:
	var a: AABB = _mesh_of(auto_free(ArchitectureKit.gopuram(Vector3(6, 12, 4), 4)) as Node3D).get_aabb()
	var b: AABB = _mesh_of(auto_free(ArchitectureKit.gopuram(Vector3(4, 12, 6), 4)) as Node3D).get_aabb()
	assert_float(b.size.x).is_equal_approx(a.size.z, 0.01)
	assert_float(b.size.z).is_equal_approx(a.size.x, 0.01)


func test_wall_fills_its_size_whichever_axis_is_long() -> void:
	for size: Vector3 in [Vector3(2, 3, 6), Vector3(6, 3, 2), Vector3(12, 4, 1)]:
		var wall: Node3D = auto_free(ArchitectureKit.wall(size, 5))
		var aabb: AABB = _mesh_of(wall).get_aabb()
		assert_float(aabb.size.x).is_equal_approx(size.x, 0.01)
		assert_float(aabb.size.y).is_equal_approx(size.y, 0.01)
		assert_float(aabb.size.z).is_equal_approx(size.z, 0.01)
		var shape: BoxShape3D = (_bodies(wall)[0].get_child(0) as CollisionShape3D).shape as BoxShape3D
		assert_vector(shape.size).is_equal_approx(size, Vector3.ONE * 0.001)


func test_tier_house_keeps_one_box_collider_and_reaches_its_height() -> void:
	var size: Vector3 = Vector3(7, 8, 7)
	var house: Node3D = auto_free(ArchitectureKit.tier_house(size, 3))
	var bodies: Array[Node] = _bodies(house)
	assert_array(bodies).has_size(1)
	var shape: BoxShape3D = (bodies[0].get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_vector(shape.size).is_equal_approx(size, Vector3.ONE * 0.001)
	var aabb: AABB = _mesh_of(house).get_aabb()
	assert_float(aabb.size.y).is_equal_approx(size.y, 0.05)
	assert_float(aabb.position.y).is_equal_approx(-size.y * 0.5, 0.01)


func test_tier_house_has_swaying_cloth_banners() -> void:
	var mesh: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.tier_house(Vector3(7, 8, 7), 3)) as Node3D)
	assert_array(_surface_names(mesh)).contains(["cloth"])


func test_rooftop_is_flat_with_awning_pots_and_a_walkable_deck() -> void:
	var size: Vector3 = Vector3(7, 2, 7)
	var roof: Node3D = auto_free(ArchitectureKit.rooftop(size, 6))
	var mesh: ArrayMesh = _mesh_of(roof)
	assert_array(_surface_names(mesh)).contains(["stone", "gold", "lacquer", "cloth", "wood"])
	# Flat roof: one deck collider across the whole footprint, with a level top to walk on.
	var bodies: Array[Node] = _bodies(roof)
	assert_array(bodies).has_size(1)
	var shape_node: CollisionShape3D = bodies[0].get_child(0) as CollisionShape3D
	var shape: BoxShape3D = shape_node.shape as BoxShape3D
	assert_float(shape.size.x).is_equal_approx(size.x, 0.001)
	assert_float(shape.size.z).is_equal_approx(size.z, 0.001)
	assert_vector(shape_node.rotation).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	assert_float(shape_node.position.y - shape.size.y * 0.5).is_equal_approx(-size.y * 0.5, 0.001)
	# Cloth (the awning) carries a wind weight so it sways: some vertex is free, some pinned.
	var free_cloth: bool = false
	var pinned_cloth: bool = false
	for s: int in range(mesh.get_surface_count()):
		if mesh.surface_get_name(s) != "cloth":
			continue
		for c: Color in mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray:
			free_cloth = free_cloth or c.a > 0.8
			pinned_cloth = pinned_cloth or c.a < 0.2
	assert_bool(free_cloth).is_true()
	assert_bool(pinned_cloth).is_true()


func test_stairs_keep_one_collider_per_step() -> void:
	for s: int in range(1, 8):
		var stairs: Node3D = auto_free(ArchitectureKit.stairs(Vector3(4, 2, 4), s))
		assert_int(_bodies(stairs).size()).is_between(4, 6)
		assert_float(_mesh_of(stairs).get_aabb().size.y).is_equal_approx(2.0, 0.05)


func test_pillar_fills_its_height() -> void:
	var pillar: Node3D = auto_free(ArchitectureKit.pillar(Vector3(1, 7, 1), 2))
	var aabb: AABB = _mesh_of(pillar).get_aabb()
	assert_float(aabb.size.y).is_equal_approx(7.0, 0.01)
	assert_float(aabb.size.x).is_less_equal(1.001)
	assert_array(_bodies(pillar)).has_size(1)


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var all: PackedVector3Array = PackedVector3Array()
	for s: int in range(mesh.get_surface_count()):
		all.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return all


func test_different_seeds_give_different_buildings() -> void:
	var a: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 1)) as Node3D)
	var b: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 2)) as Node3D)
	var c: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.rooftop(Vector3(7, 2, 7), 1)) as Node3D)
	var d: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.rooftop(Vector3(7, 2, 7), 2)) as Node3D)
	assert_bool(_vertices(a) == _vertices(b)).is_false()
	assert_bool(_vertices(c) == _vertices(d)).is_false()
	var again: ArrayMesh = _mesh_of(auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 1)) as Node3D)
	assert_bool(_vertices(a) == _vertices(again)).is_true()


func test_metadata_flags_survive() -> void:
	var plain: Node3D = auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 1))
	var marked: Node3D = auto_free(ArchitectureKit.tier_house(Vector3(4, 6, 5), 1, {"flammable": true, "protected": true}))
	assert_bool(plain.get_meta("flammable") as bool).is_false()
	assert_bool(plain.get_meta("protected") as bool).is_false()
	assert_bool(marked.get_meta("flammable") as bool).is_true()
	assert_bool(marked.get_meta("protected") as bool).is_true()
