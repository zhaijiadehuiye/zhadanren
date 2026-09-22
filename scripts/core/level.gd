class_name Level
extends RefCounted
## 关卡生成：经典泡泡堂式布局。

const DEFAULT_WIDTH := 15
const DEFAULT_HEIGHT := 13
const DEFAULT_BLOCK_CHANCE := 0.75


## 生成经典布局：外圈硬墙 + 偶数坐标硬墙，其余随机撒软方块，
## 并在每个出生点周围清出安全区。
static func classic(
	p_width: int = DEFAULT_WIDTH,
	p_height: int = DEFAULT_HEIGHT,
	spawns: Array[Vector2i] = [],
	rng: RandomNumberGenerator = null,
	block_chance: float = DEFAULT_BLOCK_CHANCE
) -> BombGrid:
	var grid := BombGrid.new(p_width, p_height)
	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	for y in p_height:
		for x in p_width:
			var is_border := x == 0 or y == 0 or x == p_width - 1 or y == p_height - 1
			var is_pillar := x % 2 == 0 and y % 2 == 0
			if is_border or is_pillar:
				grid.set_kind(x, y, Tiles.Kind.WALL)
			elif local_rng.randf() < block_chance:
				grid.set_kind(x, y, Tiles.Kind.BLOCK)

	for spawn in spawns:
		clear_spawn_area(grid, spawn)
	return grid


## 清空出生点及其朝向地图中心的两格，保证开局不会被软方块堵死。
static func clear_spawn_area(grid: BombGrid, spawn: Vector2i) -> void:
	if not grid.in_bounds(spawn.x, spawn.y):
		return
	var center := Vector2i(grid.width / 2, grid.height / 2)
	var dx := signi(center.x - spawn.x)
	var dy := signi(center.y - spawn.y)
	var area: Array[Vector2i] = [spawn]
	if dx != 0:
		area.append(spawn + Vector2i(dx, 0))
	if dy != 0:
		area.append(spawn + Vector2i(0, dy))
	for cell in area:
		if grid.get_kind(cell.x, cell.y) == Tiles.Kind.BLOCK:
			grid.set_kind(cell.x, cell.y, Tiles.Kind.EMPTY)
