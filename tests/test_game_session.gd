extends TestCase
## GameSession：单人闯关状态机 —— 移动、炸弹、爆炸、敌人、道具、生命、计时、过关。

## 通用测试地图：出生点 (1,1)，右侧 (2,1) 是软砖，(5,2) 是远离爆炸的安全点。
const ROOM := [
	"#######",
	"#.x...#",
	"#.....#",
	"#######",
]
## 空旷地图，用来测敌人移动。
const OPEN := [
	"#######",
	"#.....#",
	"#.....#",
	"#.....#",
	"#######",
]


func run() -> void:
	_test_initial_state()
	_test_ready_countdown_blocks_input()
	_test_move_blocked_by_wall_and_block()
	_test_face_turns_without_moving()
	_test_move_blocked_by_bomb()
	_test_place_bomb_and_capacity()
	_test_bomb_destroys_block_and_scores()
	_test_chain_detonation()
	_test_own_blast_kills_player()
	_test_shield_blocks_blast()
	_test_respawn_after_dying()
	_test_game_over_when_lives_run_out()
	_test_time_up_costs_a_life()
	_test_blast_kills_enemy()
	_test_chain_kill_bonus_and_popups()
	_test_enemy_moves()
	_test_enemy_blocked_by_walls()
	_test_enemy_blocked_by_bomb()
	_test_enemy_contact_kills_player()
	_test_powerup_pickup()
	_test_punch_needs_glove()
	_test_punch_slides_bomb_until_blocked()
	_test_punch_stops_at_wall_and_bomb()
	_test_punch_crushes_enemy_on_path()
	_test_remote_bomb_needs_powerup()
	_test_remote_bomb_manual_detonation()
	_test_exit_revealed_when_its_block_is_destroyed()
	_test_level_clear_requires_enemies_dead()
	_test_level_clear_requires_standing_on_exit()
	_test_next_level_advances()
	_test_campaign_complete_after_last_level()
	_test_restart_game()
	_test_events_are_drained()


func _seeded_rng(seed_value: int = 99) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 造一个完全可控的会话：地图与实体都由测试指定，避免随机关卡干扰断言。
func _session(rows: Array, player_cell: Vector2i = Vector2i(1, 1)) -> GameSession:
	var s := GameSession.new(_seeded_rng())
	s.grid = BombGrid.from_ascii(PackedStringArray(rows))
	s.enemies.clear()
	s.bombs.clear()
	s.powerups.clear()
	s.blast_cells.clear()
	s.blast_time_left = 0.0
	s.exit_cell = Vector2i(-1, -1)
	s.exit_revealed = false
	s.time_left = 100.0
	s.phase = GameSession.Phase.PLAYING
	s.phase_time_left = 0.0
	s.level_index = 0
	s.level_score = 0
	s.total_score = 0
	s.campaign_cleared = false
	s.powerup_drop_chance = 0.0
	s.events.clear()
	s._spawn_cell = player_cell
	s.player.cell = player_cell
	s.player.alive = true
	s.player.bombs_placed = 0
	s.player.shield_time = 0.0
	s.player.lives = PlayerState.DEFAULT_LIVES
	s.player.bomb_capacity = PlayerState.DEFAULT_BOMB_CAPACITY
	s.player.power = PlayerState.DEFAULT_POWER
	s.player.speed = PlayerState.DEFAULT_SPEED
	s.player.remote_capable = false
	s.player.glove = false
	s.player.facing = Vector2i(0, 1)
	return s


func _test_initial_state() -> void:
	var s := GameSession.new(_seeded_rng())
	assert_eq(s.level_index, 0, "开局从第 1 关开始")
	assert_eq(s.phase, GameSession.Phase.READY, "开局先进入准备倒计时")
	assert_eq(s.player.lives, PlayerState.DEFAULT_LIVES, "默认 3 条命")
	assert_eq(s.player.cell, LevelData.PLAYER_SPAWN, "玩家出生在左上角")
	assert_eq(s.enemies.size(), LevelData.enemy_count(0), "敌人数量取自关卡配置")
	assert_eq(s.time_left, LevelData.time_limit(0), "时间取自关卡配置")
	assert_eq(s.remaining_enemies(), LevelData.enemy_count(0), "开局敌人全在")
	assert_false(s.exit_revealed, "开局出口是隐藏的")
	assert_false(s.is_exit_active(), "开局出口未开启")


