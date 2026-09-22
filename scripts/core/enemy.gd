class_name Enemy
extends RefCounted
## 迷宫里的敌人（纯逻辑）。
##
## 这里只保存敌人自身的状态与移动节奏；「往哪个方向走」由 GameSession 结合地图、
## 炸弹与其它敌人统一裁决，因为那需要看到全局信息。

## 行为原型：决定敌人「想往哪走」的倾向。真正能不能走由 GameSession 结合地图裁决。
enum Behavior {
	WANDER, ## 随机游走，大概率保持直行
	CHASE, ## 朝玩家方向靠拢，偶尔走神
	PATROL, ## 只直行，撞墙才拐弯，路线可预测
	SKITTISH, ## 玩家贴近时掉头躲开，离得远就照常游走
}

## 贴图种类 → 行为原型。同一种怪物永远是同一种脾气，玩家可以靠外观预判。
const BEHAVIOR_BY_KIND := [
	Behavior.WANDER, ## 史莱姆
	Behavior.CHASE, ## 蛇
	Behavior.WANDER, ## 蘑菇
	Behavior.SKITTISH, ## 猫头鹰
	Behavior.PATROL, ## 鼹鼠
	Behavior.CHASE, ## 蜘蛛
]

var id: int = 0
var cell: Vector2i = Vector2i.ZERO
## 贴图种类（0..LevelData.ENEMY_KIND_COUNT-1），同时决定行为原型。
var kind: int = 0
## 行为原型，由 kind 推导。
var behavior: int = Behavior.WANDER
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
	behavior = behavior_for_kind(p_kind)
	move_interval = maxf(p_move_interval, 0.05)


## 贴图种类对应的行为原型；越界的种类退回最普通的游走。
static func behavior_for_kind(p_kind: int) -> int:
	if p_kind < 0 or p_kind >= BEHAVIOR_BY_KIND.size():
		return Behavior.WANDER
	return BEHAVIOR_BY_KIND[p_kind]


## 推进移动计时器，返回本帧是否刚好攒够一格步长（只会返回一次 true）。
func tick(delta: float) -> bool:
	if not alive:
		return false
	move_timer += delta
	if move_timer < move_interval:
		return false
	move_timer -= move_interval
	return true
