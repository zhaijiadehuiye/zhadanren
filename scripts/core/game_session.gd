class_name GameSession
extends RefCounted
## 单人闯关的纯逻辑状态机：地图 + 玩家 + 敌人 + 炸弹 + 道具 + 计时 + 生命 + 计分。
##
## 关卡循环：进入地图 → 炸墙开路 → 拿强化 → 躲敌人与自己的炸弹 → 清掉敌人
##          → 找隐藏在软砖下的出口 → 踩上去进入下一关。
##
## 不依赖场景树、Input、Time 或任何渲染 API，因此可以在 headless 下完整单测。

## 关卡内的大阶段。READY / LEVEL_CLEAR / DYING 是过渡阶段，只倒计时，不推进玩法。
enum Phase {
	READY, ## 开局倒计时：玩家与敌人都冻结，关卡时间不流逝
	PLAYING, ## 正常游玩
	LEVEL_CLEAR, ## 过关结算过渡
	DYING, ## 玩家阵亡过渡，倒计时结束后复活
	GAME_OVER, ## 生命耗尽，或已通关全部关卡
}

const DEFAULT_FUSE := 2.5
const BLAST_DURATION := 0.45
const POWERUP_DROP_CHANCE := 0.3
const LEVEL_CLEAR_DELAY := 1.8
const DYING_DELAY := 1.5
## 开局「准备 → 开始」的倒计时长度。经典炸弹人用这段静止时间让玩家看清地图。
const READY_TIME := 2.0

const SCORE_BLOCK := 10
const SCORE_ENEMY := 200
const SCORE_POWERUP := 50
## 过关时每剩余 1 秒折算的奖励分。
const SCORE_TIME_PER_SECOND := 5

## 视图层消费的事件名（用常量避免拼写漂移）。每帧通过 pop_events() 取走。
const EVENT_EXPLOSION := "explosion"
const EVENT_PLACE_BOMB := "place_bomb"
const EVENT_LEVEL_START := "level_start"
const EVENT_POWERUP := "powerup"
const EVENT_ENEMY_KILLED := "enemy_killed"
const EVENT_PLAYER_HIT := "player_hit"
const EVENT_RESPAWN := "respawn"
const EVENT_EXIT_FOUND := "exit_found"
const EVENT_LEVEL_CLEAR := "level_clear"
const EVENT_GAME_OVER := "game_over"
const EVENT_TIME_UP := "time_up"
const EVENT_PUNCH := "punch"

const ENEMY_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]
## 敌人保持当前方向的概率；越大越爱直行，越小越爱拐弯。
const ENEMY_STRAIGHT_CHANCE := 0.7
## 追击型敌人的「专注」概率：越高越黏人，剩下的概率走神照常游走。
const ENEMY_CHASE_FOCUS := 0.65
## 怯懦型敌人开始躲开玩家的曼哈顿距离。
const ENEMY_SKITTISH_RANGE := 3

var level_index: int = 0
var phase: int = Phase.PLAYING
var grid: BombGrid
var player: PlayerState
var enemies: Array[Enemy] = []
var bombs: Array[Bomb] = []
var powerups: Array[PowerUp] = []
## 当前仍在显示的爆炸格，供渲染层读取。
var blast_cells: Array[Vector2i] = []
var blast_time_left: float = 0.0
var time_left: float = 0.0
## 出口所在格；软砖没被炸掉前不可见也不可通行。
var exit_cell: Vector2i = Vector2i(-1, -1)
var exit_revealed: bool = false
var level_score: int = 0
var total_score: int = 0
## 是否已通关全部关卡（与「生命耗尽」区分开）。
var campaign_cleared: bool = false
## 过渡阶段的剩余时间。
var phase_time_left: float = 0.0
## 软砖被炸毁后掉落道具的概率（抽出来便于测试时置 0 或置 1）。
var powerup_drop_chance: float = POWERUP_DROP_CHANCE
## 待视图层消费的事件队列。
var events: Array[String] = []
## 待视图层消费的「飘分」反馈：{cell: Vector2i, text: String, kind: String}。
var popups: Array[Dictionary] = []

