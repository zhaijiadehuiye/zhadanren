# Q 版炸弹人

4399 风格 **Q 版炸弹人 / 泡泡堂** 玩法的 Godot 4 复刻：双人对战、放炸弹、炸方块、吃道具、决出胜负。

> 玩法参考视频：`【番外篇】盗版炸弹人？还记得曾经火爆4399的Q版泡泡堂吗？？.flv`
> 完整的玩法规格、架构约定与**强制开发规则**见 [agents.md](agents.md)。

## 环境要求

- Godot **4.3**（stable），渲染后端 GL Compatibility
- macOS 默认 Godot 路径为 `/Applications/Godot.app/Contents/MacOS/Godot`，其他平台用 `GODOT_BIN` 指定

## 快速开始

```bash
# 1. 首次克隆后导入资源（生成 .godot/ 与全局类缓存）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import

# 2. 跑测试
./tests/run_tests.sh

# 3. 运行游戏
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 操作

| 玩家 | 移动 | 放炸弹 |
| --- | --- | --- |
| P1 | `W` `A` `S` `D` | `空格` |
| P2 | `↑` `↓` `←` `→` | `回车` |

`R` 重开一局。

## 玩法要点

- 俯视方格地图（默认 15 × 13），**硬墙**不可摧毁，**软方块**可被炸掉。
- 炸弹引信 2.5 秒，爆炸为**十字范围**，半径等于火力值；范围内有其他炸弹会**连锁引爆**。
- 软方块被炸毁后有概率掉落道具：**炸弹数 +1 / 火力 +1 / 速度提升 / 护盾**。
- 被爆炸覆盖即阵亡（护盾期间免疫）；只剩一人存活时该玩家获胜。

## 目录结构

```
scripts/core/   纯逻辑层（RefCounted，可在 headless 下单测，禁止依赖场景树）
scripts/main.gd 视图层（渲染 + 输入翻译，不含任何玩法判定）
tests/          轻量单元测试框架与用例
scenes/         Godot 场景
assets/         美术与音频素材
```

## 开发约定

本仓库有**两条强制规则**，任何改动都必须遵守：

1. **每次代码修改，必须生成 git commit 版本快照**，便于追踪与回退。
2. **修改代码后必须编写 / 更新测试，交付前自行跑测试**（`./tests/run_tests.sh` 必须全绿）。

详见 [agents.md](agents.md) 第 4 节。

## 当前状态

可运行的双人对战骨架：核心逻辑完整、99 项断言全绿，渲染为几何占位图形，美术素材待接入。
