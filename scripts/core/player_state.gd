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

var id: int = 0
var cell: Vector2i = Vector2i.ZERO
var alive: bool = true
var bomb_capacity: int = DEFAULT_BOMB_CAPACITY
var power: int = DEFAULT_POWER
var speed: float = DEFAULT_SPEED
var shield_time: float = 0.0
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


func tick(delta: float) -> void:
	if shield_time > 0.0:
		shield_time = maxf(shield_time - delta, 0.0)
