class_name LevelData
extends RefCounted
## 单人闯关的关卡配置，以及「配置 → 可玩地图」的组装。
##
## 依赖方向是单向的：LevelData → Level（用到 Level 的经典布局生成），Level 不反向依赖本文件。

const WIDTH := Level.DEFAULT_WIDTH
const HEIGHT := Level.DEFAULT_HEIGHT

## 5 个关卡，难度递进：敌人更多、更快，软砖更密（可躲藏的空地更少），时间更紧。
const LEVELS: Array[Dictionary] = [
	{"enemies": 2, "interval": 0.85, "time": 180.0, "block_chance": 0.62},
	{"enemies": 3, "interval": 0.75, "time": 170.0, "block_chance": 0.66},
	{"enemies": 4, "interval": 0.66, "time": 160.0, "block_chance": 0.70},
	{"enemies": 5, "interval": 0.58, "time": 150.0, "block_chance": 0.72},
	{"enemies": 6, "interval": 0.50, "time": 140.0, "block_chance": 0.75},
]

## 敌人贴图种类数，与 assets 里准备的怪物图数量一致。
const ENEMY_KIND_COUNT := 6
## 出口至少要离出生点多远（曼哈顿距离），逼玩家真的去炸开地图探索。
const EXIT_MIN_DISTANCE := 6
## 敌人出生点离玩家的最小距离，避免开局就贴脸。
const ENEMY_MIN_DISTANCE := 5
## 敌人之间的最小间距，避免叠在一起。
const ENEMY_MIN_SPACING := 2
## 玩家出生点。
const PLAYER_SPAWN := Vector2i(1, 1)


static func count() -> int:
	return LEVELS.size()


## 取某一关的配置，越界时夹到合法范围。
static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


static func time_limit(index: int) -> float:
	return get_level(index).time


static func enemy_interval(index: int) -> float:
	return get_level(index).interval


static func enemy_count(index: int) -> int:
	return get_level(index).enemies


## 给第 index 关的第 order 个敌人分配贴图种类；同一关内保证不重复。
static func enemy_kind(index: int, order: int) -> int:
	return (index + order) % ENEMY_KIND_COUNT


## 组装一关：生成地图、藏好出口、挑出敌人出生点。
##
## 返回 `{grid, player_spawn, exit_cell, enemy_spawns}`。
static func build(index: int, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := get_level(index)
	var grid := Level.classic(WIDTH, HEIGHT, [PLAYER_SPAWN], rng, cfg.block_chance)
	return {
		"grid": grid,
		"player_spawn": PLAYER_SPAWN,
		"exit_cell": pick_exit_cell(grid, rng, PLAYER_SPAWN),
		"enemy_spawns": pick_enemy_spawns(grid, rng, PLAYER_SPAWN, cfg.enemies),
	}


## 出口藏在离出生点足够远的软砖下面。找不到足够远的就退而求其次取任意软砖。
## 地图上完全没有软砖时返回 (-1, -1)。
static func pick_exit_cell(grid: BombGrid, rng: RandomNumberGenerator, spawn: Vector2i) -> Vector2i:
	var far: Array[Vector2i] = []
	var any: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if grid.get_kind(x, y) != Tiles.Kind.BLOCK:
				continue
			var cell := Vector2i(x, y)
			any.append(cell)
			if manhattan(cell, spawn) >= EXIT_MIN_DISTANCE:
				far.append(cell)
	var pool := far if not far.is_empty() else any
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[rng.randi_range(0, pool.size() - 1)]


## 从空地里挑出互不贴脸、且离玩家足够远的敌人出生点。
static func pick_enemy_spawns(
	grid: BombGrid,
	rng: RandomNumberGenerator,
	spawn: Vector2i,
	count: int
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if grid.get_kind(x, y) != Tiles.Kind.EMPTY:
				continue
			var cell := Vector2i(x, y)
			if manhattan(cell, spawn) >= ENEMY_MIN_DISTANCE:
				candidates.append(cell)
	shuffle(candidates, rng)

	var result: Array[Vector2i] = []
	for cell in candidates:
		if result.size() >= count:
			break
		var too_close := false
		for placed in result:
			if manhattan(cell, placed) < ENEMY_MIN_SPACING:
				too_close = true
				break
		if not too_close:
			result.append(cell)
	return result


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 用传入的 rng 做 Fisher-Yates 洗牌，保证测试可复现。
static func shuffle(items: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := items[i]
		items[i] = items[j]
		items[j] = tmp
