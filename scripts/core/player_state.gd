class_name PlayerState
extends RefCounted
## 单个玩家的状态与成长数值（纯逻辑）。

const DEFAULT_BOMB_CAPACITY := 1
const DEFAULT_POWER := 1
const DEFAULT_SPEED := 3.0
const MAX_BOMB_CAPACITY := 8
const MAX_POWER := 8
const MAX_SPEED := 6.0
const SPEED_STEP := 0.5
const SHIELD_DURATION := 8.0
const DEFAULT_LIVES := 3
## 复活后附带的短暂无敌时间，避免刚出生就被贴脸的敌人或火焰秒杀。
const RESPAWN_SHIELD := 2.0

var id: int = 0
var cell: Vector2i = Vector2i.ZERO
var alive: bool = true
var bomb_capacity: int = DEFAULT_BOMB_CAPACITY
var power: int = DEFAULT_POWER
var speed: float = DEFAULT_SPEED
var shield_time: float = 0.0
var lives: int = DEFAULT_LIVES
## 是否已获得遥控引爆能力（吃到遥控道具后永久生效）。
var remote_capable: bool = false
## 是否已获得拳击手套，可以把正前方的炸弹推出去（吃到后永久生效）。
var glove: bool = false
## 最近一次的移动朝向，供渲染层选方向贴图。
var facing: Vector2i = Vector2i(0, 1)
## 当前已放置、尚未爆炸的炸弹数。
var bombs_placed: int = 0


func _init(p_id: int = 0, p_cell: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	cell = p_cell


func can_place_bomb() -> bool:
	return alive and bombs_placed < bomb_capacity


func has_shield() -> bool:
	return shield_time > 0.0


func apply_powerup(kind: int) -> void:
	match kind:
		Tiles.PowerUp.EXTRA_BOMB:
			bomb_capacity = mini(bomb_capacity + 1, MAX_BOMB_CAPACITY)
		Tiles.PowerUp.FIRE:
			power = mini(power + 1, MAX_POWER)
		Tiles.PowerUp.SPEED:
			speed = minf(speed + SPEED_STEP, MAX_SPEED)
		Tiles.PowerUp.SHIELD:
			shield_time = SHIELD_DURATION
		Tiles.PowerUp.REMOTE:
			remote_capable = true
		Tiles.PowerUp.GLOVE:
			glove = true


## 复活：清掉临时状态并给一段无敌时间，成长数值（炸弹数/火力/速度/遥控/手套）保留。
func reset_for_respawn(p_cell: Vector2i) -> void:
	cell = p_cell
	alive = true
	bombs_placed = 0
	shield_time = RESPAWN_SHIELD


func tick(delta: float) -> void:
	if shield_time > 0.0:
		shield_time = maxf(shield_time - delta, 0.0)
