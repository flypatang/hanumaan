extends GdUnitTestSuite
## Acceptance tests for M15 (world/level_builder.gd), DESIGN §9.
## A tiny sample level builds with the expected nodes, the navmesh is not empty, heights come in 0.5 m steps,
## props rotate in 90 degree steps, and triggers and spawns carry their metadata.

const TINY_PATH: String = "res://levels/test_tiny.json"
const WALKABLE_TINY: int = 14


func _load_tiny() -> Dictionary:
	var file: FileAccess = FileAccess.open(TINY_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary


func _level(tiles: Array, props: Array, spawns: Array, triggers: Array, nav: bool) -> Dictionary:
	return {
		"id": "unit_level",
		"nav": nav,
		"tiles": tiles,
		"props": props,
		"spawns": spawns,
		"triggers": triggers,
		"shrines": [],
	}


func _child(root: Node, child_name: String) -> Node:
	return root.get_node_or_null(child_name)


func _region_of(root: Node) -> NavigationRegion3D:
	return _child(root, "NavigationRegion3D") as NavigationRegion3D


func test_tiny_level_has_all_groups() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	assert_object(root).is_not_null()
	for group_name: String in ["Tiles", "Props", "Spawns", "Triggers", "Shrines", "NavigationRegion3D"]:
		assert_object(_child(root, group_name)).is_not_null()


func test_tiny_level_expected_node_counts() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	assert_int(_child(root, "Props").get_child_count()).is_equal(2)
	assert_int(_child(root, "Spawns").get_child_count()).is_equal(2)
	assert_int(_child(root, "Triggers").get_child_count()).is_equal(1)
	assert_int(_child(root, "Shrines").get_child_count()).is_equal(1)


func test_tiles_are_merged_one_mesh_per_type() -> void:
	# Tiny level uses ground, water, stone_floor, grass, sand and wall: six material groups.
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	# (B6 adds the animated water surface "Water_<step>" next to them; it is not a tile mesh.)
	var mesh_count: int = 0
	for child: Node in _child(root, "Tiles").get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Tiles_"):
			mesh_count += 1
	assert_int(mesh_count).is_equal(6)
	assert_object(_child(root, "Tiles").get_node_or_null("Water_0") as MeshInstance3D).is_not_null()


func test_navmesh_is_not_empty_for_tiny_level() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	var region: NavigationRegion3D = _region_of(root)
	assert_object(region.navigation_mesh).is_not_null()
	assert_int(region.navigation_mesh.get_polygon_count()).is_greater(0)
	assert_int(region.navigation_mesh.get_polygon_count()).is_equal(WALKABLE_TINY)


func test_nav_false_bakes_no_navmesh() -> void:
	var tiles: Array = [{"x": 0, "z": 0, "type": "ground", "step": 0}]
	var root: Node3D = LevelBuilder.build(_level(tiles, [], [], [], false))
	auto_free(root)
	var region: NavigationRegion3D = _region_of(root)
	assert_object(region).is_not_null()
	var mesh: NavigationMesh = region.navigation_mesh
	assert_bool(mesh == null or mesh.get_polygon_count() == 0).is_true()


func test_water_and_wall_are_not_walkable() -> void:
	var tiles: Array = [
		{"x": 0, "z": 0, "type": "water", "step": 0},
		{"x": 1, "z": 0, "type": "wall", "step": 0},
		{"x": 2, "z": 0, "type": "sand", "step": 0},
	]
	var root: Node3D = LevelBuilder.build(_level(tiles, [], [], [], true))
	auto_free(root)
	assert_int(_region_of(root).navigation_mesh.get_polygon_count()).is_equal(1)


func test_tile_heights_use_half_metre_steps() -> void:
	# Tile (1, 1) has step 2, so its surface is at y = 1.0. The spawn sits inside that tile.
	var tiles: Array = [{"x": 1, "z": 1, "type": "stone_floor", "step": 2}]
	var spawns: Array = [{"id": "s1", "kind": "player", "pos": [2.5, 2.5], "facing": 0}]
	var root: Node3D = LevelBuilder.build(_level(tiles, [], spawns, [], true))
	auto_free(root)
	var marker: Node3D = _child(root, "Spawns").get_child(0) as Node3D
	assert_float(marker.position.y).is_equal_approx(1.0, 0.001)


func test_spawn_metadata_is_stored() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	var spawn: Node = _child(root, "Spawns").get_child(0)
	assert_str(str(spawn.get_meta("id"))).is_equal("hanuman_start")
	assert_str(str(spawn.get_meta("kind"))).is_equal("player")


func test_prop_rotation_is_in_right_angles() -> void:
	var props: Array = [{"kind": "pillar", "pos": [2.0, 2.0], "rot": 90, "seed": 1, "size": [1.0, 3.0, 1.0]}]
	var tiles: Array = [{"x": 0, "z": 0, "type": "ground", "step": 0}, {"x": 1, "z": 0, "type": "ground", "step": 0}]
	var root: Node3D = LevelBuilder.build(_level(tiles, props, [], [], true))
	auto_free(root)
	var prop: Node3D = _child(root, "Props").get_child(0) as Node3D
	assert_float(prop.rotation.y).is_equal_approx(PI * 0.5, 0.001)


func test_prop_flags_come_from_opts() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	var pillar: Node = _child(root, "Props").get_child(1)
	assert_bool(pillar.get_meta("flammable") as bool).is_true()
	assert_bool(pillar.get_meta("protected") as bool).is_false()


func test_unknown_prop_kind_is_skipped() -> void:
	var props: Array = [{"kind": "no_such_thing", "pos": [0.0, 0.0], "rot": 0, "seed": 1}]
	var tiles: Array = [{"x": 0, "z": 0, "type": "ground", "step": 0}]
	var root: Node3D = LevelBuilder.build(_level(tiles, props, [], [], true))
	auto_free(root)
	assert_int(_child(root, "Props").get_child_count()).is_equal(0)


func test_trigger_is_area_with_box_and_metadata() -> void:
	var root: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(root)
	var area: Area3D = _child(root, "Triggers").get_child(0) as Area3D
	assert_object(area).is_not_null()
	assert_str(str(area.get_meta("on_enter"))).is_equal("intro_seen")
	assert_bool(area.get_meta("once") as bool).is_true()
	var shape_node: CollisionShape3D = area.get_child(0) as CollisionShape3D
	assert_object(shape_node.shape).is_instanceof(BoxShape3D)
	assert_vector((shape_node.shape as BoxShape3D).size).is_equal_approx(Vector3(2.0, 2.0, 2.0), Vector3.ONE * 0.001)


func test_same_level_builds_same_structure_twice() -> void:
	var first: Node3D = LevelBuilder.build(_load_tiny())
	var second: Node3D = LevelBuilder.build(_load_tiny())
	auto_free(first)
	auto_free(second)
	assert_int(first.find_children("*", "", true, false).size()).is_equal(second.find_children("*", "", true, false).size())
	assert_int(_region_of(first).navigation_mesh.get_polygon_count()).is_equal(_region_of(second).navigation_mesh.get_polygon_count())
