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
	Tiles.PowerUp.GLOVE: "res://assets/sprites/items/powerup_glove.png",
}
const POWERUP_TINTS := {
	Tiles.PowerUp.EXTRA_BOMB: Color("4fc3f7"),
	Tiles.PowerUp.FIRE: Color("ff7043"),
	Tiles.PowerUp.SPEED: Color("66bb6a"),
	Tiles.PowerUp.SHIELD: Color("ba68c8"),
	Tiles.PowerUp.REMOTE: Color("ffd54f"),
	Tiles.PowerUp.GLOVE: Color("ef5350"),
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
	GameSession.EVENT_PUNCH: "res://assets/audio/punch.wav",
}
const SFX_VOICES := 8

## BGM 与「非事件型」音效（脚步、引信滴答、过关 jingle）单独走路径。
const BGM_TITLE := "res://assets/audio/bgm_title.wav"
const BGM_PLAY := "res://assets/audio/bgm_play.wav"
const SFX_FUSE := "res://assets/audio/fuse.wav"
const SFX_STEP := "res://assets/audio/step.wav"
const SFX_CLEAR := "res://assets/audio/level_clear2.wav"
const SFX_READY := "res://assets/audio/ready.wav"
const SFX_GO := "res://assets/audio/go.wav"

## 动画时长：敌人阵亡、炸弹落地弹跳。
const ENEMY_DEATH_TIME := 0.5
const BOMB_POP_TIME := 0.16
## 炸弹视觉位置追赶速度（格 / 秒）。
const BOMB_SLIDE_SPEED := 9.0
## 停下来多久才把行走动画收回站立帧，避免走格间隙里动画反复归零。
const WALK_IDLE_RESET := 0.09
## 出拳特效时长与打击停顿，让推炸弹也有一下「打中了」的手感。
const PUNCH_FLASH_TIME := 0.18
const HITSTOP_PUNCH := 0.04

## 时间紧迫时 BGM 升调加速，复刻老式炸弹人的「hurry up」压迫感。
const HURRY_TIME := 30.0
const HURRY_PITCH := 1.14

## 屏幕震动与打击停顿：让爆炸和阵亡「有重量」。
const SHAKE_EXPLOSION := 0.24
const SHAKE_PLAYER_HIT := 0.5
const SHAKE_DURATION := 0.3
const HITSTOP_EXPLOSION := 0.05
const HITSTOP_PLAYER_HIT := 0.14

## 引信进入这个窗口后开始滴答。
const FUSE_TICK_WINDOW := 1.0

## 飘分文字的存活时间与上浮速度。
const POPUP_LIFE := 0.9
const POPUP_RISE := 34.0
const POPUP_COLORS := {
	"kill": Color("ffe082"),
	"power": Color("81d4fa"),
	"chain": Color("ff8a65"),
}

## 输入缓冲：冷却期间按下的方向会被记住，冷却一结束立刻执行，避免「点了没反应」。
const INPUT_BUFFER := 0.14

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
var _bgm: AudioStreamPlayer
var _bgm_path := ""

## 玩家与敌人的「视觉格坐标」，用插值追赶逻辑格坐标，做出平滑移动。
var _player_pos := Vector2.ZERO
var _enemy_pos: Array[Vector2] = []
var _walking := false
var _move_cooldown := 0.0
var _anim_time := 0.0
var _banner_time := 0.0
var _banner_text := ""

## 行走动画相位：按实际移动速度推进，脚步与动画同步；停久了才归零回到站立帧。
var _walk_phase := 0.0
var _walk_idle := 0.0
## 敌人阵亡动画：索引 → 剩余播放时间（0 表示播完，不再绘制）。
var _enemy_death: Dictionary = {}
## 每个敌人的行走动画相位。
var _enemy_walk_phase: Array[float] = []
## 炸弹的视觉位置与落地弹跳计时，键为炸弹对象本身。
var _bomb_pos: Dictionary = {}
var _bomb_pop: Dictionary = {}
## 开局倒计时上一次报数，用来判断何时该响一声。
var _ready_last := -1
## 上一次绘制过的关卡号，用来在换关瞬间把视觉坐标拉回新地图，避免横穿地图的滑动。
var _level_seen := -1
## 出拳特效：剩余时间与出拳方向，用来在角色身前画一下冲击。
var _punch_flash := 0.0
var _punch_dir := Vector2i(0, 1)

