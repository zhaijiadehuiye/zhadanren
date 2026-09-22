extends Node2D
## 视图层（本仓库唯一依赖场景树的脚本）。
##
## 职责只有两件事：
## 1. 用真实像素美术把 GameSession 的纯逻辑状态画出来（含逐帧动画与平滑移动）；
## 2. 把键盘输入翻译成对 GameSession 的调用。
## 任何玩法判定（谁能动、炸多广、谁死谁过关）都必须写在 scripts/core/ 里。

# ---------------------------------------------------------------- 布局

const CELL := 48.0
const HUD_WIDTH := 268.0
const MARGIN := 16.0
const BOARD_ORIGIN := Vector2(HUD_WIDTH + MARGIN * 2.0, 40.0)

# ---------------------------------------------------------------- 资源

const CHAR_SHEETS := [
	"res://assets/sprites/characters/ninjabomb.png",
	"res://assets/sprites/characters/lion.png",
	"res://assets/sprites/characters/eggboy.png",
	"res://assets/sprites/characters/monkey.png",
]
const CHAR_FACES := [
	"res://assets/sprites/characters/ninjabomb_face.png",
	"res://assets/sprites/characters/lion_face.png",
	"res://assets/sprites/characters/eggboy_face.png",
	"res://assets/sprites/characters/monkey_face.png",
]
const CHAR_ART := [
	"res://assets/art/char_ninjabomb.png",
	"res://assets/art/char_lion.png",
	"res://assets/art/char_eggboy.png",
	"res://assets/art/char_monkey.png",
]
const CHAR_NAMES := ["忍者", "小狮子", "蛋头", "拳击猴"]
const ENEMY_SHEETS := [
	"res://assets/sprites/enemies/slime.png",
	"res://assets/sprites/enemies/snake.png",
	"res://assets/sprites/enemies/mushroom.png",
	"res://assets/sprites/enemies/owl.png",
	"res://assets/sprites/enemies/mole.png",
	"res://assets/sprites/enemies/spider.png",
]
const TILE_SHEET := "res://assets/sprites/tiles/dungeon.png"
const FLOOR_TEX := "res://assets/sprites/tiles/floor_tex.png"
const FIRE_TEX := "res://assets/sprites/fx/fire.png"
const SMOKE_TEX := "res://assets/sprites/fx/smoke.png"
const ROCK_TEX := "res://assets/sprites/fx/rock.png"
const HEART_TEX := "res://assets/sprites/items/heart.png"
const TITLE_ART := "res://assets/art/title.png"
const POWERUP_TEX := {
	Tiles.PowerUp.EXTRA_BOMB: "res://assets/sprites/items/powerup_bomb.png",
	Tiles.PowerUp.FIRE: "res://assets/sprites/items/powerup_fire.png",
	Tiles.PowerUp.SPEED: "res://assets/sprites/items/powerup_speed.png",
	Tiles.PowerUp.SHIELD: "res://assets/sprites/items/powerup_bomb.png",
	Tiles.PowerUp.REMOTE: "res://assets/sprites/items/powerup_remote.png",
}
const POWERUP_TINTS := {
	Tiles.PowerUp.EXTRA_BOMB: Color("4fc3f7"),
	Tiles.PowerUp.FIRE: Color("ff7043"),
	Tiles.PowerUp.SPEED: Color("66bb6a"),
	Tiles.PowerUp.SHIELD: Color("ba68c8"),
	Tiles.PowerUp.REMOTE: Color("ffd54f"),
}

## 瓦片集 dungeon.png（12 列 × 4 行，16×16）里挑出来的三个格子。
const TILE_WALL := Vector2i(8, 3)
const TILE_BRICK := Vector2i(3, 1)
const TILE_SOURCE_SIZE := 16.0