var _rng: RandomNumberGenerator
var _spawn_cell: Vector2i = LevelData.PLAYER_SPAWN


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	player = PlayerState.new(0, LevelData.PLAYER_SPAWN)
	start_level(0)


## 载入指定关卡并重置关卡内的全部临时状态。
## 玩家的成长数值（炸弹数/火力/速度/遥控）与剩余生命跨关保留。
func start_level(p_index: int) -> void:
	level_index = clampi(p_index, 0, LevelData.count() - 1)
	var data := LevelData.build(level_index, _rng)
	grid = data.grid
	_spawn_cell = data.player_spawn
	exit_cell = data.exit_cell
	exit_revealed = false

	enemies.clear()
	var spawns = data.enemy_spawns
	for i in spawns.size():
		var cell: Vector2i = spawns[i]
		enemies.append(Enemy.new(
			i, cell, LevelData.enemy_kind(level_index, i), LevelData.enemy_interval(level_index)
		))

	bombs.clear()
	powerups.clear()
	blast_cells.clear()
	blast_time_left = 0.0
	time_left = LevelData.time_limit(level_index)
	level_score = 0
	phase = Phase.READY
	phase_time_left = READY_TIME
	events.clear()
	popups.clear()

	player.cell = _spawn_cell
	player.alive = true
	player.bombs_placed = 0
	player.facing = Vector2i(0, 1)
	player.shield_time = 0.0


## 从第 1 关重新开始整局（含清空分数与生命）。
func restart_game() -> void:
	player = PlayerState.new(0, LevelData.PLAYER_SPAWN)
	total_score = 0
	level_score = 0
	campaign_cleared = false
	start_level(0)


## 推进一帧逻辑。
func tick(delta: float) -> void:
	match phase:
		Phase.READY:
			# 准备阶段：只走倒计时，玩家、敌人与关卡时间全部冻结。
			phase_time_left = maxf(phase_time_left - delta, 0.0)
			if phase_time_left <= 0.0:
				phase = Phase.PLAYING
				events.append(EVENT_LEVEL_START)
		Phase.PLAYING:
			_tick_playing(delta)
		Phase.LEVEL_CLEAR, Phase.DYING:
			phase_time_left = maxf(phase_time_left - delta, 0.0)
			if phase_time_left <= 0.0:
				_resolve_timeout()
		_:
			pass


## 取走并清空事件队列。
func pop_events() -> Array[String]:
	var drained := events.duplicate()
	events.clear()
	return drained


## 取走并清空飘分队列。
func pop_popups() -> Array[Dictionary]:
	var drained := popups.duplicate()
	popups.clear()
	return drained


func bomb_at(cell: Vector2i) -> Bomb:
	for b in bombs:
		if not b.exploded and b.cell == cell:
			return b
	return null


func powerup_at(cell: Vector2i) -> PowerUp:
	for item in powerups:
		if item.cell == cell:
			return item
	return null


func enemy_at(cell: Vector2i, exclude: Enemy = null) -> Enemy:
	for e in enemies:
		if e.alive and e != exclude and e.cell == cell:
			return e
	return null


func remaining_enemies() -> int:
	var total := 0
	for e in enemies:
		if e.alive:
			total += 1
	return total


## 出口是否已开启：软砖被炸掉显现出来，且场上敌人已清空。
func is_exit_active() -> bool:
	return exit_revealed and exit_cell.x >= 0 and remaining_enemies() == 0


func is_playing() -> bool:
	return phase == Phase.PLAYING


## 只转向不移动。撞墙时也改变朝向，让操作立刻有视觉反馈。
func face(direction: Vector2i) -> void:
	if phase != Phase.PLAYING or not player.alive or direction == Vector2i.ZERO:
		return
	player.facing = direction