## 手感相关的瞬时状态。
var _shake_time := 0.0
var _shake_power := 0.0
var _hitstop := 0.0
var _fuse_timer := 0.0
var _buffer_dir := Vector2i.ZERO
var _buffer_left := 0.0
## 飘分文字：{text, kind, pos(像素), life}
var _popups: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = _load_ui_font()
	_load_textures()
	_load_sfx()
	_new_session()
	_play_bgm(BGM_TITLE)


## 退出时停掉 BGM。
## 注意：Godot 4.3 的 AudioStreamPlayer.stop() 要等下一次音频混音才释放 playback，
## 而退出后不会再有混音，所以 --quit-after 这类强制退出仍会打印一条
## "resources still in use: bgm_*.wav" 的引擎警告。不影响运行，仅退出日志噪声。
func _exit_tree() -> void:
	if _bgm != null:
		_bgm.stop()
		_bgm.stream = null


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
	for path in [SFX_FUSE, SFX_STEP, SFX_CLEAR, SFX_READY, SFX_GO]:
		if ResourceLoader.exists(path):
			_sfx[path] = load(path)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_voices.append(player)

	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	_bgm.volume_db = -7.0
	add_child(_bgm)


## 切换 BGM。同一首重复调用不会打断播放。
func _play_bgm(path: String) -> void:
	if _bgm == null or path == _bgm_path or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		# WAV 的循环标记在导入设置里，运行时显式打开更稳。
		var bytes_per_frame := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if stream.stereo:
			bytes_per_frame *= 2
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / bytes_per_frame
	_bgm_path = path
	_bgm.stream = stream
	_bgm.play()


func _play_path(path: String) -> void:
	var stream: AudioStream = _sfx.get(path)
	if stream != null:
		_play_stream(stream)


func _play_sfx(event: String) -> void:
	var stream: AudioStream = _sfx.get(event)
	if stream != null:
		_play_stream(stream)


func _play_stream(stream: AudioStream) -> void:
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
	_banner_text = ""
	_banner_time = 0.0
	_shake_time = 0.0
	_shake_power = 0.0
	_hitstop = 0.0
	_fuse_timer = 0.0
	_buffer_dir = Vector2i.ZERO
	_buffer_left = 0.0
	_popups.clear()
	_ready_last = -1
	_level_seen = session.level_index
	_bomb_pos.clear()
	_bomb_pop.clear()
	_punch_flash = 0.0


## 让视觉坐标立刻对齐逻辑坐标（重开、换关、复活时用，避免出现横穿地图的滑动）。
func _sync_visual_positions(force: bool = false) -> void:
	if session == null:
		return
	if force:
		_player_pos = Vector2(session.player.cell)
		_walk_phase = 0.0
		_walk_idle = 0.0
		_enemy_death.clear()
		_bomb_pos.clear()
		_bomb_pop.clear()
	_enemy_pos.resize(session.enemies.size())
	_enemy_walk_phase.resize(session.enemies.size())
	for i in session.enemies.size():
		if force or i >= _enemy_pos.size():
			_enemy_pos[i] = Vector2(session.enemies[i].cell)
			_enemy_walk_phase[i] = 0.0
		# 已经在场上阵亡的敌人不补播动画（换关/复活后直接消失）。
		if not session.enemies[i].alive:
			_enemy_death[i] = 0.0


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	_handle_key(event.physical_keycode)


