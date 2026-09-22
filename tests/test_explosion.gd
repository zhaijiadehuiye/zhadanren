extends TestCase
## Explosion：十字范围、硬墙阻挡、软方块被炸并阻挡扩散。


func run() -> void:
	_test_blast_is_cross()
	_test_wall_blocks_blast()
	_test_block_is_destroyed_and_stops_blast()
	_test_power_zero_hits_only_origin()
	_test_origin_out_of_bounds_is_empty()


func _open_grid(size: int = 9) -> BombGrid:
	var rows := PackedStringArray()
	for _i in size:
		rows.append(".".repeat(size))
	return BombGrid.from_ascii(rows)


func _test_blast_is_cross() -> void:
	var grid := _open_grid()
	var cells := Explosion.blast_cells(grid, Vector2i(4, 4), 2)
	assert_eq(cells.size(), 9, "半径 2 的十字应覆盖 1+2*4=9 格")
	assert_true(cells.has(Vector2i(4, 4)), "包含中心格")
	assert_true(cells.has(Vector2i(6, 4)), "向右 2 格")
	assert_true(cells.has(Vector2i(2, 4)), "向左 2 格")
	assert_true(cells.has(Vector2i(4, 2)), "向上 2 格")
	assert_true(cells.has(Vector2i(4, 6)), "向下 2 格")
	assert_false(cells.has(Vector2i(5, 5)), "斜角不应被覆盖")
	assert_false(cells.has(Vector2i(7, 4)), "超出火力半径不应被覆盖")


func _test_wall_blocks_blast() -> void:
	var grid := BombGrid.from_ascii(PackedStringArray([
		"....#....",
		".........",
	]))
	var cells := Explosion.blast_cells(grid, Vector2i(1, 0), 4)
	assert_true(cells.has(Vector2i(3, 0)), "硬墙前的格子应被覆盖")
	assert_false(cells.has(Vector2i(4, 0)), "硬墙自身不被覆盖")
	assert_false(cells.has(Vector2i(5, 0)), "硬墙后不应被覆盖")


func _test_block_is_destroyed_and_stops_blast() -> void:
	var grid := BombGrid.from_ascii(PackedStringArray([
		"..x....",
	]))
	var cells := Explosion.blast_cells(grid, Vector2i(0, 0), 5)
	assert_eq(cells.size(), 3, "只应覆盖 中心 + 空地 + 软方块")
	assert_true(cells.has(Vector2i(2, 0)), "软方块自身会被炸")
	assert_false(cells.has(Vector2i(3, 0)), "软方块挡住后续扩散")


func _test_power_zero_hits_only_origin() -> void:
	var grid := _open_grid(5)
	var cells := Explosion.blast_cells(grid, Vector2i(2, 2), 0)
	assert_eq(cells.size(), 1, "火力 0 只覆盖中心格")
	assert_true(cells.has(Vector2i(2, 2)), "中心格")


func _test_origin_out_of_bounds_is_empty() -> void:
	var grid := _open_grid(5)
	assert_eq(Explosion.blast_cells(grid, Vector2i(-1, 0), 3).size(), 0, "越界原点无爆炸")
