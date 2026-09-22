extends TestCase
## Bomb：引信倒计时与只引爆一次。


func run() -> void:
	_test_fuse_counts_down()
	_test_tick_fires_once()
	_test_power_is_at_least_one()


func _test_fuse_counts_down() -> void:
	var bomb := Bomb.new(Vector2i(1, 1), 0, 2, 1.0)
	assert_false(bomb.tick(0.4), "未到时间不应引爆")
	assert_almost_eq(bomb.fuse, 0.6, "引信应递减")
	assert_false(bomb.tick(0.5), "仍未到时间")
	assert_true(bomb.tick(0.2), "到时间应引爆")
	assert_almost_eq(bomb.fuse, 0.0, "引爆后引信归零")


func _test_tick_fires_once() -> void:
	var bomb := Bomb.new(Vector2i(0, 0), 0, 1, 0.5)
	assert_true(bomb.tick(1.0), "首次到时间引爆")
	assert_false(bomb.tick(1.0), "已引爆的炸弹不应再次触发")
	assert_true(bomb.exploded, "状态标记为已引爆")


func _test_power_is_at_least_one() -> void:
	var bomb := Bomb.new(Vector2i(0, 0), 0, 0, 1.0)
	assert_eq(bomb.power, 1, "火力下限为 1")