func _handle_key(keycode: int) -> void:
	match _scene:
		Scene.TITLE:
			if keycode == KEY_SPACE or keycode == KEY_ENTER:
				_go_to(Scene.SELECT)
		Scene.SELECT:
			if keycode == KEY_A or keycode == KEY_LEFT:
				_selected_char = wrapi(_selected_char - 1, 0, CHAR_SHEETS.size())
			elif keycode == KEY_D or keycode == KEY_RIGHT:
				_selected_char = wrapi(_selected_char + 1, 0, CHAR_SHEETS.size())
			elif keycode == KEY_SPACE or keycode == KEY_ENTER:
				_go_to(Scene.PLAY)
				_new_session()
			elif keycode == KEY_ESCAPE:
				_go_to(Scene.TITLE)
		Scene.PLAY:
			_handle_play_key(keycode)


## 切换场景时同步切换 BGM：标题/选人用舒缓版，对局用欢快版。
func _go_to(scene: int) -> void:
	_scene = scene
	_paused = false
	_play_bgm(BGM_PLAY if scene == Scene.PLAY else BGM_TITLE)
	if scene == Scene.TITLE and _bgm != null:
		_bgm.pitch_scale = 1.0


func _handle_play_key(keycode: int) -> void:
	match keycode:
		KEY_R:
			_new_session()
		KEY_P:
			_paused = not _paused
		KEY_ESCAPE:
			_go_to(Scene.SELECT)
		KEY_SPACE:
			if session.place_bomb():
				_move_cooldown = 0.05
		KEY_F:
			session.detonate_remote()
		KEY_J:
			if session.punch_bomb():
				_punch_dir = session.player.facing
				_punch_flash = PUNCH_FLASH_TIME
				_hitstop = maxf(_hitstop, HITSTOP_PUNCH)
		KEY_ENTER:
			if not session.is_playing() and session.phase == GameSession.Phase.GAME_OVER:
				_new_session()


## 方向键 / WASD 用轮询而不是事件，这样按住可以连续走格。
## 两个手感要点：
##   1. 转向即时生效（撞墙也会转身），按下去立刻有反馈；
##   2. 冷却期间按下的方向进缓冲，冷却一结束立刻执行，避免「点了没反应」。
func _poll_movement(delta: float) -> void:
	_move_cooldown = maxf(_move_cooldown - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)

	var held := _held_direction()
	if held != Vector2i.ZERO:
		_buffer_dir = held
		_buffer_left = INPUT_BUFFER
	var direction := held
	if direction == Vector2i.ZERO and _buffer_left > 0.0:
		direction = _buffer_dir

	if direction == Vector2i.ZERO or not session.is_playing():
		return

	# 转向先于移动生效，撞墙时也能看到角色转身。
	session.face(direction)

	if _move_cooldown > 0.0:
		return

	if session.move_player(direction):
		_buffer_left = 0.0
		_move_cooldown = _step_duration()
		_play_path(SFX_STEP)
	else:
		# 撞墙只给很短冷却，避免按住方向键时贴墙卡顿。
		_move_cooldown = 0.05


func _held_direction() -> Vector2i:
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		return Vector2i(0, -1)
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		return Vector2i(0, 1)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		return Vector2i(-1, 0)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _step_duration() -> float:
	return clampf(0.56 / maxf(session.player.speed, 0.5), 0.06, 0.34)


# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	_anim_time += delta
	_banner_time = maxf(_banner_time - delta, 0.0)
	_update_shake(delta)
	_update_popups(delta)

	if _scene == Scene.PLAY:
		if not _paused:
			# 打击停顿：爆炸/阵亡瞬间冻结逻辑几十毫秒，让冲击有分量。
			if _hitstop > 0.0:
				_hitstop = maxf(_hitstop - delta, 0.0)
			else:
				session.tick(delta)
				_poll_movement(delta)
				_drain_events()
				_update_fuse_tick(delta)
				_update_ready_tick()
			_update_hurry()
		_update_visual_positions(delta)

	queue_redraw()