const SFX_PATHS := {
	GameSession.EVENT_PLACE_BOMB: "res://assets/audio/place_bomb.wav",
	GameSession.EVENT_EXPLOSION: "res://assets/audio/explosion.wav",
	GameSession.EVENT_POWERUP: "res://assets/audio/powerup.wav",
	GameSession.EVENT_ENEMY_KILLED: "res://assets/audio/kill.wav",
	GameSession.EVENT_PLAYER_HIT: "res://assets/audio/hit.wav",
	GameSession.EVENT_RESPAWN: "res://assets/audio/bonus.wav",
	GameSession.EVENT_EXIT_FOUND: "res://assets/audio/bonus.wav",
	GameSession.EVENT_LEVEL_CLEAR: "res://assets/audio/level_clear.wav",
	GameSession.EVENT_GAME_OVER: "res://assets/audio/game_over.wav",
	GameSession.EVENT_TIME_UP: "res://assets/audio/alert.wav",
}
const SFX_VOICES := 8

const COLOR_BG := Color("12102a")
const COLOR_HUD_PANEL := Color("f7d6e6")
const COLOR_HUD_EDGE := Color("e091b8")
const COLOR_TEXT_DARK := Color("3b2b3a")
const COLOR_TEXT_LIGHT := Color("fff4fa")

## 场景状态：标题 → 选人 → 游玩。
enum Scene { TITLE, SELECT, PLAY }

var session: GameSession
var _scene: int = Scene.TITLE
var _selected_char: int = 0
var _paused: bool = false

var _tex: Dictionary = {}
var _sfx: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _font: Font = ThemeDB.fallback_font

## 玩家与敌人的「视觉格坐标」，用插值追赶逻辑格坐标，做出平滑移动。
var _player_pos := Vector2.ZERO
var _enemy_pos: Array[Vector2] = []
var _walking := false
var _move_cooldown := 0.0
var _anim_time := 0.0
var _banner_time := 0.0
var _banner_text := ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = _load_ui_font()
	_load_textures()
	_load_sfx()
	_new_session()


# ---------------------------------------------------------------- 资源加载

## HUD 需要中文，Godot 内置字体不含 CJK 字形，所以优先挂载系统字体。
func _load_ui_font() -> Font:
	var candidates := [
		"/System/Library/Fonts/PingFang.ttc",
		"/System/Library/Fonts/STHeiti Medium.ttc",
		"/System/Library/Fonts/Hiragino Sans GB.ttc",
	]
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var font := FontFile.new()
		if font.load_dynamic_font(path) == OK:
			return font
	return ThemeDB.fallback_font


func _load_textures() -> void:
	var paths: Array[String] = [TILE_SHEET, FLOOR_TEX, FIRE_TEX, SMOKE_TEX, ROCK_TEX, HEART_TEX, TITLE_ART]
	paths.append_array(CHAR_SHEETS)
	paths.append_array(CHAR_FACES)
	paths.append_array(CHAR_ART)
	paths.append_array(ENEMY_SHEETS)
	for key in POWERUP_TEX:
		paths.append(POWERUP_TEX[key])
	for path in paths:
		if not _tex.has(path):
			_tex[path] = load(path) if ResourceLoader.exists(path) else null


func _load_sfx() -> void:
	for event in SFX_PATHS:
		var path: String = SFX_PATHS[event]
		if ResourceLoader.exists(path):
			_sfx[event] = load(path)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_voices.append(player)


func _play_sfx(event: String) -> void:
	var stream: AudioStream = _sfx.get(event)
	if stream == null:
		return
	for player in _voices:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	_voices[0].stream = stream
	_voices[0].play()


func _new_session() -> void:
	session = GameSession.new()
	_sync_visual_positions(true)
	_banner_text = "第 1 关 开始！"
	_banner_time = 1.6


## 让视觉坐标立刻对齐逻辑坐标（重开、换关、复活时用，避免出现横穿地图的滑动）。
func _sync_visual_positions(force: bool = false) -> void:
	if session == null:
		return
	if force:
		_player_pos = Vector2(session.player.cell)
	_enemy_pos.resize(session.enemies.size())
	for i in session.enemies.size():
		if force or i >= _enemy_pos.size():
			_enemy_pos[i] = Vector2(session.enemies[i].cell)


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	_handle_key(event.physical_keycode)


