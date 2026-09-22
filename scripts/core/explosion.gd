class_name Explosion
extends RefCounted
## 爆炸范围计算：纯函数，不修改地图。


## 计算以 origin 为中心、半径为 power 的十字爆炸覆盖格。
##
## 规则：
## - 硬墙：挡住扩散，且自身不被覆盖；
## - 软方块：会被覆盖（随后由调用方摧毁），但挡住后续扩散；
## - 越界：停止扩散。
static func blast_cells(grid: BombGrid, origin: Vector2i, power: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid.in_bounds(origin.x, origin.y):
		return result
	result.append(origin)
	if grid.get_kind(origin.x, origin.y) == Tiles.Kind.WALL:
		return result

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for dir in directions:
		for step in range(1, maxi(power, 0) + 1):
			var cell := origin + dir * step
			if not grid.in_bounds(cell.x, cell.y):
				break
			var kind := grid.get_kind(cell.x, cell.y)
			if kind == Tiles.Kind.WALL:
				break
			result.append(cell)
			if kind == Tiles.Kind.BLOCK:
				break
	return result
