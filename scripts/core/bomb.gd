class_name Bomb
extends RefCounted
## 一颗已放置的炸弹的状态（纯逻辑）。

var cell: Vector2i
var owner_id: int
var power: int
var fuse: float
## 遥控炸弹不会自己炸，必须由玩家手动引爆（吃到遥控道具后放置的炸弹）。
var remote: bool = false
var exploded: bool = false


func _init(
	p_cell: Vector2i,
	p_owner_id: int,
	p_power: int,
	p_fuse: float = 2.5,
	p_remote: bool = false
) -> void:
	cell = p_cell
	owner_id = p_owner_id
	power = maxi(p_power, 1)
	fuse = p_fuse
	remote = p_remote


## 推进引信，返回本帧是否刚好引爆（只会返回一次 true）。遥控炸弹永远返回 false。
func tick(delta: float) -> bool:
	if exploded or remote:
		return false
	fuse -= delta
	if fuse <= 0.0:
		fuse = 0.0
		exploded = true
		return true
	return false