func _handle_key(keycode: int) -> void:
	match _scene:
		Scene.TITLE:
			if keycode == KEY_SPACE or keycode == KEY_ENTER:
				_scene = Scene.SELECT
		Scene.SELECT:
			if keycode == KEY_A or keycode == KEY_LEFT:
				_selected_char = wrapi(_selected_char - 1, 0, CHAR_SHEETS.size())
			elif keycode == KEY_D or keycode == KEY_RIGHT:
				_selected_char = wrapi(_selected_char + 1, 0, CHAR_SHEETS.size())
			elif keycode == KEY_SPACE or keycode == KEY_ENTER:
				_scene = Scene.PLAY
				_new_session()
			elif keycode == KEY_ESCAPE:
				_scene = Scene.TITLE
		Scene.PLAY:
			_handle_play_key(keycode)


func _handle_play_key(keycode: int) -> void:
	match keycode:
		KEY_R:
			_new_session()
		KEY_P:
			_paused = not _paused
		KEY_ESCAPE:
			_scene = Scene.SELECT
		KEY_SPACE:
			if session.place_bomb():
				_move_cooldown = 0.05
		KEY_F:
			session.detonate_remote()
		KEY_ENTER:
			if not session.is_playing() and session.phase == GameSession.Phase.GAME_OVER:
				_new_session()


## 方向键 / WASD 用轮询而不是事件，这样按住可以连续走格。
func _poll_movement(delta: float) -> void:
	_move_cooldown = maxf(_move_cooldown - delta, 0.0)
	if _move_cooldown > 0.0 or not session.is_playing():
		return
	var direction := Vector2i.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction = Vector2i(0, -1)
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction = Vector2i(0, 1)
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction = Vector2i(-1, 0)
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction = Vector2i(1, 0)
	if direction == Vector2i.ZERO:
		return
	# 走得动就按速度给冷却；撞墙只给很短冷却，避免按住方向键时贴墙卡顿。
	_move_cooldown = _step_duration() if session.move_player(direction) else 0.05


func _step_duration() -> float:
	return clampf(0.62 / maxf(session.player.speed, 0.5), 0.07, 0.4)


# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	_anim_time += delta
	_banner_time = maxf(_banner_time - delta, 0.0)

	if _scene == Scene.PLAY:
		if not _paused:
			session.tick(delta)
			_poll_movement(delta)
			_drain_events()
		_update_visual_positions(delta)

	queue_redraw()


func _drain_events() -> void:
	for event in session.pop_events():
		_play_sfx(event)
		match event:
			GameSession.EVENT_LEVEL_CLEAR:
				_banner_text = "过关！"
				_banner_time = 1.6
			GameSession.EVENT_EXIT_FOUND:
				_banner_text = "发现出口！"
				_banner_time = 1.6
			GameSession.EVENT_GAME_OVER:
				_banner_text = "通关！" if session.campaign_cleared else "游戏结束"
				_banner_time = 3.0
			GameSession.EVENT_RESPAWN:
				_sync_visual_positions(true)


## 视觉坐标以固定速度追赶逻辑坐标，追赶速度略快于走一格的时间，保证落点不拖沓。
func _update_visual_positions(delta: float) -> void:
	if session.player.alive:
		var target := Vector2(session.player.cell)
		var catch_up := maxf(7.0, session.player.speed * 2.4)
		_walking = _player_pos.distance_to(target) > 0.04
		_player_pos = _player_pos.move_toward(target, catch_up * delta)
	else:
		_walking = false

	if _enemy_pos.size() != session.enemies.size():
		_sync_visual_positions(true)
	for i in session.enemies.size():
		var enemy := session.enemies[i]
		if not enemy.alive:
			continue
		var target := Vector2(enemy.cell)
		var speed := 1.0 / maxf(enemy.move_interval, 0.05) * 1.6
		_enemy_pos[i] = _enemy_pos[i].move_toward(target, speed * delta)


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BG)
	match _scene:
		Scene.TITLE:
			_draw_title()
		Scene.SELECT:
			_draw_select()
		Scene.PLAY:
			_draw_play()


