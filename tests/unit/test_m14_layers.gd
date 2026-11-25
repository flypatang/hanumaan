extends GdUnitTestSuite
## M14 acceptance: physics layer constants and mask helper (core/layers.gd, DESIGN §9 M14).


func test_layer_numbers_match_design() -> void:
	assert_int(Layers.WORLD).is_equal(1)
	assert_int(Layers.PLAYER).is_equal(2)
	assert_int(Layers.ENEMY).is_equal(3)
	assert_int(Layers.PLAYER_HIT).is_equal(4)
	assert_int(Layers.ENEMY_HIT).is_equal(5)
	assert_int(Layers.INTERACT).is_equal(6)
	assert_int(Layers.FIRE).is_equal(7)


func test_mask_of_single_layer_is_its_bit() -> void:
	var layers: Array[int] = [Layers.WORLD]
	assert_int(Layers.mask(layers)).is_equal(1)
	var fire: Array[int] = [Layers.FIRE]
	assert_int(Layers.mask(fire)).is_equal(1 << 6)


func test_mask_combines_layers() -> void:
	var layers: Array[int] = [Layers.PLAYER_HIT, Layers.ENEMY_HIT]
	assert_int(Layers.mask(layers)).is_equal((1 << 3) | (1 << 4))


func test_empty_mask_is_zero() -> void:
	var none: Array[int] = []
	assert_int(Layers.mask(none)).is_equal(0)


func test_team_hit_layers() -> void:
	assert_int(Layers.hit_layer_for_team(&"player")).is_equal(Layers.PLAYER_HIT)
	assert_int(Layers.hit_layer_for_team(&"enemy")).is_equal(Layers.ENEMY_HIT)
	assert_int(Layers.hit_layer_for_team(&"fire")).is_equal(Layers.FIRE)


func test_hurt_mask_excludes_own_team() -> void:
	var own: int = Layers.mask([Layers.PLAYER_HIT])
	assert_int(Layers.hurt_mask_for_team(&"player") & own).is_equal(0)
	var enemy_own: int = Layers.mask([Layers.ENEMY_HIT])
	assert_int(Layers.hurt_mask_for_team(&"enemy") & enemy_own).is_equal(0)
	assert_int(Layers.hurt_mask_for_team(&"player") & Layers.mask([Layers.ENEMY_HIT])).is_not_equal(0)
