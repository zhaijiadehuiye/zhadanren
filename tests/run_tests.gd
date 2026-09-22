extends SceneTree
## 测试入口。
##
## 运行方式（仓库根目录）：
##   ./tests/run_tests.sh
## 或直接：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
##
## 退出码 0 = 全部通过；1 = 存在失败断言。CI 与提交前检查都以退出码为准。

const TEST_SCRIPTS := [
	"res://tests/test_grid.gd",
	"res://tests/test_explosion.gd",
	"res://tests/test_level.gd",
	"res://tests/test_level_data.gd",
	"res://tests/test_bomb.gd",
	"res://tests/test_enemy.gd",
	"res://tests/test_player_state.gd",
	"res://tests/test_game_session.gd",
]


func _initialize() -> void:
	var total_checks := 0
	var total_failures := 0
	var failed_suites := 0

	print("=== Q 版炸弹人 单元测试 ===")
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			print("  [加载失败] %s" % path)
			total_failures += 1
			failed_suites += 1
			continue

		var suite: TestCase = script.new()
		suite.name = path.get_file()
		suite.run()
		total_checks += suite.check_count()
		var fails := suite.failure_count()
		total_failures += fails
		if fails == 0:
			print("  [通过] %-22s %d 项断言" % [suite.name, suite.check_count()])
		else:
			failed_suites += 1
			print("  [失败] %-22s %d/%d 项断言失败" % [suite.name, fails, suite.check_count()])
			for message in suite.failures():
				print("         - %s" % message)

	print("-----------------------------------")
	print("合计断言 %d 项，失败 %d 项，失败套件 %d 个" % [total_checks, total_failures, failed_suites])
	if total_failures == 0:
		print("结果：全部通过")
	else:
		print("结果：存在失败，禁止提交")
	quit(1 if total_failures > 0 else 0)
