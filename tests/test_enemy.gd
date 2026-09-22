extends TestCase
## Enemy：移动节奏计时器。


func run() -> void:
	_test_interval_timing()
	_test_dead_enemy_never_ticks()
	_test_interval_floor()


func _test_interval_timing() -> void:
	var e := Enemy.new(0, Vector2i(3, 3), 1, 0.5)
	assert_eq(e.cell, Vector2i(3, 3), "初始格子")
	assert_eq(e.kind, 1, "贴图种类")
	assert_false(e.tick(0.2), "未攒满一格步长时不该移动")
	assert_false(e.tick(0.2), "累计 0.4s 仍不够 0.5s")
	assert_true(e.tick(0.2), "累计 0.6s 应触发一次移动")
	# 触发后余下的 0.1s 要保留，不能被清零。
	assert_false(e.tick(0.3), "剩余 0.1s + 0.3s = 0.4s，还不够下一格")
	assert_true(e.tick(0.2), "再攒够 0.5s 触发第二次移动")


func _test_dead_enemy_never_ticks() -> void:
	var e := Enemy.new(0, Vector2i.ZERO, 0, 0.1)
	e.alive = false
	assert_false(e.tick(10.0), "已阵亡的敌人不再移动")


func _test_interval_floor() -> void:
	var e := Enemy.new(0, Vector2i.ZERO, 0, 0.0)
	assert_true(e.move_interval >= 0.05, "移动间隔有下限，避免除零或瞬移")