func _test_ready_countdown_blocks_input() -> void:
	var s := GameSession.new(_seeded_rng())
	assert_false(s.is_playing(), "准备倒计时期间不算游玩中")
	assert_false(s.move_player(Vector2i(0, 1)), "倒计时期间不能移动")
	assert_false(s.place_bomb(), "倒计时期间不能放炸弹")
	assert_eq(s.player.cell, LevelData.PLAYER_SPAWN, "倒计时期间位置不变")

	var before := s.time_left
	s.tick(GameSession.READY_TIME - 0.01)
	assert_eq(s.phase, GameSession.Phase.READY, "倒计时没走完仍是准备阶段")
	assert_eq(s.time_left, before, "准备阶段不消耗关卡时间")
	assert_false(s.events.has(GameSession.EVENT_LEVEL_START), "倒计时期间不发开局事件")

	s.tick(0.02)
	assert_eq(s.phase, GameSession.Phase.PLAYING, "倒计时结束进入游玩阶段")
	assert_true(s.events.has(GameSession.EVENT_LEVEL_START), "发出开局事件")
	assert_true(s.is_playing(), "此时才算游玩中")
	assert_true(s.move_player(Vector2i(0, 1)), "开始后可以移动")


func _test_move_blocked_by_wall_and_block() -> void:
	var s := _session(ROOM)
	assert_false(s.move_player(Vector2i(-1, 0)), "不能走进左边界硬墙")
	assert_false(s.move_player(Vector2i(0, -1)), "不能走进上边界硬墙")
	assert_false(s.move_player(Vector2i(1, 0)), "不能走进软砖")
	assert_eq(s.player.cell, Vector2i(1, 1), "被挡住时位置不变")
	assert_true(s.can_move(Vector2i(0, 1)), "下方是空地，可以走")
	assert_true(s.move_player(Vector2i(0, 1)), "向下移动成功")
	assert_eq(s.player.cell, Vector2i(1, 2), "位置更新")
	assert_eq(s.player.facing, Vector2i(0, 1), "朝向更新")
	assert_false(s.move_player(Vector2i.ZERO), "零向量不是合法移动")


func _test_face_turns_without_moving() -> void:
	var s := _session(ROOM)
	assert_eq(s.player.facing, Vector2i(0, 1), "初始朝下")
	s.face(Vector2i(-1, 0))
	assert_eq(s.player.facing, Vector2i(-1, 0), "撞墙方向也能立刻转身")
	assert_eq(s.player.cell, Vector2i(1, 1), "转向不改变位置")
	s.face(Vector2i.ZERO)
	assert_eq(s.player.facing, Vector2i(-1, 0), "零向量不改变朝向")
	s.phase = GameSession.Phase.GAME_OVER
	s.face(Vector2i(1, 0))
	assert_eq(s.player.facing, Vector2i(-1, 0), "非游玩阶段不允许转向")


func _test_move_blocked_by_bomb() -> void:
	var s := _session(ROOM)
	assert_true(s.place_bomb(), "在脚下放炸弹")
	assert_true(s.move_player(Vector2i(0, 1)), "可以走出自己刚放的炸弹格")
	assert_false(s.move_player(Vector2i(0, -1)), "不能走回有炸弹的格子")
	assert_eq(s.player.cell, Vector2i(1, 2), "位置停在被挡住之前")


func _test_place_bomb_and_capacity() -> void:
	var s := _session(ROOM)
	assert_eq(s.player.bomb_capacity, 1, "初始只能带 1 颗炸弹")
	assert_true(s.place_bomb(), "第一颗炸弹放下成功")
	assert_eq(s.bombs.size(), 1, "场上有 1 颗炸弹")
	assert_eq(s.player.bombs_placed, 1, "额度被占用")
	assert_false(s.place_bomb(), "同一格不能叠放炸弹")
	s.player.bomb_capacity = 2
	assert_false(s.place_bomb(), "同一格即使有额度也不能叠放")
	assert_true(s.move_player(Vector2i(0, 1)), "走开")
	assert_true(s.place_bomb(), "有了第二份额度就能再放一颗")
	assert_eq(s.bombs.size(), 2, "场上有 2 颗炸弹")
	assert_false(s.place_bomb(), "额度用尽后不能再放")


