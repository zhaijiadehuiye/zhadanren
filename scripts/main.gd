extends Node2D
## 视图层（本仓库唯一依赖场景树的脚本）。
##
## 职责只有两件事：
## 1. 把 Match 的纯逻辑状态画出来；
## 2. 把键盘输入翻译成对 Match 的调用。
## 任何玩法判定（谁能动、炸多广、谁死谁赢）都必须写在 scripts/core/ 里。

const CELL_SIZE := 48.0
const BOARD_ORIGIN := Vector2(40.0, 140.0)
const BACKGROUND_COLOR := Color("0b1220")

var tile_colors := {
	Tiles.Kind.EMPTY: Color("101c33"),
	Tiles.Kind.WALL: Color("37474f"),
	Tiles.Kind.BLOCK: Color("f48fb1"),
}
var powerup_colors := {
	Tiles.PowerUp.EXTRA_BOMB: Color("263238"),
	Tiles.PowerUp.FIRE: Color("ff5252"),
	Tiles.PowerUp.SPEED: Color("ffd54f"),
	Tiles.PowerUp.SHIELD: Color("4dd0e1"),
}
var player_colors: Array[Color] = [
	Color("4fc3f7"),
	Color("ff8a65"),
	Color("aed581"),
	Color("ba68c8"),
]

var match_state: Match


func _ready() -> void:
	restart()


## 重开一局（R 键触发）。
func restart() -> void:
	var w := Level.DEFAULT_WIDTH
	var h := Level.DEFAULT_HEIGHT
	var spawns := Level.corner_spawns(w, h)
	var active: Array[Vector2i] = [spawns[0], spawns[1]]
	var grid := Level.classic(w, h, active)
	match_state = Match.new(grid, active)


func _unhandled_input(event: InputEvent) -> void:
	if match_state == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.physical_keycode)


func _handle_key(keycode: int) -> void:
	if keycode == KEY_R:
		restart()
		return
	if match_state.is_over:
		return
	match keycode:
		KEY_W:
			match_state.move_player(0, Vector2i(0, -1))
		KEY_S:
			match_state.move_player(0, Vector2i(0, 1))
		KEY_A:
			match_state.move_player(0, Vector2i(-1, 0))
		KEY_D:
			match_state.move_player(0, Vector2i(1, 0))
		KEY_SPACE:
			match_state.place_bomb(0)
		KEY_UP:
			match_state.move_player(1, Vector2i(0, -1))
		KEY_DOWN:
			match_state.move_player(1, Vector2i(0, 1))
		KEY_LEFT:
			match_state.move_player(1, Vector2i(-1, 0))
		KEY_RIGHT:
			match_state.move_player(1, Vector2i(1, 0))
		KEY_ENTER:
			match_state.place_bomb(1)


func _process(delta: float) -> void:
	if match_state != null:
		match_state.tick(delta)
	queue_redraw()


func _draw() -> void:
	if match_state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND_COLOR)
	_draw_board()
	_draw_powerups()
	_draw_bombs()
	_draw_blasts()
	_draw_players()
	_draw_hud()


func _cell_rect(cell: Vector2i, inset: float = 1.0) -> Rect2:
	var pos := BOARD_ORIGIN + Vector2(cell) * CELL_SIZE
	return Rect2(pos + Vector2(inset, inset), Vector2(CELL_SIZE - inset * 2.0, CELL_SIZE - inset * 2.0))


func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _draw_board() -> void:
	var grid := match_state.grid
	for y in grid.height:
		for x in grid.width:
			var kind := grid.get_kind(x, y)
			var rect := _cell_rect(Vector2i(x, y))
			draw_rect(rect, tile_colors[kind])
			if kind == Tiles.Kind.WALL:
				draw_rect(rect.grow(-6.0), Color("546e7a"))
			elif kind == Tiles.Kind.BLOCK:
				draw_rect(rect.grow(-5.0), Color("f8bbd0"))
				draw_circle(rect.get_center(), 6.0, Color("ad1457"))


func _draw_powerups() -> void:
	for item in match_state.powerups:
		draw_rect(_cell_rect(item.cell, 14.0), powerup_colors[item.kind])


func _draw_bombs() -> void:
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 120.0)
	for bomb in match_state.bombs:
		var center := _cell_center(bomb.cell)
		draw_circle(center, 16.0 * pulse, Color("212121"))
		draw_circle(center, 8.0 * pulse, Color("455a64"))
		draw_line(center, center + Vector2(8, -14), Color("ffab00"), 3.0)


func _draw_blasts() -> void:
	for cell in match_state.blast_cells:
		var rect := _cell_rect(cell)
		draw_rect(rect, Color(1.0, 0.42, 0.16, 0.85))
		draw_rect(rect.grow(-10.0), Color(1.0, 0.9, 0.4, 0.9))


func _draw_players() -> void:
	for p in match_state.players:
		if not p.alive:
			continue
		var center := _cell_center(p.cell)
		var color: Color = player_colors[p.id % player_colors.size()]
		if p.has_shield():
			draw_circle(center, 21.0, Color(0.3, 0.85, 0.9, 0.35))
		draw_circle(center, 15.0, color)
		draw_circle(center, 8.0, Color("ffffff"))
		draw_circle(center + Vector2(-4, -3), 2.5, Color("263238"))
		draw_circle(center + Vector2(4, -3), 2.5, Color("263238"))


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var y := 36.0
	for p in match_state.players:
		var color: Color = player_colors[p.id % player_colors.size()]
		var status := "已阵亡"
		if p.alive:
			var shield_text := "   护盾中" if p.has_shield() else ""
			status = "炸弹 %d/%d   火力 %d   速度 %.1f%s" % [
				p.bomb_capacity - p.bombs_placed,
				p.bomb_capacity,
				p.power,
				p.speed,
				shield_text,
			]
		draw_string(
			font,
			Vector2(40.0, y),
			"P%d   %s" % [p.id + 1, status],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			color
		)
		y += 26.0

	draw_string(
		font,
		Vector2(40.0, y + 10.0),
		"P1: WASD 移动 / 空格 放炸弹    P2: 方向键移动 / 回车 放炸弹    R: 重开",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		Color("90a4ae")
	)

	if match_state.is_over:
		var text := "平局！" if match_state.winner_id < 0 else "P%d 获胜！" % (match_state.winner_id + 1)
		draw_string(
			font,
			Vector2(40.0, y + 44.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			28,
			Color("ffe082")
		)
