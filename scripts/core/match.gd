class_name Match
extends RefCounted
## 一局对战的纯逻辑状态机：地图 + 玩家 + 炸弹 + 道具 + 伤害与胜负判定。
##
## 不依赖场景树、Input、Time 或任何渲染 API，因此可以在 headless 下完整单测。

const DEFAULT_FUSE := 2.5
const BLAST_DURATION := 0.45
const POWERUP_DROP_CHANCE := 0.3

var grid: BombGrid
var players: Array[PlayerState] = []
var bombs: Array[Bomb] = []
var powerups: Array[PowerUp] = []
## 当前仍在显示的爆炸格，供渲染层读取。
var blast_cells: Array[Vector2i] = []
var blast_time_left: float = 0.0
var winner_id: int = -1
var is_over: bool = false
## 软方块被炸毁后掉落道具的概率（抽出来便于测试时置 0）。
var powerup_drop_chance: float = POWERUP_DROP_CHANCE

var _rng: RandomNumberGenerator


func _init(p_grid: BombGrid, spawns: Array[Vector2i] = [], rng: RandomNumberGenerator = null) -> void:
	grid = p_grid
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	for i in spawns.size():
		players.append(PlayerState.new(i, spawns[i]))


func player(id: int) -> PlayerState:
	for p in players:
		if p.id == id:
			return p
	return null


func alive_players() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for p in players:
		if p.alive:
			result.append(p)
	return result


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


## 推进一帧逻辑：引信倒计时、爆炸结算、道具拾取、胜负判定。
func tick(delta: float) -> void:
	if is_over:
		return
	for p in players:
		p.tick(delta)
	if blast_time_left > 0.0:
		blast_time_left = maxf(blast_time_left - delta, 0.0)
		if blast_time_left == 0.0:
			blast_cells.clear()
	_detonate_due_bombs(delta)
	_pickup_powerups()
	_check_win()


## 在玩家当前格放置炸弹。成功返回 true。
func place_bomb(player_id: int) -> bool:
	var p := player(player_id)
	if p == null or not p.can_place_bomb():
		return false
	if bomb_at(p.cell) != null:
		return false
	bombs.append(Bomb.new(p.cell, p.id, p.power, DEFAULT_FUSE))
	p.bombs_placed += 1
	return true


## 按格移动玩家。目标格不可通行或已有炸弹时移动失败。
func move_player(player_id: int, direction: Vector2i) -> bool:
	var p := player(player_id)
	if p == null or not p.alive:
		return false
	var target := p.cell + direction
	if not grid.is_walkable(target.x, target.y):
		return false
	if bomb_at(target) != null:
		return false
	p.cell = target
	_pickup_powerups()
	return true


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

	var owner := player(bomb.owner_id)
	if owner != null and owner.bombs_placed > 0:
		owner.bombs_placed -= 1

	var cells := Explosion.blast_cells(grid, bomb.cell, bomb.power)
	blast_cells = _merge_cells(blast_cells, cells)
	blast_time_left = BLAST_DURATION

	for cell in cells:
		if grid.get_kind(cell.x, cell.y) == Tiles.Kind.BLOCK:
			grid.set_kind(cell.x, cell.y, Tiles.Kind.EMPTY)
			if _rng.randf() < powerup_drop_chance:
				_spawn_powerup(cell)
		# 连锁引爆：爆炸范围内的其他炸弹立即爆炸。
		var chained := bomb_at(cell)
		if chained != null:
			_detonate(chained)

	_kill_players_in(cells)


func _kill_players_in(cells: Array[Vector2i]) -> void:
	for p in players:
		if not p.alive or p.has_shield():
			continue
		if cells.has(p.cell):
			p.alive = false
			p.bombs_placed = 0


func _spawn_powerup(cell: Vector2i) -> void:
	if powerup_at(cell) != null:
		return
	var kinds: Array[int] = [
		Tiles.PowerUp.EXTRA_BOMB,
		Tiles.PowerUp.FIRE,
		Tiles.PowerUp.SPEED,
		Tiles.PowerUp.SHIELD,
	]
	powerups.append(PowerUp.new(cell, kinds[_rng.randi_range(0, kinds.size() - 1)]))


func _pickup_powerups() -> void:
	var taken: Array[PowerUp] = []
	for item in powerups:
		for p in players:
			if p.alive and p.cell == item.cell:
				p.apply_powerup(item.kind)
				taken.append(item)
				break
	for item in taken:
		powerups.erase(item)


func _check_win() -> void:
	if players.size() < 2:
		return
	var alive := alive_players()
	if alive.size() <= 1:
		is_over = true
		winner_id = alive[0].id if alive.size() == 1 else -1


func _merge_cells(base: Array[Vector2i], extra: Array[Vector2i]) -> Array[Vector2i]:
	var merged: Array[Vector2i] = []
	merged.append_array(base)
	for cell in extra:
		if not merged.has(cell):
			merged.append(cell)
	return merged