func _test_bomb_destroys_block_and_scores() -> void:
	var s := _session(ROOM)
	assert_true(s.place_bomb(), "放炸弹")
	s.player.cell = Vector2i(5, 2)  # 移出爆炸范围，只验证地形与计分
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.bombs.size(), 0, "引信到点后炸弹消失")
	assert_eq(s.grid.get_kind(2, 1), Tiles.Kind.EMPTY, "软砖被炸毁变成空地")
	assert_eq(s.level_score, GameSession.SCORE_BLOCK, "炸毁软砖得分")
	assert_eq(s.total_score, GameSession.SCORE_BLOCK, "总分同步累加")
	assert_true(s.blast_cells.has(Vector2i(1, 1)), "爆炸覆盖原点")
	assert_true(s.blast_cells.has(Vector2i(2, 1)), "爆炸覆盖软砖格")
	assert_false(s.blast_cells.has(Vector2i(0, 1)), "硬墙挡住爆炸")
	assert_eq(s.player.bombs_placed, 0, "爆炸后归还额度")


func _test_chain_detonation() -> void:
	var s := _session(ROOM)
	s.bombs.append(Bomb.new(Vector2i(1, 2), 0, 1, 99.0))
	assert_true(s.place_bomb(), "在 (1,1) 放炸弹")
	s.player.cell = Vector2i(5, 2)
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.bombs.size(), 0, "相邻的炸弹被连锁引爆")


func _test_own_blast_kills_player() -> void:
	var s := _session(ROOM)
	assert_true(s.place_bomb(), "放炸弹")
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.player.lives, 2, "被自己的炸弹炸掉一条命")
	assert_false(s.player.alive, "玩家阵亡")
	assert_eq(s.phase, GameSession.Phase.DYING, "进入阵亡过渡")


func _test_shield_blocks_blast() -> void:
	var s := _session(ROOM)
	s.player.shield_time = 30.0
	assert_true(s.place_bomb(), "放炸弹")
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.player.lives, PlayerState.DEFAULT_LIVES, "护盾期间不掉命")
	assert_true(s.player.alive, "护盾期间不会死")
	assert_eq(s.phase, GameSession.Phase.PLAYING, "仍在游玩阶段")


func _test_respawn_after_dying() -> void:
	var s := _session(ROOM)
	s.player.bomb_capacity = 3
	s.player.power = 4
	assert_true(s.place_bomb(), "在脚下放炸弹并且不躲开")
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.phase, GameSession.Phase.DYING, "先进入阵亡过渡")
	s.tick(GameSession.DYING_DELAY + 0.01)
	assert_eq(s.phase, GameSession.Phase.PLAYING, "过渡结束后回到游玩")
	assert_true(s.player.alive, "复活")
	assert_eq(s.player.cell, Vector2i(1, 1), "回到出生点")
	assert_true(s.player.shield_time > 0.0, "复活带一段无敌时间")
	assert_eq(s.player.bomb_capacity, 3, "复活保留炸弹额度成长")
	assert_eq(s.player.power, 4, "复活保留火力成长")


func _test_game_over_when_lives_run_out() -> void:
	var s := _session(ROOM)
	s.player.lives = 1
	assert_true(s.place_bomb(), "放炸弹")
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_eq(s.player.lives, 0, "命扣光")
	assert_eq(s.phase, GameSession.Phase.GAME_OVER, "生命耗尽后整局结束")


func _test_time_up_costs_a_life() -> void:
	var s := _session(ROOM)
	s.time_left = 0.01
	s.tick(0.05)
	assert_eq(s.player.lives, 2, "时间耗尽扣一条命")
	assert_eq(s.phase, GameSession.Phase.DYING, "进入阵亡过渡")
	assert_true(s.events.has(GameSession.EVENT_TIME_UP), "发出超时事件")


func _test_blast_kills_enemy() -> void:
	var s := _session(ROOM)
	var e := Enemy.new(0, Vector2i(1, 2), 0, 0.7)
	s.enemies.append(e)
	assert_true(s.place_bomb(), "放炸弹")
	s.player.cell = Vector2i(5, 2)
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_false(e.alive, "被火焰覆盖的敌人阵亡")
	assert_eq(s.remaining_enemies(), 0, "场上敌人清空")
	assert_eq(s.level_score, GameSession.SCORE_BLOCK + GameSession.SCORE_ENEMY, "击杀敌人得分")


