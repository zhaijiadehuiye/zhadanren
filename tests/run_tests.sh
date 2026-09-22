#!/usr/bin/env bash
# 一键运行全部单元测试（headless，无需打开编辑器）。
#
# 用法：在仓库根目录执行 ./tests/run_tests.sh
# 自定义 Godot 路径：GODOT_BIN=/path/to/Godot ./tests/run_tests.sh
#
# 退出码 0 = 全部通过；非 0 = 存在失败断言，禁止提交。

set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "找不到 Godot 可执行文件：$GODOT_BIN" >&2
  echo "请用 GODOT_BIN 环境变量指定，例如：GODOT_BIN=/path/to/Godot ./tests/run_tests.sh" >&2
  exit 127
fi

exec "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/run_tests.gd