## 屏幕震动：按剩余时间线性衰减的随机偏移。
func _update_shake(delta: float) -> void:
	_shake_time = maxf(_shake_time - delta, 0.0)
	if _shake_time <= 0.0:
		_shake_power = 0.0


func _add_shake(power: float) -> void:
	_shake_power = maxf(_shake_power, power)
	_shake_time = SHAKE_DURATION


func _shake_offset() -> Vector2:
	if _shake_time <= 0.0 or _shake_power <= 0.0:
		return Vector2.ZERO
	var amp := _shake_power * clampf(_shake_time / SHAKE_DURATION, 0.0, 1.0)
	return Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


## 引信滴答：场上最急的那颗炸弹越接近爆炸，滴答越密，制造紧张感。
func _update_fuse_tick(delta: float) -> void:
	var most_urgent := INF
	for bomb in session.bombs:
		if not bomb.remote:
			most_urgent = minf(most_urgent, bomb.fuse)
	if most_urgent == INF or most_urgent > FUSE_TICK_WINDOW:
		_fuse_timer = 0.0
		return
	_fuse_timer -= delta
	if _fuse_timer > 0.0:
		return
	_play_path(SFX_FUSE)
	_fuse_timer = lerpf(0.09, 0.3, clampf(most_urgent / FUSE_TICK_WINDOW, 0.0, 1.0))


## 开局倒计时：每跳一个数字响一声，让「准备」阶段也有节拍感。
func _update_ready_tick() -> void:
	if session.phase != GameSession.Phase.READY:
		_ready_last = -1
		return
	var current := int(ceil(session.phase_time_left))
	if current == _ready_last:
		return
	_ready_last = current
	if current > 0:
		_play_path(SFX_READY)


## 时间所剩无几时给 BGM 升调加速，复刻老式炸弹人的「hurry up」压迫感。
func _update_hurry() -> void:
	if _bgm == null:
		return
	var hurry := session.is_playing() and session.time_left < HURRY_TIME
	_bgm.pitch_scale = HURRY_PITCH if hurry else 1.0


func _update_popups(delta: float) -> void:
	for i in range(_popups.size() - 1, -1, -1):
		var entry: Dictionary = _popups[i]
		entry["life"] -= delta
		entry["pos"] += Vector2(0.0, -POPUP_RISE * delta)
		if entry["life"] <= 0.0:
			_popups.remove_at(i)


func _drain_events() -> void:
	for event in session.pop_events():
		_play_sfx(event)
		match event:
			GameSession.EVENT_LEVEL_START:
				_banner_text = "第 %d 关 开始！" % (session.level_index + 1)
				_banner_time = 1.2
				_play_path(SFX_GO)
			GameSession.EVENT_PLACE_BOMB:
				var placed := session.bomb_at(session.player.cell)
				if placed != null:
					_bomb_pop[placed] = BOMB_POP_TIME
			GameSession.EVENT_EXPLOSION:
				_add_shake(SHAKE_EXPLOSION)
				_hitstop = maxf(_hitstop, HITSTOP_EXPLOSION)
			GameSession.EVENT_PLAYER_HIT:
				_add_shake(SHAKE_PLAYER_HIT)
				_hitstop = maxf(_hitstop, HITSTOP_PLAYER_HIT)
			GameSession.EVENT_LEVEL_CLEAR:
				_banner_text = "过关！"
				_banner_time = 1.6
				_play_path(SFX_CLEAR)
			GameSession.EVENT_EXIT_FOUND:
				_banner_text = "发现出口！"
				_banner_time = 1.6
			GameSession.EVENT_GAME_OVER:
				_banner_text = "通关！" if session.campaign_cleared else "游戏结束"
				_banner_time = 3.0
			GameSession.EVENT_RESPAWN:
				_sync_visual_positions(true)

	for entry in session.pop_popups():
		_popups.append({
			"text": entry["text"],
			"kind": entry["kind"],
			"pos": _center_of(Vector2(entry["cell"])) + Vector2(0, -CELL * 0.2),
			"life": POPUP_LIFE,
		})