func _draw_play() -> void:
	_draw_board()
	_draw_exit()
	_draw_powerups()
	_draw_bombs()
	_draw_blasts()
	_draw_enemies()
	_draw_player()
	_draw_hud()
	_draw_banner()


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _center_of(pos: Vector2) -> Vector2:
	return BOARD_ORIGIN + (pos + Vector2(0.5, 0.5)) * CELL


func _board_size() -> Vector2:
	return Vector2(session.grid.width, session.grid.height) * CELL


## 画图集里的一帧（按正方形帧切分）。
func _draw_frame(tex: Texture2D, index: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var frame := float(tex.get_height())
	var count := maxi(int(tex.get_width() / frame), 1)
	draw_texture_rect_region(tex, rect, Rect2(float(index % count) * frame, 0.0, frame, frame), tint)


## 画 4 列 × rows 行的角色/怪物图集：列由朝向决定，行由动画帧决定。
func _draw_sheet(tex: Texture2D, col: int, row: int, rect: Rect2, rows: int) -> void:
	if tex == null:
		return
	var cw := tex.get_width() / 4.0
	var ch := tex.get_height() / float(rows)
	draw_texture_rect_region(tex, rect, Rect2(float(col) * cw, float(row) * ch, cw, ch))


## 把 16×16 的瓦片放大铺满一个格子。
func _draw_tile(cell: Vector2i, tile: Vector2i) -> void:
	var sheet: Texture2D = _tex.get(TILE_SHEET)
	if sheet == null:
		return
	draw_texture_rect_region(
		sheet,
		_cell_rect(cell),
		Rect2(Vector2(tile) * TILE_SOURCE_SIZE, Vector2(TILE_SOURCE_SIZE, TILE_SOURCE_SIZE))
	)


## 角色/怪物统一用「略大于格子、略微上移」的矩形，避免精灵贴边显得局促。
func _sprite_rect(pos: Vector2) -> Rect2:
	var size := CELL * 1.2
	var center := _center_of(pos)
	return Rect2(center.x - size * 0.5, center.y - size * 0.5 - CELL * 0.1, size, size)


func _draw_board() -> void:
	var board := Rect2(BOARD_ORIGIN, _board_size())
	var floor_tex: Texture2D = _tex.get(FLOOR_TEX)
	if floor_tex != null:
		# AI 生成的地板纹理整体铺一次，避免逐格重复造成明显接缝。
		draw_texture_rect(floor_tex, board, false, Color(0.55, 0.5, 0.78))
	else:
		draw_rect(board, Color("241d3d"))

	var grid := session.grid
	for y in grid.height:
		for x in grid.width:
			var kind := grid.get_kind(x, y)
			match kind:
				Tiles.Kind.WALL:
					_draw_tile(Vector2i(x, y), TILE_WALL)
				Tiles.Kind.BLOCK:
					_draw_tile(Vector2i(x, y), TILE_BRICK)
				_:
					pass
	# 淡淡的格线，让网格结构可读但又不抢戏。
	for x in grid.width + 1:
		var px := BOARD_ORIGIN.x + x * CELL
		draw_line(Vector2(px, board.position.y), Vector2(px, board.end.y), Color(1, 1, 1, 0.05), 1.0)
	for y in grid.height + 1:
		var py := BOARD_ORIGIN.y + y * CELL
		draw_line(Vector2(board.position.x, py), Vector2(board.end.x, py), Color(1, 1, 1, 0.05), 1.0)


func _draw_exit() -> void:
	if not session.exit_revealed or session.exit_cell.x < 0:
		return
	var center := _center_of(Vector2(session.exit_cell))
	var active := session.is_exit_active()
	var tint := Color("ffd54f") if active else Color("78909c")
	var pulse := 1.0 + 0.12 * sin(_anim_time * 5.0)
	var size := CELL * 1.05 * pulse
	draw_circle(center, CELL * 0.46, Color(0, 0, 0, 0.45))
	var smoke: Texture2D = _tex.get(SMOKE_TEX)
	if smoke != null:
		_draw_frame(
			smoke,
			int(_anim_time * 10.0),
			Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size),
			tint
		)
	if active:
		draw_circle(center, CELL * 0.18, Color(1, 1, 0.85, 0.75))


