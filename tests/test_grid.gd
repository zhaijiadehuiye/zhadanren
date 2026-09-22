extends TestCase
## BombGrid：读写、边界语义与 ASCII 互转。


func run() -> void:
	_test_new_grid_is_empty()
	_test_set_and_get()
	_test_out_of_bounds_is_solid()
	_test_ascii_roundtrip()


func _test_new_grid_is_empty() -> void:
	var grid := BombGrid.new(3, 2)
	assert_eq(grid.width, 3, "宽度")
	assert_eq(grid.height, 2, "高度")
	assert_eq(grid.count_kind(Tiles.Kind.EMPTY), 6, "初始应全部是空地")
	assert_true(grid.is_walkable(0, 0), "空地可通行")


func _test_set_and_get() -> void:
	var grid := BombGrid.new(4, 4)
	grid.set_kind(1, 1, Tiles.Kind.WALL)
	assert_eq(grid.get_kind(1, 1), Tiles.Kind.WALL, "硬墙写入后应能读回")
	assert_false(grid.is_walkable(1, 1), "硬墙不可通行")
	grid.set_kind(2, 2, Tiles.Kind.BLOCK)
	assert_eq(grid.count_kind(Tiles.Kind.BLOCK), 1, "软方块计数")
	assert_true(grid.is_solid(2, 2), "软方块视为实心")


func _test_out_of_bounds_is_solid() -> void:
	var grid := BombGrid.new(2, 2)
	assert_false(grid.in_bounds(-1, 0), "负坐标越界")
	assert_false(grid.in_bounds(2, 0), "超出宽度越界")
	assert_false(grid.in_bounds(0, 2), "超出高度越界")
	assert_true(grid.is_solid(-1, -1), "越界视为实心")
	assert_eq(grid.get_kind(9, 9), Tiles.Kind.WALL, "越界读取返回硬墙")


func _test_ascii_roundtrip() -> void:
	var rows := PackedStringArray([
		"#####",
		"#x.x#",
		"#####",
	])
	var grid := BombGrid.from_ascii(rows)
	assert_eq(grid.width, 5, "ASCII 宽度")
	assert_eq(grid.height, 3, "ASCII 高度")
	assert_eq(grid.get_kind(1, 1), Tiles.Kind.BLOCK, "'x' 解析为软方块")
	assert_eq(grid.get_kind(2, 1), Tiles.Kind.EMPTY, "'.' 解析为空地")
	assert_eq(grid.to_ascii(), "\n".join(rows), "ASCII 往返应一致")