## 视觉坐标以固定速度追赶逻辑坐标。追赶速度取「走一格时间的 1.15 倍」，
## 让精灵在一格冷却结束前刚好到位，连起来是连续滑动而不是走一步停一下。
func _update_visual_positions(delta: float) -> void:
	_punch_flash = maxf(_punch_flash - delta, 0.0)
	# 换关瞬间：敌人数量可能和新关卡一样，光靠长度判断会漏掉，所以直接比关卡号。
	if session.level_index != _level_seen:
		_level_seen = session.level_index
		_sync_visual_positions(true)
	if session.player.alive:
		var target := Vector2(session.player.cell)
		var catch_up := 1.15 / _step_duration()
		_walking = _player_pos.distance_to(target) > 0.04
		_player_pos = _player_pos.move_toward(target, catch_up * delta)
	else:
		_walking = false
	_update_walk_phase(delta)

	if _enemy_pos.size() != session.enemies.size():
		_sync_visual_positions(true)
	for i in session.enemies.size():
		var enemy := session.enemies[i]
		if not enemy.alive:
			# 刚阵亡的敌人开播死亡动画，已经播完的保持 0 不再绘制。
			_enemy_death[i] = (
				ENEMY_DEATH_TIME if not _enemy_death.has(i)
				else maxf(float(_enemy_death[i]) - delta, 0.0)
			)
			continue
		_enemy_death.erase(i)
		var target := Vector2(enemy.cell)
		var interval := maxf(enemy.move_interval, 0.05)
		_enemy_pos[i] = _enemy_pos[i].move_toward(target, 1.25 / interval * delta)
		if _enemy_pos[i].distance_to(target) > 0.02:
			_enemy_walk_phase[i] = float(_enemy_walk_phase[i]) + delta / interval
		else:
			_enemy_walk_phase[i] = 0.0

	_update_bomb_visuals(delta)


## 行走动画相位按实际移动速度推进，走一格刚好走完一个循环，脚步与动画自然同步。
func _update_walk_phase(delta: float) -> void:
	if _walking:
		_walk_phase += delta / _step_duration()
		_walk_idle = 0.0
		return
	_walk_idle += delta
	if _walk_idle > WALK_IDLE_RESET:
		_walk_phase = 0.0


## 炸弹的视觉位置独立插值：位置变化时能看到滑动而不是瞬移；落地时补一个弹跳。
func _update_bomb_visuals(delta: float) -> void:
	for bomb in session.bombs:
		var target := Vector2(bomb.cell)
		if _bomb_pos.has(bomb):
			_bomb_pos[bomb] = (_bomb_pos[bomb] as Vector2).move_toward(target, BOMB_SLIDE_SPEED * delta)
		else:
			_bomb_pos[bomb] = target
	for key in _bomb_pos.keys():
		if not session.bombs.has(key):
			_bomb_pos.erase(key)
			_bomb_pop.erase(key)
	for key in _bomb_pop.keys():
		_bomb_pop[key] = maxf(float(_bomb_pop[key]) - delta, 0.0)


## 行走图集的行号：相位每前进 1.0 走完 4 帧。
func _walk_row(phase: float) -> int:
	return int(phase * 4.0) % 4


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
	# 只让棋盘内容震动，HUD 与横幅保持稳定，避免文字抖到看不清。
	draw_set_transform(_shake_offset())
	_draw_board()
	_draw_exit()
	_draw_powerups()
	_draw_blasts()
	_draw_enemies()
	_draw_player()
	# 炸弹画在角色之后：站在自己刚放的炸弹上时也必须看得见它，否则容易误踩送命。
	_draw_bombs()
	_draw_punch_flash()
	_draw_popups()
	draw_set_transform(Vector2.ZERO)
	_draw_ready_overlay()
	_draw_hud()
	_draw_banner()


