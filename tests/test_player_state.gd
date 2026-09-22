extends TestCase
## PlayerState：炸弹上限、道具效果与护盾衰减。


func run() -> void:
	_test_bomb_capacity_limit()
	_test_dead_player_cannot_place_bomb()
	_test_powerup_effects()
	_test_caps_are_respected()
	_test_shield_decays()


func _test_bomb_capacity_limit() -> void:
	var p := PlayerState.new(0, Vector2i(1, 1))
	assert_true(p.can_place_bomb(), "初始可以放炸弹")
	p.bombs_placed = 1
	assert_false(p.can_place_bomb(), "已达上限不能再放")


func _test_dead_player_cannot_place_bomb() -> void:
	var p := PlayerState.new(0, Vector2i(1, 1))
	p.alive = false
	assert_false(p.can_place_bomb(), "阵亡后不能放炸弹")


func _test_powerup_effects() -> void:
	var p := PlayerState.new(0, Vector2i.ZERO)
	var base_speed := p.speed
	p.apply_powerup(Tiles.PowerUp.EXTRA_BOMB)
	assert_eq(p.bomb_capacity, PlayerState.DEFAULT_BOMB_CAPACITY + 1, "炸弹数 +1")
	p.apply_powerup(Tiles.PowerUp.FIRE)
	assert_eq(p.power, PlayerState.DEFAULT_POWER + 1, "火力 +1")
	p.apply_powerup(Tiles.PowerUp.SPEED)
	assert_true(p.speed > base_speed, "速度提升")
	p.apply_powerup(Tiles.PowerUp.SHIELD)
	assert_true(p.has_shield(), "获得护盾")


func _test_caps_are_respected() -> void:
	var p := PlayerState.new(0, Vector2i.ZERO)
	for _i in PlayerState.MAX_BOMB_CAPACITY + 5:
		p.apply_powerup(Tiles.PowerUp.EXTRA_BOMB)
	assert_eq(p.bomb_capacity, PlayerState.MAX_BOMB_CAPACITY, "炸弹数不超过上限")
	for _i in PlayerState.MAX_POWER + 5:
		p.apply_powerup(Tiles.PowerUp.FIRE)
	assert_eq(p.power, PlayerState.MAX_POWER, "火力不超过上限")
	for _i in 100:
		p.apply_powerup(Tiles.PowerUp.SPEED)
	assert_almost_eq(p.speed, PlayerState.MAX_SPEED, "速度不超过上限")


func _test_shield_decays() -> void:
	var p := PlayerState.new(0, Vector2i.ZERO)
	p.apply_powerup(Tiles.PowerUp.SHIELD)
	assert_true(p.has_shield(), "刚获得时有无敌")
	p.tick(PlayerState.SHIELD_DURATION + 0.1)
	assert_false(p.has_shield(), "护盾会随时间消失")