func _draw_powerups() -> void:
	for item in session.powerups:
		var center := _center_of(Vector2(item.cell))
		var bob := sin(_anim_time * 4.0 + float(item.cell.x)) * 2.5
		var tint: Color = POWERUP_TINTS.get(item.kind, Color.WHITE)
		draw_circle(center + Vector2(0, bob), CELL * 0.34, Color(tint.r, tint.g, tint.b, 0.3))
		draw_circle(center + Vector2(0, bob), CELL * 0.28, Color(1, 1, 1, 0.18))
		var tex: Texture2D = _tex.get(POWERUP_TEX.get(item.kind, ""))
		var size := CELL * 0.72
		_draw_frame(tex, int(_anim_time * 8.0), Rect2(
			center.x - size * 0.5, center.y - size * 0.5 + bob, size, size
		))


func _draw_bombs() -> void:
	var ball: Texture2D = _tex.get(POWERUP_TEX[Tiles.PowerUp.EXTRA_BOMB])
	for bomb in session.bombs:
		var center := _center_of(Vector2(bomb.cell))
		# 遥控炸弹不倒数，改成稳定的金色呼吸；普通炸弹越接近爆炸闪得越快。
		if bomb.remote:
			var breathe := 1.0 + 0.08 * sin(_anim_time * 6.0)
			draw_circle(center, CELL * 0.42 * breathe, Color(1.0, 0.84, 0.3, 0.35))
			draw_circle(center, CELL * 0.34, Color(1.0, 0.9, 0.45, 0.5))
		else:
			var urgency := clampf(1.0 - bomb.fuse / GameSession.DEFAULT_FUSE, 0.0, 1.0)
			var blink := 0.5 + 0.5 * sin(_anim_time * (6.0 + urgency * 26.0))
			draw_circle(center, CELL * 0.42, Color(1.0, 0.35 + 0.3 * urgency, 0.2, 0.25 + 0.35 * blink))
		var size := CELL * 0.86 * (1.0 + 0.06 * sin(_anim_time * 9.0))
		_draw_frame(ball, int(_anim_time * 10.0), Rect2(
			center.x - size * 0.5, center.y - size * 0.5, size, size
		))


func _draw_blasts() -> void:
	if session.blast_cells.is_empty():
		return
	var progress := 1.0 - session.blast_time_left / GameSession.BLAST_DURATION
	var frame := int(clampf(progress, 0.0, 0.999) * 8.0)
	var fire: Texture2D = _tex.get(FIRE_TEX)
	var rock: Texture2D = _tex.get(ROCK_TEX)
	for cell in session.blast_cells:
		var center := _center_of(Vector2(cell))
		draw_circle(center, CELL * 0.5, Color(1.0, 0.55, 0.15, 0.35))
		var size := CELL * 1.05
		_draw_frame(fire, frame, Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size))
		# 前 40% 的爆炸时间叠一层碎石，表现「炸开软砖」的冲击感。
		if progress < 0.4:
			var debris := CELL * 0.7
			_draw_frame(rock, frame, Rect2(
				center.x - debris * 0.5, center.y - debris * 0.5, debris, debris
			), Color(1, 1, 1, 1.0 - progress / 0.4))


func _draw_enemies() -> void:
	for i in session.enemies.size():
		var enemy := session.enemies[i]
		if not enemy.alive:
			continue
		var pos: Vector2 = _enemy_pos[i] if i < _enemy_pos.size() else Vector2(enemy.cell)
		var sheet: Texture2D = _tex.get(ENEMY_SHEETS[enemy.kind % ENEMY_SHEETS.size()])
		draw_circle(_center_of(pos) + Vector2(0, CELL * 0.34), CELL * 0.26, Color(0, 0, 0, 0.25))
		var row := int(_anim_time * 7.0 + i) % 4
		_draw_sheet(sheet, _dir_column(enemy.facing), row, _sprite_rect(pos), 4)