## 开局倒计时：压暗棋盘并报数，让玩家看清地图再出发。
func _draw_ready_overlay() -> void:
	if session.phase != GameSession.Phase.READY:
		return
	var board := Rect2(BOARD_ORIGIN, _board_size())
	draw_rect(board, Color(0.05, 0.03, 0.12, 0.55))
	var center := board.get_center()
	_text_center(center.x, center.y - 30.0, "第 %d 关" % (session.level_index + 1), 34, COLOR_TEXT_LIGHT)
	_text_center(center.x, center.y + 30.0, str(int(ceil(session.phase_time_left))), 76, Color("ffd54f"))


func _draw_popups() -> void:
	for entry in _popups:
		var alpha := clampf(entry["life"] / POPUP_LIFE, 0.0, 1.0)
		var color: Color = POPUP_COLORS.get(entry["kind"], Color.WHITE)
		color.a = alpha
		var size := 26 if entry["kind"] == "chain" else 20
		var pos: Vector2 = entry["pos"]
		_text_center(pos.x, pos.y, entry["text"], size, color)


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
func _draw_sheet(
	tex: Texture2D, col: int, row: int, rect: Rect2, rows: int, tint: Color = Color.WHITE
) -> void:
	if tex == null:
		return
	var cw := tex.get_width() / 4.0
	var ch := tex.get_height() / float(rows)
	draw_texture_rect_region(tex, rect, Rect2(float(col) * cw, float(row) * ch, cw, ch), tint)


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
		var center := _center_of(_bomb_pos.get(bomb, Vector2(bomb.cell)))
		# 遥控炸弹不倒数，改成稳定的金色呼吸；普通炸弹越接近爆炸闪得越快。
		if bomb.remote:
			var breathe := 1.0 + 0.08 * sin(_anim_time * 6.0)
			draw_circle(center, CELL * 0.42 * breathe, Color(1.0, 0.84, 0.3, 0.35))
			draw_circle(center, CELL * 0.34, Color(1.0, 0.9, 0.45, 0.5))
		else:
			var urgency := clampf(1.0 - bomb.fuse / GameSession.DEFAULT_FUSE, 0.0, 1.0)
			var blink := 0.5 + 0.5 * sin(_anim_time * (6.0 + urgency * 26.0))
			draw_circle(center, CELL * 0.42, Color(1.0, 0.35 + 0.3 * urgency, 0.2, 0.25 + 0.35 * blink))
		# 刚落地的炸弹从偏大缩回原尺寸，给「放下去」一个实感。
		var pop := float(_bomb_pop.get(bomb, 0.0)) / BOMB_POP_TIME
		var size := CELL * 0.86 * (1.0 + 0.06 * sin(_anim_time * 9.0) + 0.3 * pop)
		_draw_frame(ball, int(_anim_time * 10.0), Rect2(
			center.x - size * 0.5, center.y - size * 0.5, size, size
		))


## 出拳特效：在角色身前画一圈快速扩散并淡出的冲击环，让「推炸弹」这一下看得见。
func _draw_punch_flash() -> void:
	if _punch_flash <= 0.0:
		return
	var progress := 1.0 - _punch_flash / PUNCH_FLASH_TIME
	var center := _center_of(_player_pos + Vector2(_punch_dir) * (0.45 + 0.55 * progress))
	var alpha := 1.0 - progress
	draw_circle(center, CELL * (0.20 + 0.34 * progress), Color(1.0, 0.95, 0.7, 0.45 * alpha))
	draw_arc(
		center, CELL * (0.28 + 0.44 * progress), 0.0, TAU, 28,
		Color(1.0, 0.85, 0.4, alpha), 5.0
	)


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
			_draw_enemy_death(i)
			continue
		var pos: Vector2 = _enemy_pos[i] if i < _enemy_pos.size() else Vector2(enemy.cell)
		var sheet: Texture2D = _tex.get(ENEMY_SHEETS[enemy.kind % ENEMY_SHEETS.size()])
		draw_circle(_center_of(pos) + Vector2(0, CELL * 0.34), CELL * 0.26, Color(0, 0, 0, 0.25))
		var phase: float = _enemy_walk_phase[i] if i < _enemy_walk_phase.size() else 0.0
		_draw_sheet(sheet, _dir_column(enemy.facing), _walk_row(phase), _sprite_rect(pos), 4)


