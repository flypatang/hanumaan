extends GdUnitTestSuite
## Acceptance tests for M15 level data (levels/SCHEMA.md and levels/test_tiny.json).
## The sample level parses, every tile type is valid, and every tile step is a non-negative integer.

const TINY_PATH: String = "res://levels/test_tiny.json"
const VALID_TYPES: Array[String] = ["ground", "water", "stone_floor", "grass", "sand", "wall"]


func _load_tiny() -> Dictionary:
	var file: FileAccess = FileAccess.open(TINY_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	return JSON.parse_string(file.get_as_text()) as Dictionary


func test_sample_level_has_required_keys() -> void:
	var data: Dictionary = _load_tiny()
	assert_str(str(data.get("id", ""))).is_equal("test_tiny")
	for key: String in ["tiles", "props", "spawns", "triggers", "shrines"]:
		assert_bool(data.has(key)).is_true()


func test_every_tile_has_valid_type_and_integer_step() -> void:
	var tiles: Array = _load_tiny()["tiles"] as Array
	assert_int(tiles.size()).is_equal(16)
	for entry: Variant in tiles:
		var tile: Dictionary = entry as Dictionary
		assert_bool(VALID_TYPES.has(str(tile["type"]))).is_true()
		var step: float = (tile["step"] as float)
		assert_float(step).is_equal_approx(roundf(step), 0.0001)
		assert_bool(step >= 0.0).is_true()


func test_sample_level_tile_cells_are_unique() -> void:
	var seen: Dictionary = {}
	for entry: Variant in _load_tiny()["tiles"] as Array:
		var tile: Dictionary = entry as Dictionary
		var key: String = "%d,%d" % [(tile["x"] as int), (tile["z"] as int)]
		assert_bool(seen.has(key)).is_false()
		seen[key] = true