func _draw_player() -> void:
	if not session.player.alive:
		return
	var player := session.player
	var center := _center_of(_player_pos)
	if player.has_shield():
		var glow := 0.35 + 0.15 * sin(_anim_time * 8.0)
		draw_circle(center, CELL * 0.55, Color(0.45, 0.9, 1.0, glow))
		draw_circle(center, CELL * 0.46, Color(0.85, 0.97, 1.0, 0.22))
	draw_circle(center + Vector2(0, CELL * 0.34), CELL * 0.26, Color(0, 0, 0, 0.28))
	var sheet: Texture2D = _tex.get(CHAR_SHEETS[_selected_char])
	var row := 0
	if _walking:
		row = [0, 1, 2, 3][int(_anim_time * 9.0) % 4]
	_draw_sheet(sheet, _dir_column(player.facing), row, _sprite_rect(_player_pos), 7)


## 逻辑朝向 → 图集列号：0 下 / 1 上 / 2 左 / 3 右。
func _dir_column(direction: Vector2i) -> int:
	if direction == Vector2i(0, -1):
		return 1
	if direction == Vector2i(-1, 0):
		return 2
	if direction == Vector2i(1, 0):
		return 3
	return 0


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var player := session.player
	var panel := Rect2(MARGIN, MARGIN, HUD_WIDTH, 372.0)
	draw_rect(panel, COLOR_HUD_PANEL)
	draw_rect(panel, COLOR_HUD_EDGE, false, 3.0)

	var face: Texture2D = _tex.get(CHAR_FACES[_selected_char])
	if face != null:
		var face_rect := Rect2(panel.position + Vector2(14, 14), Vector2(72, 72))
		draw_rect(face_rect.grow(4.0), COLOR_HUD_EDGE)
		draw_texture_rect(face, face_rect, false)

	_text(Vector2(panel.position.x + 100, panel.position.y + 40), CHAR_NAMES[_selected_char], 26, COLOR_TEXT_DARK)

	# 生命：心形图标 × 剩余条数
	var heart: Texture2D = _tex.get(HEART_TEX)
	var y := panel.position.y + 108.0
	for i in player.lives:
		var rect := Rect2(panel.position.x + 16.0 + i * 34.0, y, 30.0, 30.0)
		if heart != null:
			draw_texture_rect(heart, rect, false, Color(1, 1, 1))
		else:
			draw_circle(rect.get_center(), 12.0, Color("e53935"))
	_text(Vector2(panel.position.x + 16, y + 56), "生命 %d" % player.lives, 20, COLOR_TEXT_DARK)

	# 强化数值：用道具图标当表头，后面跟当前值
	var rows := [
		[Tiles.PowerUp.EXTRA_BOMB, "炸弹", "%d / %d" % [player.bomb_capacity - player.bombs_placed, player.bomb_capacity]],
		[Tiles.PowerUp.FIRE, "火力", "%d" % player.power],
		[Tiles.PowerUp.SPEED, "速度", "%.1f" % player.speed],
		[Tiles.PowerUp.REMOTE, "遥控", "已获得" if player.remote_capable else "未获得"],
	]
	var row_y := y + 82.0
	for row in rows:
		var icon: Texture2D = _tex.get(POWERUP_TEX[row[0]])
		var icon_rect := Rect2(panel.position.x + 16.0, row_y, 26.0, 26.0)
		_draw_frame(icon, 0, icon_rect)
		_text(Vector2(panel.position.x + 52, row_y + 21), row[1], 20, COLOR_TEXT_DARK)
		_text(Vector2(panel.position.x + 140, row_y + 21), row[2], 20, COLOR_TEXT_DARK)
		row_y += 34.0

	# 关数 / 时间 / 分数
	var info := Rect2(MARGIN, panel.end.y + MARGIN, HUD_WIDTH, 168.0)
	draw_rect(info, Color("cfe6ff"))
	draw_rect(info, Color("7fb3e8"), false, 3.0)
	_text(Vector2(info.position.x + 16, info.position.y + 34), "关数", 20, COLOR_TEXT_DARK)
	_text(Vector2(info.position.x + 16, info.position.y + 66), "%d / %d" % [session.level_index + 1, LevelData.count()], 26, COLOR_TEXT_DARK)
	_text(Vector2(info.position.x + 16, info.position.y + 104), "时间", 20, COLOR_TEXT_DARK)
	var time_color := Color("c62828") if session.time_left < 30.0 else COLOR_TEXT_DARK
	_text(Vector2(info.position.x + 16, info.position.y + 136), "%d" % int(ceil(session.time_left)), 26, time_color)
	_text(Vector2(info.position.x + 130, info.position.y + 104), "分数", 20, COLOR_TEXT_DARK)
	_text(Vector2(info.position.x + 130, info.position.y + 136), "%d" % session.total_score, 26, COLOR_TEXT_DARK)

	_draw_hud_hints()