func _test_chain_kill_bonus_and_popups() -> void:
	# 一次爆炸同时清掉两只敌人：除基础分外还有连锁奖励。
	var s := _session(OPEN)
	var first := Enemy.new(0, Vector2i(2, 1), 0, 99.0)
	var second := Enemy.new(1, Vector2i(1, 2), 0, 99.0)
	s.enemies.append(first)
	s.enemies.append(second)
	assert_true(s.place_bomb(), "在 (1,1) 放炸弹")
	s.player.cell = Vector2i(5, 2)
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_false(first.alive, "第一只敌人阵亡")
	assert_false(second.alive, "第二只敌人阵亡")
	assert_eq(
		s.level_score,
		GameSession.SCORE_ENEMY * 2 + GameSession.SCORE_ENEMY,
		"两连杀拿到额外连锁奖励"
	)

	var popups := s.pop_popups()
	assert_eq(popups.size(), 3, "两只敌人各一条飘分，外加一条连锁提示")
	assert_true(popups.any(func(p): return p["kind"] == "chain"), "存在连锁提示")
	assert_eq(s.pop_popups().size(), 0, "取走后飘分队列清空")


func _test_enemy_moves() -> void:
	var s := _session(OPEN)
	var e := Enemy.new(0, Vector2i(3, 3), 0, 0.1)
	s.enemies.append(e)
	s.tick(0.15)
	assert_ne(e.cell, Vector2i(3, 3), "敌人会自己走动")
	assert_eq(
		LevelData.manhattan(e.cell, Vector2i(3, 3)), 1,
		"一次只走一格"
	)


func _test_enemy_blocked_by_walls() -> void:
	var s := _session([
		"#####",
		"#.#.#",
		"#####",
	], Vector2i(3, 1))
	var e := Enemy.new(0, Vector2i(1, 1), 0, 0.1)
	s.enemies.append(e)
	s.tick(0.5)
	assert_eq(e.cell, Vector2i(1, 1), "四面都是墙时原地不动")


func _test_enemy_blocked_by_bomb() -> void:
	var s := _session([
		"####",
		"#..#",
		"####",
	], Vector2i(1, 1))
	var e := Enemy.new(0, Vector2i(1, 1), 0, 0.1)
	s.enemies.append(e)
	# 敌人唯一的出路被炸弹堵死。
	s.bombs.append(Bomb.new(Vector2i(2, 1), 0, 1, 99.0))
	s.player.shield_time = 30.0  # 避免被贴身敌人直接判定死亡，干扰断言
	s.tick(0.5)
	assert_eq(e.cell, Vector2i(1, 1), "炸弹挡住去路时敌人不动")


func _test_enemy_contact_kills_player() -> void:
	var s := _session(ROOM)
	var e := Enemy.new(0, Vector2i(1, 1), 0, 5.0)
	s.enemies.append(e)
	s.tick(0.05)
	assert_eq(s.player.lives, 2, "碰到敌人扣一条命")
	assert_eq(s.phase, GameSession.Phase.DYING, "进入阵亡过渡")


func _test_powerup_pickup() -> void:
	var s := _session(ROOM)
	s.powerups.append(PowerUp.new(Vector2i(1, 1), Tiles.PowerUp.FIRE))
	s.tick(0.05)
	assert_eq(s.player.power, PlayerState.DEFAULT_POWER + 1, "火力提升")
	assert_eq(s.powerups.size(), 0, "道具被拾取后从地图移除")
	assert_eq(s.level_score, GameSession.SCORE_POWERUP, "拾取道具得分")


func _test_punch_needs_glove() -> void:
	var s := _session(OPEN)
	s.bombs.append(Bomb.new(Vector2i(2, 1), 0, 1, 99.0))
	s.player.facing = Vector2i(1, 0)
	assert_false(s.punch_bomb(), "没吃到拳击手套时推不动炸弹")
	assert_eq(s.bombs[0].cell, Vector2i(2, 1), "炸弹原地不动")

	s.player.glove = true
	assert_true(s.punch_bomb(), "拿到手套后可以推炸弹")
	assert_eq(s.bombs[0].cell, Vector2i(5, 1), "炸弹被推到通道尽头")
	assert_true(s.events.has(GameSession.EVENT_PUNCH), "发出出拳事件")

	s.player.cell = Vector2i(1, 3)
	s.player.facing = Vector2i(0, -1)
	assert_false(s.punch_bomb(), "正前方没有炸弹时出拳无效")


