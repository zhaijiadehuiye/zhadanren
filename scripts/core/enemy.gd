class_name Enemy
extends RefCounted
## 迷宫里的敌人（纯逻辑）。
##
## 这里只保存敌人自身的状态与移动节奏；「往哪个方向走」由 GameSession 结合地图、
## 炸弹与其它敌人统一裁决，因为那需要看到全局信息。

var id: int = 0
var cell: Vector2i = Vector2i.ZERO
## 贴图种类（0..LevelData.ENEMY_KIND_COUNT-1），只影响表现，不影响数值。
var kind: int = 0
var alive: bool = true
## 当前朝向，用于渲染与「尽量直行」的移动倾向。
var facing: Vector2i = Vector2i(0, 1)
## 走一格所需的秒数，越小越快。
var move_interval: float = 0.7
var move_timer: float = 0.0


func _init(
	p_id: int = 0,
	p_cell: Vector2i = Vector2i.ZERO,
	p_kind: int = 0,
	p_move_interval: float = 0.7
) -> void:
	id = p_id
	cell = p_cell
	kind = p_kind
	move_interval = maxf(p_move_interval, 0.05)


## 推进移动计时器，返回本帧是否刚好攒够一格步长（只会返回一次 true）。
func tick(delta: float) -> bool:
	if not alive:
		return false
	move_timer += delta
	if move_timer < move_interval:
		return false
	move_timer -= move_interval
	return true