## 玩家能否朝该方向走一格。
func can_move(direction: Vector2i) -> bool:
	if phase != Phase.PLAYING or not player.alive or direction == Vector2i.ZERO:
		return false
	var target: Vector2i = player.cell + direction
	if not grid.is_walkable(target.x, target.y):
		return false
	return bomb_at(target) == null


## 朝相邻格移动一格。成功返回 true。
func move_player(direction: Vector2i) -> bool:
	if not can_move(direction):
		return false
	player.cell += direction
	player.facing = direction
	_pickup_powerups()
	if phase == Phase.PLAYING:
		_check_level_clear()
	return true


## 在玩家脚下放一颗炸弹。成功返回 true。
func place_bomb() -> bool:
	if phase != Phase.PLAYING or not player.alive:
		return false
	if not player.can_place_bomb():
		return false
	if bomb_at(player.cell) != null:
		return false
	bombs.append(Bomb.new(
		player.cell, player.id, player.power, DEFAULT_FUSE, player.remote_capable
	))
	player.bombs_placed += 1
	events.append(EVENT_PLACE_BOMB)
	return true


## 拳击手套：把正前方那颗炸弹往朝向推出去，一路滑到被墙、软砖或另一颗炸弹挡住为止；
## 沿途碾到的敌人直接消灭（经典炸弹人的「推炸弹」玩法）。成功出手返回 true。
func punch_bomb() -> bool:
	if phase != Phase.PLAYING or not player.alive or not player.glove:
		return false
	var direction := player.facing
	if direction == Vector2i.ZERO:
		return false
	var start: Vector2i = player.cell + direction
	var bomb := bomb_at(start)
	if bomb == null:
		return false

	var destination := start
	while true:
		var next: Vector2i = destination + direction
		if not grid.is_walkable(next.x, next.y):
			break
		if bomb_at(next) != null:
			break
		destination = next

	if destination != start:
		bomb.cell = destination
		_kill_enemies_in(_path_cells(start, destination, direction), start)

	events.append(EVENT_PUNCH)
	return true


