class_name Bomb
extends RefCounted
## 一颗已放置的炸弹的状态（纯逻辑）。

var cell: Vector2i
var owner_id: int
var power: int
var fuse: float
var exploded: bool = false


func _init(p_cell: Vector2i, p_owner_id: int, p_power: int, p_fuse: float = 2.5) -> void:
	cell = p_cell
	owner_id = p_owner_id
	power = maxi(p_power, 1)
	fuse = p_fuse


## 推进引信，返回本帧是否刚好引爆（只会返回一次 true）。
func tick(delta: float) -> bool:
	if exploded:
		return false
	fuse -= delta
	if fuse <= 0.0:
		fuse = 0.0
		exploded = true
		return true
	return false
