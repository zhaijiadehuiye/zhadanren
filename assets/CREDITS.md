# 素材署名与来源（CREDITS）

本项目的美术素材与一部分音效来自 **Ninja Adventure Asset Pack**；BGM 与手感类音效
（`bgm_*.wav` / `fuse.wav` / `step.wav` / `level_clear2.wav` / `ready.wav` / `go.wav`）
为本项目**原创合成**，不引用任何第三方作品，无版权风险。

| 项目 | 内容 |
| --- | --- |
| 素材包名称 | Ninja Adventure Asset Pack |
| 作者 | Pixel-Boy（图形 / 动画）、AAA（音乐 / 音效） |
| 许可 | CC0 1.0 Universal（公共领域贡献） |
| 商用 | 允许（可用于商业游戏） |
| 修改 | 允许 |
| 署名 | 无需署名（本文件为自愿署名，表示感谢） |
| 来源链接 | https://pixel-boy.itch.io/ninja-adventure-asset-pack |
| 作者主页 | https://pixel-boy.itch.io/ · https://www.instagram.com/challenger.aaa/ |

> CC0 1.0 Universal：作者已将作品贡献至公共领域，放弃全部著作权及相关权利。
> 可自由复制、修改、分发，包括用于商业目的，无需获得许可、无需署名。
> 许可全文见素材包内 `LICENSE.txt`。

---

## 文件对照表（项目内文件 → 素材包原路径）

以下路径均相对于素材包根目录 `NinjaAdventure/`。

### 可玩角色 `assets/sprites/characters/`

| 项目内文件 | 素材包原路径 | 尺寸 |
| --- | --- | --- |
| `ninjabomb.png` | `Actor/Characters/NinjaBomb/SpriteSheet.png` | 64×112 |
| `ninjabomb_face.png` | `Actor/Characters/NinjaBomb/Faceset.png` | 38×38 |
| `lion.png` | `Actor/Characters/Lion/SpriteSheet.png` | 64×112 |
| `lion_face.png` | `Actor/Characters/Lion/Faceset.png` | 38×38 |
| `eggboy.png` | `Actor/Characters/EggBoy/SpriteSheet.png` | 64×112 |
| `eggboy_face.png` | `Actor/Characters/EggBoy/Faceset.png` | 38×38 |
| `monkey.png` | `Actor/Characters/MonkeyBoxerBlue/SpriteSheet.png` | 64×112 |
| `monkey_face.png` | `Actor/Characters/MonkeyBoxerBlue/Faceset.png` | 38×38 |

### 敌人 `assets/sprites/enemies/`

| 项目内文件 | 素材包原路径 | 尺寸 |
| --- | --- | --- |
| `slime.png` | `Actor/Monsters/Slime/Slime.png` | 64×64 |
| `snake.png` | `Actor/Monsters/Snake/Snake.png` | 64×64 |
| `mushroom.png` | `Actor/Monsters/Mushroom/mushroom.png` | 64×64 |
| `owl.png` | `Actor/Monsters/Owl/Owl.png` | 64×64 |
| `mole.png` | `Actor/Monsters/Mole/Mole.png` | 64×64 |
| `spider.png` | `Actor/Monsters/SpiderRed/SpriteSheet.png` | 64×64 |

### 特效 `assets/sprites/fx/`

| 项目内文件 | 素材包原路径 | 尺寸 |
| --- | --- | --- |
| `fire.png` | `FX/Particle/Fire.png` | 96×12 |
| `spark.png` | `FX/Particle/Spark.png` | 70×8 |
| `rock.png` | `FX/Particle/Rock.png` | 80×16 |
| `smoke.png` | `FX/Smoke/Smoke/SpriteSheet.png` | 192×32 |

### 瓦片集 `assets/sprites/tiles/`

| 项目内文件 | 素材包原路径 | 尺寸 |
| --- | --- | --- |
| `dungeon.png` | `Backgrounds/Tilesets/TilesetDungeon.png` | 192×64 |
| `floor.png` | `Backgrounds/Tilesets/TilesetFloor.png` | 352×417 |
| `relief.png` | `Backgrounds/Tilesets/TilesetRelief.png` | 320×192 |
| `floor_detail.png` | `Backgrounds/Tilesets/TilesetFloorDetail.png` | 256×80 |

### 道具图标 `assets/sprites/items/`

| 项目内文件 | 语义 | 素材包原路径 | 尺寸 |
| --- | --- | --- | --- |
| `powerup_bomb.png` | 炸弹数 +1 | `FX/Projectile/CanonBall.png` | 80×16（5 帧动画条） |
| `powerup_fire.png` | 火力 +1 | `Items/Scroll/ScrollFire.png` | 16×16 |
| `powerup_speed.png` | 速度 +1 | `Ui/Shuriken.png` | 16×16 |
| `powerup_remote.png` | 遥控引爆 | `Items/Other/Stamp.png` | 9×9 |

### 音效 `assets/audio/`

| 项目内文件 | 素材包原路径 |
| --- | --- |
| `explosion.wav` | `Sounds/Game/Explosion.wav` |
| `fire.wav` | `Sounds/Game/Fire.wav` |
| `powerup.wav` | `Sounds/Game/PowerUp1.wav` |
| `hit.wav` | `Sounds/Game/Hit.wav` |
| `kill.wav` | `Sounds/Game/Kill.wav` |
| `game_over.wav` | `Sounds/Game/GameOver.wav` |
| `level_clear.wav` | `Sounds/Game/Success1.wav` |
| `alert.wav` | `Sounds/Game/Alert.wav` |
| `bonus.wav` | `Sounds/Game/Bonus.wav` |
| `place_bomb.wav` | `Sounds/Game/MiniImpact.wav` |

### 原创音频 `assets/audio/`（非第三方素材）

以下文件由本项目用 Python + numpy 从零合成（方波 / 三角波 / 噪声 + 包络混音），
不使用任何现成采样，可自由使用与修改。

| 项目内文件 | 用途 | 时长 | 说明 |
| --- | --- | --- | --- |
| `bgm_title.wav` | 标题页 BGM | 8.89s | 108 BPM，4 小节，无鼓组，循环播放 |
| `bgm_play.wav` | 对局 BGM | 13.71s | 140 BPM，8 小节，含鼓组；剩余时间 < 30s 时升调至 1.14x |
| `fuse.wav` | 引信滴答 | 0.05s | 场上最急的炸弹进入最后 1s 后开始滴答 |
| `step.wav` | 脚步 | 0.07s | 每成功走一格播放一次 |
| `level_clear2.wav` | 过关 jingle | 0.88s | 过关瞬间播放的欢快上行音阶 |
| `ready.wav` | 开局报数 | 0.12s | READY 倒计时每跳一个数字响一声 |
| `go.wav` | 开始 | 0.27s | 倒计时结束的「GO」上行三音 |

所有音频均为 16-bit PCM 立体声 44100Hz；生成时按目标 RMS 归一化并做 0.95 峰值限幅，
保证不同音效之间响度一致。

---

## 备注

- 文件名已统一改为小写 snake_case；未复制任何 `.meta` 文件（Unity 专用，Godot 不需要）。
- 角色精灵表 `SpriteSheet.png` 均为 64×112（4 方向 × 7 帧的 16×16 图集）。
- 敌人图集均为 64×64（4×4 的 16×16 图集）。
- `powerup_bomb.png` 源图为 80×16 的 5 帧旋转动画条；作为静态图标使用时建议用 `AtlasTexture` 取第 0 帧（16×16），或设 `hframes = 5` 播放动画。