func _test_punch_slides_bomb_until_blocked() -> void:
	var s := _session([
		"#########",
		"#.......#",
		"#.....x.#",
		"#########",
	], Vector2i(1, 2))
	s.player.glove = true
	s.player.facing = Vector2i(1, 0)
	s.bombs.append(Bomb.new(Vector2i(2, 2), 0, 1, 99.0))
	assert_true(s.punch_bomb(), "推炸弹")
	assert_eq(s.bombs[0].cell, Vector2i(5, 2), "一路滑到软砖前停住")


func _test_punch_stops_at_wall_and_bomb() -> void:
	var s := _session(OPEN)
	s.player.glove = true
	s.player.facing = Vector2i(1, 0)
	s.bombs.append(Bomb.new(Vector2i(2, 1), 0, 1, 99.0))
	# 前面还堵着一颗炸弹：只能滑到它前面一格，不能叠在一起。
	s.bombs.append(Bomb.new(Vector2i(4, 1), 0, 1, 99.0))
	assert_true(s.punch_bomb(), "推炸弹")
	assert_eq(s.bombs[0].cell, Vector2i(3, 1), "被另一颗炸弹挡住就停下")

	# 贴着右墙的炸弹推不动，但仍然算一次出拳（给音效反馈）。
	var wall := _session(OPEN)
	wall.player.glove = true
	wall.player.cell = Vector2i(4, 1)
	wall.player.facing = Vector2i(1, 0)
	wall.bombs.append(Bomb.new(Vector2i(5, 1), 0, 1, 99.0))
	assert_true(wall.punch_bomb(), "贴墙时依然算出拳")
	assert_eq(wall.bombs[0].cell, Vector2i(5, 1), "贴墙的炸弹不动")


func _test_punch_crushes_enemy_on_path() -> void:
	var s := _session(OPEN)
	s.player.glove = true
	s.player.facing = Vector2i(1, 0)
	s.bombs.append(Bomb.new(Vector2i(2, 1), 0, 1, 99.0))
	var e := Enemy.new(0, Vector2i(4, 1), 0, 99.0)
	s.enemies.append(e)
	assert_true(s.punch_bomb(), "推炸弹")
	assert_eq(s.bombs[0].cell, Vector2i(5, 1), "炸弹滑到底")
	assert_false(e.alive, "被推的炸弹沿途碾死敌人")
	assert_eq(s.level_score, GameSession.SCORE_ENEMY, "碾死敌人同样得分")


func _test_remote_bomb_needs_powerup() -> void:
	var s := _session(ROOM)
	assert_false(s.detonate_remote(), "没吃到遥控道具时无法手动引爆")


func _test_remote_bomb_manual_detonation() -> void:
	var s := _session(ROOM)
	s.player.remote_capable = true
	assert_true(s.place_bomb(), "放一颗遥控炸弹")
	assert_true(s.bombs[0].remote, "吃到遥控道具后放的炸弹是遥控炸弹")
	s.player.cell = Vector2i(5, 2)
	s.tick(GameSession.DEFAULT_FUSE + 5.0)
	assert_eq(s.bombs.size(), 1, "遥控炸弹不会自己爆炸")
	assert_true(s.detonate_remote(), "手动引爆成功")
	assert_eq(s.bombs.size(), 0, "炸弹被引爆")
	assert_true(s.blast_cells.has(Vector2i(1, 1)), "产生爆炸")
	assert_false(s.detonate_remote(), "没有遥控炸弹时返回 false")


func _test_exit_revealed_when_its_block_is_destroyed() -> void:
	var s := _session(ROOM)
	s.exit_cell = Vector2i(2, 1)
	# 留一个远离爆炸、且慢到不会动的敌人，用来验证「出口显现 ≠ 出口开启」。
	s.enemies.append(Enemy.new(0, Vector2i(5, 1), 0, 9.0))
	assert_true(s.place_bomb(), "放炸弹")
	s.player.cell = Vector2i(5, 2)
	s.tick(GameSession.DEFAULT_FUSE + 0.1)
	assert_true(s.exit_revealed, "出口显现")
	assert_eq(s.grid.get_kind(2, 1), Tiles.Kind.EXIT, "软砖位置变成出口")
	assert_true(s.grid.is_walkable(2, 1), "出口可以走上去")
	assert_true(s.events.has(GameSession.EVENT_EXIT_FOUND), "发出发现出口事件")
	assert_false(s.is_exit_active(), "敌人没清完时出口未开启")


