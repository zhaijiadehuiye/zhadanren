class_name BombGrid
extends RefCounted
## 纯逻辑的方格地图：只保存每个格子的类型，不涉及任何渲染与场景树。

var width: int = 0
var height: int = 0
var cells: PackedByteArray = PackedByteArray()


func _init(p_width: int = 0, p_height: int = 0) -> void:
	resize(p_width, p_height)


## 重置为指定尺寸，并把所有格子填成空地。
func resize(p_width: int, p_height: int) -> void:
	width = maxi(p_width, 0)
	height = maxi(p_height, 0)
	cells = PackedByteArray()
	cells.resize(width * height)
	cells.fill(Tiles.Kind.EMPTY)


func index(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## 越界一律返回硬墙，让调用方无需额外判空。
func get_kind(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tiles.Kind.WALL
	return cells[index(x, y)]


func set_kind(x: int, y: int, kind: int) -> void:
	if not in_bounds(x, y):
		return
	cells[index(x, y)] = kind


func is_walkable(x: int, y: int) -> bool:
	return in_bounds(x, y) and get_kind(x, y) == Tiles.Kind.EMPTY


func is_solid(x: int, y: int) -> bool:
	return not is_walkable(x, y)


func count_kind(kind: int) -> int:
	var total := 0
	for i in cells.size():
		if cells[i] == kind:
			total += 1
	return total


func duplicate_grid() -> BombGrid:
	var copy := BombGrid.new(width, height)
	copy.cells = cells.duplicate()
	return copy


## 转成便于测试与调试的 ASCII 地图：'#' 硬墙，'x' 软方块，'.' 空地。
func to_ascii() -> String:
	var lines := PackedStringArray()
	for y in height:
		var line := ""
		for x in width:
			match get_kind(x, y):
				Tiles.Kind.WALL:
					line += "#"
				Tiles.Kind.BLOCK:
					line += "x"
				_:
					line += "."
		lines.append(line)
	return "\n".join(lines)


## 从 ASCII 地图构造网格，便于在测试和关卡里用声明式的方式描述地图。
static func from_ascii(rows: PackedStringArray) -> BombGrid:
	var h := rows.size()
	var w := 0
	for row in rows:
		w = maxi(w, row.length())
	var grid := BombGrid.new(w, h)
	for y in h:
		var row := rows[y]
		for x in row.length():
			match row[x]:
				"#":
					grid.set_kind(x, y, Tiles.Kind.WALL)
				"x":
					grid.set_kind(x, y, Tiles.Kind.BLOCK)
				_:
					grid.set_kind(x, y, Tiles.Kind.EMPTY)
	return grid
