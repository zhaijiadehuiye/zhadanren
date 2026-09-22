extends TestCase
## Level：经典布局的硬墙规则与出生点安全区。


func run() -> void:
	_test_border_and_pillars()
	_test_spawn_area_cleared()


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func _test_border_and_pillars() -> void:
	var spawns: Array[Vector2i] = [LevelData.PLAYER_SPAWN]
	var grid := Level.classic(15, 13, spawns, _seeded_rng())
	assert_eq(grid.width, 15, "宽度")
	assert_eq(grid.height, 13, "高度")
	assert_eq(grid.get_kind(0, 0), Tiles.Kind.WALL, "左上角为外圈硬墙")
	assert_eq(grid.get_kind(14, 12), Tiles.Kind.WALL, "右下角为外圈硬墙")
	assert_eq(grid.get_kind(6, 6), Tiles.Kind.WALL, "偶数坐标交叉点为柱子")
	assert_eq(grid.get_kind(2, 2), Tiles.Kind.WALL, "偶数坐标柱子")
	assert_ne(grid.get_kind(1, 1), Tiles.Kind.WALL, "出生点不应是硬墙")


func _test_spawn_area_cleared() -> void:
	var spawn := Vector2i(1, 1)
	var spawns: Array[Vector2i] = [spawn]
	# block_chance = 1.0：所有非硬墙格都会变成软方块，用来验证安全区确实被清空。
	var grid := Level.classic(15, 13, spawns, _seeded_rng(), 1.0)
	assert_eq(grid.get_kind(1, 1), Tiles.Kind.EMPTY, "出生点必须为空地")
	assert_eq(grid.get_kind(2, 1), Tiles.Kind.EMPTY, "出生点右侧一格必须为空地")
	assert_eq(grid.get_kind(1, 2), Tiles.Kind.EMPTY, "出生点下方一格必须为空地")
