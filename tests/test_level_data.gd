extends TestCase
## LevelData：关卡配置与「配置 → 可玩地图」的组装。


func run() -> void:
	_test_config_shape()
	_test_difficulty_progression()
	_test_enemy_kind_uniqueness()
	_test_build_produces_playable_map()
	_test_exit_is_hidden_and_far()
	_test_enemy_spawns_are_safe()
	_test_exit_falls_back_when_no_far_block()
	_test_exit_missing_when_no_block()


func _seeded_rng(seed_value: int = 20240923) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_config_shape() -> void:
	assert_eq(LevelData.count(), 5, "共 5 关")
	for i in LevelData.count():
		var cfg := LevelData.get_level(i)
		assert_true(cfg.has("enemies"), "第 %d 关有敌人数量" % (i + 1))
		assert_true(cfg.has("interval"), "第 %d 关有移动间隔" % (i + 1))
		assert_true(cfg.has("time"), "第 %d 关有时间限制" % (i + 1))
		assert_true(cfg.has("block_chance"), "第 %d 关有软砖密度" % (i + 1))


func _test_difficulty_progression() -> void:
	for i in range(1, LevelData.count()):
		assert_true(
			LevelData.enemy_count(i) > LevelData.enemy_count(i - 1),
			"第 %d 关敌人应比上一关多" % (i + 1)
		)
		assert_true(
			LevelData.enemy_interval(i) < LevelData.enemy_interval(i - 1),
			"第 %d 关敌人应比上一关快" % (i + 1)
		)
		assert_true(
			LevelData.time_limit(i) < LevelData.time_limit(i - 1),
			"第 %d 关时间应比上一关紧" % (i + 1)
		)
	assert_eq(LevelData.enemy_count(0), 2, "第 1 关 2 个敌人")
	assert_eq(LevelData.time_limit(0), 180.0, "第 1 关 180 秒")


func _test_enemy_kind_uniqueness() -> void:
	for level in LevelData.count():
		var seen: Array[int] = []
		for order in LevelData.enemy_count(level):
			var kind := LevelData.enemy_kind(level, order)
			assert_true(kind >= 0 and kind < LevelData.ENEMY_KIND_COUNT, "种类在合法范围内")
			assert_false(seen.has(kind), "第 %d 关内敌人种类不重复" % (level + 1))
			seen.append(kind)


func _test_build_produces_playable_map() -> void:
	for level in LevelData.count():
		var data := LevelData.build(level, _seeded_rng(1000 + level))
		var grid: BombGrid = data.grid
		assert_eq(grid.width, LevelData.WIDTH, "地图宽度")
		assert_eq(grid.height, LevelData.HEIGHT, "地图高度")
		assert_eq(data.player_spawn, LevelData.PLAYER_SPAWN, "玩家出生点固定在左上角")
		assert_eq(
			grid.get_kind(LevelData.PLAYER_SPAWN.x, LevelData.PLAYER_SPAWN.y),
			Tiles.Kind.EMPTY,
			"出生点必须是空地"
		)
		var spawns: Array = data.enemy_spawns
		assert_eq(spawns.size(), LevelData.enemy_count(level), "第 %d 关敌人数" % (level + 1))


func _test_exit_is_hidden_and_far() -> void:
	var rng := _seeded_rng(4242)
	for level in LevelData.count():
		var data := LevelData.build(level, rng)
		var grid: BombGrid = data.grid
		var exit_cell: Vector2i = data.exit_cell
		assert_ne(exit_cell, Vector2i(-1, -1), "第 %d 关应能找到藏出口的软砖" % (level + 1))
		assert_eq(
			grid.get_kind(exit_cell.x, exit_cell.y),
			Tiles.Kind.BLOCK,
			"出口初始必须藏在软砖下面"
		)
		assert_true(
			LevelData.manhattan(exit_cell, LevelData.PLAYER_SPAWN) >= LevelData.EXIT_MIN_DISTANCE,
			"出口要离出生点足够远"
		)


func _test_enemy_spawns_are_safe() -> void:
	var rng := _seeded_rng(777)
	for level in LevelData.count():
		var data := LevelData.build(level, rng)
		var grid: BombGrid = data.grid
		var spawns: Array = data.enemy_spawns
		var exit_cell: Vector2i = data.exit_cell
		for i in spawns.size():
			var cell: Vector2i = spawns[i]
			assert_eq(grid.get_kind(cell.x, cell.y), Tiles.Kind.EMPTY, "敌人只出生在空地")
			assert_true(
				LevelData.manhattan(cell, LevelData.PLAYER_SPAWN) >= LevelData.ENEMY_MIN_DISTANCE,
				"敌人不能贴着玩家出生"
			)
			assert_ne(cell, exit_cell, "敌人不能站在出口上")
			for j in range(i + 1, spawns.size()):
				var other: Vector2i = spawns[j]
				assert_true(
					LevelData.manhattan(cell, other) >= LevelData.ENEMY_MIN_SPACING,
					"敌人之间不能挤在一起"
				)


func _test_exit_falls_back_when_no_far_block() -> void:
	# 只有一块紧邻出生点的软砖：够不到 EXIT_MIN_DISTANCE，应退而取它。
	var grid := BombGrid.from_ascii(PackedStringArray([
		"#####",
		"#.x.#",
		"#####",
	]))
	var exit_cell := LevelData.pick_exit_cell(grid, _seeded_rng(), Vector2i(1, 1))
	assert_eq(exit_cell, Vector2i(2, 1), "没有足够远的软砖时退化为任意软砖")


func _test_exit_missing_when_no_block() -> void:
	var grid := BombGrid.from_ascii(PackedStringArray([
		"#####",
		"#...#",
		"#####",
	]))
	var exit_cell := LevelData.pick_exit_cell(grid, _seeded_rng(), Vector2i(1, 1))
	assert_eq(exit_cell, Vector2i(-1, -1), "地图上没有软砖时没有出口")
