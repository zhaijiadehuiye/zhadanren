extends TestCase
## Match：放炸弹、爆炸结算、摧毁软方块、连锁引爆、道具拾取与胜负判定。


func run() -> void:
	_test_place_bomb_respects_capacity()
	_test_cannot_stack_bombs_on_same_cell()
	_test_move_is_blocked_by_wall_and_bomb()
	_test_blast_destroys_block()
	_test_blast_kills_player()
	_test_shield_blocks_damage()
	_test_chain_reaction()
	_test_pickup_powerup()
	_test_win_detection()


func _make_match(rows: PackedStringArray, a: Vector2i, b: Vector2i) -> Match:
	var spawns: Array[Vector2i] = [a, b]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var m := Match.new(BombGrid.from_ascii(rows), spawns, rng)
	# 默认关闭掉落，避免随机道具干扰断言；需要时由用例单独打开。
	m.powerup_drop_chance = 0.0
	return m


func _open_rows(w: int, h: int = 1) -> PackedStringArray:
	var rows := PackedStringArray()
	for _i in h:
		rows.append(".".repeat(w))
	return rows


func _test_place_bomb_respects_capacity() -> void:
	var m := _make_match(_open_rows(5), Vector2i(1, 0), Vector2i(3, 0))
	assert_eq(m.player(0).bomb_capacity, 1, "初始炸弹数上限为 1")
	assert_true(m.place_bomb(0), "第一次放置成功")
	assert_false(m.place_bomb(0), "超出上限后放置失败")
	assert_eq(m.bombs.size(), 1, "场上只有一颗炸弹")


func _test_cannot_stack_bombs_on_same_cell() -> void:
	var m := _make_match(_open_rows(5), Vector2i(1, 0), Vector2i(3, 0))
	m.player(0).bomb_capacity = 3
	assert_true(m.place_bomb(0), "首次放置成功")
	assert_false(m.place_bomb(0), "同一格不能重复放置")


func _test_move_is_blocked_by_wall_and_bomb() -> void:
	var m := _make_match(PackedStringArray(["#..."]), Vector2i(1, 0), Vector2i(3, 0))
	assert_false(m.move_player(0, Vector2i(-1, 0)), "撞硬墙不能移动")
	assert_true(m.move_player(0, Vector2i(1, 0)), "空地可以移动")
	assert_eq(m.player(0).cell, Vector2i(2, 0), "位置已更新")
	m.place_bomb(0)
	assert_true(m.move_player(0, Vector2i(1, 0)), "可以离开自己刚放的炸弹")
	assert_eq(m.player(0).cell, Vector2i(3, 0), "已走到右侧")
	assert_false(m.move_player(0, Vector2i(-1, 0)), "不能走回已有炸弹的格子")


func _test_blast_destroys_block() -> void:
	var m := _make_match(PackedStringArray([
		".x...",
		".....",
	]), Vector2i(0, 0), Vector2i(4, 1))
	assert_eq(m.grid.get_kind(1, 0), Tiles.Kind.BLOCK, "初始有软方块")
	m.place_bomb(0)
	m.tick(Match.DEFAULT_FUSE + 0.1)
	assert_eq(m.grid.get_kind(1, 0), Tiles.Kind.EMPTY, "软方块被炸掉")
	assert_true(m.blast_cells.has(Vector2i(1, 0)), "爆炸覆盖软方块所在格")


func _test_blast_kills_player() -> void:
	var m := _make_match(_open_rows(5), Vector2i(0, 0), Vector2i(4, 0))
	m.place_bomb(0)
	m.tick(Match.DEFAULT_FUSE + 0.1)
	assert_false(m.player(0).alive, "站在炸弹上的玩家被炸死")
	assert_true(m.player(1).alive, "火力范围外的玩家存活")


func _test_shield_blocks_damage() -> void:
	var m := _make_match(_open_rows(5), Vector2i(1, 0), Vector2i(2, 0))
	m.player(1).apply_powerup(Tiles.PowerUp.SHIELD)
	m.place_bomb(0)
	m.tick(Match.DEFAULT_FUSE + 0.1)
	assert_true(m.player(1).alive, "护盾期间不受伤害")
	assert_false(m.player(0).alive, "无护盾的玩家仍然被炸死")


func _test_chain_reaction() -> void:
	var m := _make_match(_open_rows(7), Vector2i(0, 0), Vector2i(6, 0))
	var p0 := m.player(0)
	var p1 := m.player(1)
	p0.bomb_capacity = 2
	p1.bomb_capacity = 2
	p0.cell = Vector2i(2, 0)
	p1.cell = Vector2i(3, 0)
	assert_true(m.place_bomb(0), "P1 放炸弹")
	assert_true(m.place_bomb(1), "P2 放炸弹")
	assert_eq(m.bombs.size(), 2, "场上有两颗相邻炸弹")
	# 让第二颗先爆，通过连锁把第一颗也带走。
	m.bombs[1].fuse = 0.1
	m.tick(0.2)
	assert_eq(m.bombs.size(), 0, "连锁反应应引爆全部炸弹")
	assert_true(m.blast_cells.has(Vector2i(3, 0)), "后爆的炸弹位置也被覆盖")


func _test_pickup_powerup() -> void:
	var m := _make_match(_open_rows(5), Vector2i(0, 0), Vector2i(4, 0))
	m.powerups.append(PowerUp.new(Vector2i(1, 0), Tiles.PowerUp.FIRE))
	var before := m.player(0).power
	assert_true(m.move_player(0, Vector2i(1, 0)), "可以移动到道具格")
	assert_eq(m.player(0).power, before + 1, "拾取后火力提升")
	assert_eq(m.powerups.size(), 0, "道具被拾取后从场上移除")


func _test_win_detection() -> void:
	var m := _make_match(_open_rows(5), Vector2i(0, 0), Vector2i(4, 0))
	assert_false(m.is_over, "开局对局未结束")
	m.place_bomb(0)
	m.tick(Match.DEFAULT_FUSE + 0.1)
	assert_true(m.is_over, "只剩一名存活玩家时对局结束")
	assert_eq(m.winner_id, 1, "幸存者获胜")
