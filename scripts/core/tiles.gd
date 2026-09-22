class_name Tiles
extends RefCounted
## 地图格子与道具的类型定义。
##
## 纯数据定义，无副作用，可被逻辑层与视图层共同引用。

## 地图格子类型。
enum Kind {
	EMPTY, ## 可通行空地
	WALL, ## 不可摧毁的硬墙，同时阻挡爆炸
	BLOCK, ## 可被炸弹摧毁的软砖，炸掉后可能露出道具或隐藏出口
	EXIT, ## 藏在软砖下的出口；软砖被炸毁后显现，清光敌人后踩上去过关
}

## 道具类型（软砖被炸毁后有概率掉落）。
enum PowerUp {
	EXTRA_BOMB, ## 炸弹携带数 +1
	FIRE, ## 火力（爆炸半径）+1
	SPEED, ## 移动速度提升
	SHIELD, ## 获得一段时间的护盾，免疫爆炸与敌人接触
	REMOTE, ## 获得遥控引爆能力，可手动引爆自己放的炸弹
}

## 该格子是否可被炸弹摧毁。
static func is_destructible(kind: int) -> bool:
	return kind == Kind.BLOCK

## 该格子是否可被玩家与敌人通行。
static func is_walkable_kind(kind: int) -> bool:
	return kind == Kind.EMPTY or kind == Kind.EXIT

## 该格子是否阻挡爆炸扩散。
static func blocks_blast(kind: int) -> bool:
	return kind == Kind.WALL
