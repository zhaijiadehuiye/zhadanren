class_name PowerUp
extends RefCounted
## 地图上等待被拾取的道具。

var cell: Vector2i
var kind: int


func _init(p_cell: Vector2i, p_kind: int) -> void:
	cell = p_cell
	kind = p_kind