func _test_level_clear_requires_enemies_dead() -> void:
	var s := _session([
		"#######",
		"#.E...#",
		"#.....#",
		"#######",
	])
	s.exit_cell = Vector2i(2, 1)
	s.exit_revealed = true
	var e := Enemy.new(0, Vector2i(5, 2), 0, 5.0)
	s.enemies.append(e)
	s.player.cell = Vector2i(2, 1)
	s.tick(0.05)
	assert_eq(s.phase, GameSession.Phase.PLAYING, "还有敌人时踩出口不过关")
	e.alive = false
	s.tick(0.05)
	assert_eq(s.phase, GameSession.Phase.LEVEL_CLEAR, "敌人清空后踩出口过关")


func _test_level_clear_requires_standing_on_exit() -> void:
	var s := _session([
		"#######",
		"#.E...#",
		"#.....#",
		"#######",
	])
	s.exit_cell = Vector2i(2, 1)
	s.exit_revealed = true
	s.player.cell = Vector2i(1, 1)
	s.tick(0.05)
	assert_eq(s.phase, GameSession.Phase.PLAYING, "没站到出口上不过关")
	assert_true(s.is_exit_active(), "敌人清空且出口显现时出口是开启的")


func _test_next_level_advances() -> void:
	var s := _session([
		"#######",
		"#.E...#",
		"#######",
	])
	s.exit_cell = Vector2i(2, 1)
	s.exit_revealed = true
	s.player.cell = Vector2i(2, 1)
	s.tick(0.05)
	assert_eq(s.phase, GameSession.Phase.LEVEL_CLEAR, "过关")
	assert_true(s.level_score > 0, "过关拿到时间奖励分")
	s.tick(GameSession.LEVEL_CLEAR_DELAY + 0.01)
	assert_eq(s.level_index, 1, "进入第 2 关")
	assert_eq(s.phase, GameSession.Phase.READY, "新关卡重新进入准备倒计时")
	assert_eq(s.phase_time_left, GameSession.READY_TIME, "准备倒计时从满开始")
	assert_eq(s.enemies.size(), LevelData.enemy_count(1), "第 2 关敌人数量正确")
	assert_eq(s.time_left, LevelData.time_limit(1), "第 2 关时间重置")
	assert_false(s.exit_revealed, "新关卡出口重新隐藏")
	assert_eq(s.level_score, 0, "新关卡关卡分数清零")
	assert_true(s.total_score > 0, "总分跨关累计")
	s.tick(GameSession.READY_TIME + 0.01)
	assert_eq(s.phase, GameSession.Phase.PLAYING, "倒计时结束后开始第 2 关")


func _test_campaign_complete_after_last_level() -> void:
	var s := _session([
		"#######",
		"#.E...#",
		"#######",
	])
	s.level_index = LevelData.count() - 1
	s.exit_cell = Vector2i(2, 1)
	s.exit_revealed = true
	s.player.cell = Vector2i(2, 1)
	s.tick(0.05)
	assert_eq(s.phase, GameSession.Phase.LEVEL_CLEAR, "最后一关过关")
	s.tick(GameSession.LEVEL_CLEAR_DELAY + 0.01)
	assert_eq(s.phase, GameSession.Phase.GAME_OVER, "通关后整局结束")
	assert_true(s.campaign_cleared, "标记为已通关")
	assert_true(s.player.lives > 0, "通关不是因生命耗尽")


func _test_restart_game() -> void:
	var s := _session(ROOM)
	s.total_score = 999
	s.player.lives = 1
	s.player.power = 5
	s.level_index = 3
	s.restart_game()
	assert_eq(s.total_score, 0, "总分清零")
	assert_eq(s.level_score, 0, "关卡分清零")
	assert_eq(s.player.lives, PlayerState.DEFAULT_LIVES, "生命恢复")
	assert_eq(s.player.power, PlayerState.DEFAULT_POWER, "成长数值重置")
	assert_eq(s.level_index, 0, "回到第 1 关")
	assert_eq(s.phase, GameSession.Phase.READY, "重开后回到准备倒计时")
	assert_false(s.campaign_cleared, "清除通关标记")


func _test_events_are_drained() -> void:
	var s := _session(ROOM)
	assert_true(s.place_bomb(), "放炸弹")
	assert_true(s.events.has(GameSession.EVENT_PLACE_BOMB), "产生放炸弹事件")
	var drained := s.pop_events()
	assert_true(drained.has(GameSession.EVENT_PLACE_BOMB), "取到事件")
	assert_eq(s.events.size(), 0, "取走后队列清空")
	assert_eq(s.pop_events().size(), 0, "再次取走为空")
