class_name TestCase
extends RefCounted
## 极简测试基类：子类重写 run()，内部用 assert_* 断言。
##
## 由 tests/run_tests.gd 统一驱动，可在 headless 下运行，无需第三方插件。

var name: String = "TestCase"

var _checks: int = 0
var _failures: Array[String] = []


## 子类重写：在这里调用 assert_* 完成断言。
func run() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_failures.append("期望为 true：%s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	_checks += 1
	if condition:
		_failures.append("期望为 false：%s" % message)


func assert_eq(actual, expected, message: String = "") -> void:
	_checks += 1
	if actual != expected:
		_failures.append("期望 %s，实际 %s（%s）" % [str(expected), str(actual), message])


func assert_ne(actual, unexpected, message: String = "") -> void:
	_checks += 1
	if actual == unexpected:
		_failures.append("不应等于 %s（%s）" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, message: String = "", epsilon: float = 0.0001) -> void:
	_checks += 1
	if absf(actual - expected) > epsilon:
		_failures.append("期望约等于 %s，实际 %s（%s）" % [str(expected), str(actual), message])


func check_count() -> int:
	return _checks


func failure_count() -> int:
	return _failures.size()


func failures() -> Array[String]:
	return _failures