## 敌人阵亡：本体缩小上飘淡出，同时冒一团烟，比直接消失更容易看清「炸到了」。
func _draw_enemy_death(index: int) -> void:
	var left := float(_enemy_death.get(index, 0.0))
	if left <= 0.0 or index >= _enemy_pos.size():
		return
	var progress := 1.0 - left / ENEMY_DEATH_TIME
	var center := _center_of(_enemy_pos[index])
	var smoke: Texture2D = _tex.get(SMOKE_TEX)
	var smoke_size := CELL * (0.7 + 0.8 * progress)
	_draw_frame(
		smoke,
		int(progress * 7.0),
		Rect2(center.x - smoke_size * 0.5, center.y - smoke_size * 0.5, smoke_size, smoke_size),
		Color(1, 1, 1, 0.85 * (1.0 - progress))
	)
	var enemy := session.enemies[index]
	var sheet: Texture2D = _tex.get(ENEMY_SHEETS[enemy.kind % ENEMY_SHEETS.size()])
	var shrink := 1.0 - 0.65 * progress
	var base := _sprite_rect(_enemy_pos[index] + Vector2(0.0, -progress * 0.6))
	var rect := Rect2(base.get_center() - base.size * 0.5 * shrink, base.size * shrink)
	_draw_sheet(
		sheet, _dir_column(enemy.facing), int(progress * 9.0) % 4, rect, 4,
		Color(1, 1, 1, 1.0 - progress)
	)


func _draw_player() -> void:
	if not session.player.alive:
		_draw_player_death()
		return
	var player := session.player
	var center := _center_of(_player_pos)
	if player.has_shield():
		var glow := 0.35 + 0.15 * sin(_anim_time * 8.0)
		draw_circle(center, CELL * 0.55, Color(0.45, 0.9, 1.0, glow))
		draw_circle(center, CELL * 0.46, Color(0.85, 0.97, 1.0, 0.22))
	draw_circle(center + Vector2(0, CELL * 0.34), CELL * 0.26, Color(0, 0, 0, 0.28))
	var sheet: Texture2D = _tex.get(CHAR_SHEETS[_selected_char])
	_draw_sheet(sheet, _dir_column(player.facing), _walk_row(_walk_phase), _sprite_rect(_player_pos), 7)


## 玩家阵亡：本体原地打转、缩小并淡出。
## 用四个朝向循环冒充「旋转」，比真去旋转像素精灵更贴合这套 16×16 图集。
## 动画只占阵亡过渡的前 60%，剩下的时间保持「人已经不在了」，读起来更清楚。
func _draw_player_death() -> void:
	if session.phase != GameSession.Phase.DYING:
		return
	var span := GameSession.DYING_DELAY * 0.6
	var progress := clampf(1.0 - session.phase_time_left / span, 0.0, 1.0)
	var sheet: Texture2D = _tex.get(CHAR_SHEETS[_selected_char])
	var shrink := 1.0 - 0.45 * progress
	var base := _sprite_rect(_player_pos + Vector2(0.0, -progress * 0.5))
	var rect := Rect2(base.get_center() - base.size * 0.5 * shrink, base.size * shrink)
	_draw_sheet(sheet, int(progress * 10.0) % 4, 0, rect, 7, Color(1, 1, 1, 1.0 - progress))


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
		[Tiles.PowerUp.GLOVE, "手套", "已获得" if player.glove else "未获得"],
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
	var y := get_viewport_rect().size.y - 118.0
	var lines := [
		"WASD / 方向键 移动   空格 放炸弹",
		"F 手动引爆（需吃到遥控道具）",
		"J 推炸弹（需吃到拳击手套）",
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