## start 到 destination 之间（含两端）的连续格，用来判定推炸弹沿途碾到了谁。
func _path_cells(start: Vector2i, destination: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var cursor := start
	while cursor != destination:
		cells.append(cursor)
		cursor += direction
	cells.append(destination)
	return cells


## 手动引爆自己所有的遥控炸弹（需先吃到遥控道具）。有炸弹被引爆返回 true。
func detonate_remote() -> bool:
	if phase != Phase.PLAYING or not player.remote_capable:
		return false
	var targets: Array[Bomb] = []
	for b in bombs:
		if b.remote and b.owner_id == player.id:
			targets.append(b)
	if targets.is_empty():
		return false
	for b in targets:
		_detonate(b)
	return true


func _tick_playing(delta: float) -> void:
	player.tick(delta)

	if blast_time_left > 0.0:
		blast_time_left = maxf(blast_time_left - delta, 0.0)
		if blast_time_left <= 0.0:
			blast_cells.clear()

	_detonate_due_bombs(delta)
	if phase != Phase.PLAYING:
		return

	_update_enemies(delta)
	_check_enemy_collision()
	if phase != Phase.PLAYING:
		return

	_pickup_powerups()

	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		events.append(EVENT_TIME_UP)
		_kill_player()
		return

	_check_level_clear()


func _resolve_timeout() -> void:
	if phase == Phase.LEVEL_CLEAR:
		if level_index + 1 >= LevelData.count():
			phase = Phase.GAME_OVER
			campaign_cleared = true
			events.append(EVENT_GAME_OVER)
		else:
			start_level(level_index + 1)
	elif phase == Phase.DYING:
		player.reset_for_respawn(_spawn_cell)
		_recount_bombs()
		phase = Phase.PLAYING
		events.append(EVENT_RESPAWN)


func _detonate_due_bombs(delta: float) -> void:
	var due: Array[Bomb] = []
	for b in bombs:
		if b.tick(delta):
			due.append(b)
	for b in due:
		_detonate(b)


func _detonate(bomb: Bomb) -> void:
	if not bombs.has(bomb):
		return
	bombs.erase(bomb)
	bomb.exploded = true

	if bomb.owner_id == player.id:
		player.bombs_placed = maxi(player.bombs_placed - 1, 0)

	var cells := Explosion.blast_cells(grid, bomb.cell, bomb.power)
	blast_cells = _merge_cells(blast_cells, cells)
	blast_time_left = BLAST_DURATION
	events.append(EVENT_EXPLOSION)

	for cell in cells:
		_destroy_block(cell)
		# 连锁引爆：爆炸范围内的其它炸弹立即爆炸。
		var chained := bomb_at(cell)
		if chained != null:
			_detonate(chained)

	_kill_enemies_in(cells, bomb.cell)
	_hit_player_in(cells)


func _destroy_block(cell: Vector2i) -> void:
	if grid.get_kind(cell.x, cell.y) != Tiles.Kind.BLOCK:
		return
	_add_score(SCORE_BLOCK)
	if cell == exit_cell:
		# 出口显现：变成可通行的出口格，不再掉落道具。
		grid.set_kind(cell.x, cell.y, Tiles.Kind.EXIT)
		exit_revealed = true
		events.append(EVENT_EXIT_FOUND)
		return
	grid.set_kind(cell.x, cell.y, Tiles.Kind.EMPTY)
	if _rng.randf() < powerup_drop_chance:
		_spawn_powerup(cell)


func _spawn_powerup(cell: Vector2i) -> void:
	if powerup_at(cell) != null:
		return
	var kinds: Array[int] = [
		Tiles.PowerUp.EXTRA_BOMB,
		Tiles.PowerUp.FIRE,
		Tiles.PowerUp.SPEED,
		Tiles.PowerUp.SHIELD,
		Tiles.PowerUp.REMOTE,
		Tiles.PowerUp.GLOVE,
	]
	powerups.append(PowerUp.new(cell, kinds[_rng.randi_range(0, kinds.size() - 1)]))


func _pickup_powerups() -> void:
	if not player.alive:
		return
	var taken: Array[PowerUp] = []
	for item in powerups:
		if item.cell == player.cell:
			player.apply_powerup(item.kind)
			_add_score(SCORE_POWERUP)
			taken.append(item)
			events.append(EVENT_POWERUP)
			popups.append({"cell": item.cell, "text": "+%d" % SCORE_POWERUP, "kind": "power"})
	for item in taken:
		powerups.erase(item)


func _update_enemies(delta: float) -> void:
	for e in enemies:
		if not e.alive:
			continue
		if not e.tick(delta):
			continue
		var direction := _pick_enemy_direction(e)
		if direction == Vector2i.ZERO:
			continue
		e.facing = direction
		e.cell += direction


## 敌人选方向：先筛出可走的格子，再按各自的行为原型决定倾向。
func _pick_enemy_direction(e: Enemy) -> Vector2i:
	var options := _enemy_options(e)
	if options.is_empty():
		return Vector2i.ZERO
	match e.behavior:
		Enemy.Behavior.PATROL:
			# 直行到底：只要前方能走就绝不拐弯，路线可预测。
			return e.facing if options.has(e.facing) else _random_option(options)
		Enemy.Behavior.CHASE:
			# 追击：多数时候缩短与玩家的距离，偶尔走神，避免贴脸到无法摆脱。
			if _rng.randf() < ENEMY_CHASE_FOCUS:
				return _closest_to_player(e, options)
			return _straight_or_random(e, options)
		Enemy.Behavior.SKITTISH:
			# 怯懦：玩家贴近时掉头躲开，离得远就照常游走。
			if LevelData.manhattan(e.cell, player.cell) <= ENEMY_SKITTISH_RANGE:
				return _farthest_from_player(e, options)
			return _straight_or_random(e, options)
		_:
			return _straight_or_random(e, options)


## 可走方向：可通行、没有炸弹、也没有其它敌人。
func _enemy_options(e: Enemy) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for d in ENEMY_DIRECTIONS:
		var target: Vector2i = e.cell + d
		if not grid.is_walkable(target.x, target.y):
			continue
		if bomb_at(target) != null:
			continue
		if enemy_at(target, e) != null:
			continue
		options.append(d)
	return options


func _random_option(options: Array[Vector2i]) -> Vector2i:
	return options[_rng.randi_range(0, options.size() - 1)]


## 大概率保持当前方向，避免在路口来回抖动。
func _straight_or_random(e: Enemy, options: Array[Vector2i]) -> Vector2i:
	if options.has(e.facing) and _rng.randf() < ENEMY_STRAIGHT_CHANCE:
		return e.facing
	return _random_option(options)


## 可走方向里离玩家最近的一个；并列时优先保持直行。
func _closest_to_player(e: Enemy, options: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = options[0]
	var best_dist := LevelData.manhattan(e.cell + best, player.cell)
	for d in options:
		var dist := LevelData.manhattan(e.cell + d, player.cell)
		if dist < best_dist or (dist == best_dist and d == e.facing):
			best = d
			best_dist = dist
	return best


## 可走方向里离玩家最远的一个；并列时优先保持直行。
func _farthest_from_player(e: Enemy, options: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = options[0]
	var best_dist := LevelData.manhattan(e.cell + best, player.cell)
	for d in options:
		var dist := LevelData.manhattan(e.cell + d, player.cell)
		if dist > best_dist or (dist == best_dist and d == e.facing):
			best = d
			best_dist = dist
	return best


func _check_enemy_collision() -> void:
	if not player.alive or player.has_shield():
		return
	if enemy_at(player.cell) != null:
		_kill_player()


func _kill_enemies_in(cells: Array[Vector2i], origin: Vector2i) -> void:
	var killed := 0
	for e in enemies:
		if e.alive and cells.has(e.cell):
			e.alive = false
			_add_score(SCORE_ENEMY)
			events.append(EVENT_ENEMY_KILLED)
			popups.append({"cell": e.cell, "text": "+%d" % SCORE_ENEMY, "kind": "kill"})
			killed += 1
	if killed >= 2:
		# 一次爆炸清掉多只敌人：按多杀的数量给连锁奖励，鼓励把敌人聚到一起再炸。
		var bonus := SCORE_ENEMY * (killed - 1)
		_add_score(bonus)
		popups.append({"cell": origin, "text": "连锁 x%d  +%d" % [killed, bonus], "kind": "chain"})


func _hit_player_in(cells: Array[Vector2i]) -> void:
	if not player.alive or player.has_shield():
		return
	if cells.has(player.cell):
		_kill_player()


## 扣一条命；还有命就进入阵亡过渡，没命就结束整局。
func _kill_player() -> void:
	if not player.alive:
		return
	player.alive = false
	player.bombs_placed = 0
	player.lives = maxi(player.lives - 1, 0)
	events.append(EVENT_PLAYER_HIT)
	if player.lives <= 0:
		phase = Phase.GAME_OVER
		events.append(EVENT_GAME_OVER)
	else:
		phase = Phase.DYING
		phase_time_left = DYING_DELAY


## 按场上实际存在的炸弹重新统计额度（复活后调用，避免额度错乱）。
func _recount_bombs() -> void:
	var count := 0
	for b in bombs:
		if not b.exploded and b.owner_id == player.id:
			count += 1
	player.bombs_placed = count


func _check_level_clear() -> void:
	if not is_exit_active():
		return
	if player.cell != exit_cell:
		return
	_add_score(int(time_left) * SCORE_TIME_PER_SECOND)
	phase = Phase.LEVEL_CLEAR
	phase_time_left = LEVEL_CLEAR_DELAY
	events.append(EVENT_LEVEL_CLEAR)


func _add_score(points: int) -> void:
	level_score += points
	total_score += points


func _merge_cells(base: Array[Vector2i], extra: Array[Vector2i]) -> Array[Vector2i]:
	var merged: Array[Vector2i] = []
	merged.append_array(base)
	for cell in extra:
		if not merged.has(cell):
			merged.append(cell)
	return merged