func _draw_hud_hints() -> void:
	var y := get_viewport_rect().size.y - 92.0
	var lines := [
		"WASD / 方向键 移动   空格 放炸弹",
		"F 手动引爆（需吃到遥控道具）",
		"P 暂停   R 重开   ESC 返回选人",
	]
	for line in lines:
		_text(Vector2(MARGIN, y), line, 16, Color("9d8fb0"))
		y += 26.0

	if _paused:
		var size := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		_text_center(size.x * 0.5, size.y * 0.5, "已暂停", 52, COLOR_TEXT_LIGHT)
		_text_center(size.x * 0.5, size.y * 0.5 + 44, "按 P 继续", 22, COLOR_TEXT_LIGHT)


func _draw_banner() -> void:
	if _banner_time <= 0.0:
		return
	var alpha := clampf(_banner_time, 0.0, 1.0)
	var size := get_viewport_rect().size
	var center_x := BOARD_ORIGIN.x + _board_size().x * 0.5
	_text_center(center_x, BOARD_ORIGIN.y + 40.0, _banner_text, 40, Color(1, 1, 1, alpha))


func _text(pos: Vector2, content: String, size: int, color: Color) -> void:
	draw_string(_font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center(center_x: float, baseline_y: float, content: String, size: int, color: Color) -> void:
	var width := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(center_x - width * 0.5, baseline_y), content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# ---------------------------------------------------------------- 标题 / 选人

func _draw_title() -> void:
	var size := get_viewport_rect().size
	var art: Texture2D = _tex.get(TITLE_ART)
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a1d4d"))
	_text_center(size.x * 0.5, size.y - 150.0, "Q 版炸弹人", 64, COLOR_TEXT_LIGHT)
	_text_center(size.x * 0.5, size.y - 96.0, "空格 / 回车 开始", 26, Color(1, 1, 1, 0.75 + 0.25 * sin(_anim_time * 4.0)))


func _draw_select() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1436"))
	_text_center(size.x * 0.5, 84.0, "选择角色", 42, COLOR_TEXT_LIGHT)

	var count := CHAR_SHEETS.size()
	var card := 200.0
	var gap := 26.0
	var total := count * card + (count - 1) * gap
	var start_x := (size.x - total) * 0.5
	var top := 150.0
	for i in count:
		var rect := Rect2(start_x + i * (card + gap), top, card, card + 62.0)
		var picked := i == _selected_char
		draw_rect(rect, Color("2b2150"))
		draw_rect(rect, Color("ffd54f") if picked else Color("4a3d75"), false, 4.0)
		var art: Texture2D = _tex.get(CHAR_ART[i])
		if art != null:
			var inner := rect.grow(-14.0)
			inner.size.y = card - 14.0
			draw_texture_rect(art, inner, false)
		_text_center(
			rect.get_center().x,
			rect.end.y - 22.0,
			CHAR_NAMES[i],
			24,
			COLOR_TEXT_LIGHT if picked else Color("b6a8d8")
		)
		if picked:
			var bob := sin(_anim_time * 6.0) * 6.0
			_text_center(rect.get_center().x, rect.position.y - 16.0 + bob, "▼", 28, Color("ffd54f"))

	_text_center(size.x * 0.5, size.y - 96.0, "A / D 切换角色    空格 / 回车 开始", 24, COLOR_TEXT_LIGHT)
	_text_center(size.x * 0.5, size.y - 58.0, "ESC 返回标题", 18, Color("9d8fb0"))
