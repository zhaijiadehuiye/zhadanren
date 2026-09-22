class_name Tiles
extends RefCounted
## 地图格子与道具的类型定义。
##
## 纯数据定义，无副作用，可被逻辑层与视图层共同引用。

## 地图格子类型。
enum Kind {
	EMPTY, ## 可通行空地
	WALL, ## 不可摧毁的硬墙
	BLOCK, ## 可被炸弹摧毁的软方块（对应参考视频里的兔子砖块）
}

## 道具类型（对应参考视频里掉落的炸弹 / 火焰 / 星星 / 水滴图标）。
enum PowerUp {
	EXTRA_BOMB, ## 炸弹携带数 +1
	FIRE, ## 火力（爆炸半径）+1
	SPEED, ## 移动速度提升
	SHIELD, ## 获得一段时间的护盾
}
