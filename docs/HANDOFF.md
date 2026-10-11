# 交接文档（云端 → 本地）

> 写于 2026-10-11。分支 `claude/emergence-game-design-auy1xn`。
> 读完这一页就能接着做；细节在 `docs/design/` 和代码注释里。

---

## 1. 现在是什么状态

一个**可玩的竖切原型**：街道 → 城市 → 拉远到地球（预览）。核心交互、连锁、坍缩、字幕、阶段过渡、狂热模式都在。没做的见 §7。

一句话玩法：**按住吸，松开推。被砸中的东西会"涌现"出别的东西，同类堆够数量会"坍缩"成更高级的东西。**

---

## 2. 本地跑起来

1. 拉分支：
   ```
   git fetch origin
   git checkout claude/emergence-game-design-auy1xn
   ```
2. 用 **Godot 4.7**（`project.godot` 里写的是 4.7；云端是用 4.6 测的，也能跑）打开仓库根目录，等首次导入完，F5。
3. 字体样张：打开 `scenes/wordart_specimen.tscn`，F6。

操作：

| 输入 | 作用 |
|---|---|
| WASD / 左摇杆 | 走 |
| 鼠标 / 右摇杆 | 转镜头 |
| **按住** 空格 / 左键 / A / RT | 吸：前方锥形范围的东西被拉到面前；对着固定物体按住约 1 秒 = 榨它 |
| **松开** | 推：面前那团朝镜头方向甩出去；砸到什么，什么就涌现 |
| 滚轮 | 镜头远近 |
| T / N / R / Esc | 调试掉落物体 / 直接跳下一段 / 重开 / 释放鼠标 |

---

## 3. 验证工具

| 命令 | 用途 |
|---|---|
| `godot --headless --path . -- --autopilot` | 无头冒烟测试：机器人自动走向固定物体、吸、推，40 秒后打印账本并退出。**改完代码先跑这个**，能抓到 GDScript 解析错误 |
| `... -- --autopilot --run=60 --stages-at=12,30` | 指定时长，并在第 12、30 秒强制跳阶段 |
| `... -- --autopilot --fever-at=10` | 第 10 秒强制进入狂热 |
| `godot --path . -- --autopilot --shots=DIR --shots-at=2,9.5` | 非无头：在指定时刻截图（看画面用） |
| `python3 tools/validate_table.py` | 校验内容表：名字引用、枚举、坍缩配对 |
| `python3 tools/wordart_preview.py OUT_DIR` | 出 WordArt 设计稿 PNG + 波浪 GIF（只要 Pillow + numpy） |

自动跑日志每 5 秒一行：`bodies / emerged / collapsed / stage / progress / seen / fever`，调节奏时很有用。

---

## 4. 架构速览

```
project.godot
  autoload: Boot → DB → Stats → Juice   （顺序有依赖）
scenes/main.tscn          世界 + 玩家 + HUD
content/emergence_table.csv  所有物体的规则（唯一真相源）
```

| 文件 | 职责 |
|---|---|
| `scripts/boot.gd` | 代码注册输入（不依赖 project.godot 的 input 段）；加载字体；解析命令行参数 |
| `scripts/emergence_db.gd` | 读 CSV → `EmergenceDef`，按中文名或 id 查 |
| `scripts/stats.gd` | **事件账本**：物体注册表、连涌、坍缩检测、物体数量预算、涌现度 / 阶段、发现记录、狂热、连锁限流 |
| `scripts/juice.gd` | 手感：慢动作、顿帧、震屏、闪白、粒子、冲击环、音效池 |
| `scripts/emergent_body.gd` | 世界里的每个东西（RigidBody3D）：被打 / 被榨 → 涌现、配方、吃、开窍 NPC、扎根 / 拔起、暴击 |
| `scripts/visuals.gd` | 按 def 造外观和碰撞体；手搓几何 / 借来的模型 / 名字的彩虹 3D 字兜底 |
| `scripts/player.gd` | 玩家：移动、吸（锥形力场）、推（甩出 + 冲击）、按体型的"抓力"、走路顶开东西、人 ↔ 挖掘机、体型 k |
| `scripts/world.gd` | 搭街道、生成 API（`spawn_body` / `spawn_after`）、阶段过渡（城市生长、地球拉远） |
| `scripts/hud.gd` | 字幕调度、XP 弹窗、连涌、涌现度条、提示、狂热遮罩 |
| `scripts/wordart_line.gd` | WordArt 艺术字（三步：平面字 → 一次性合成 → 每帧波浪变形） |
| `scripts/object_caption.gd` | 物体字幕：名字是 WordArt，后缀是不动的 POP 字；普通 / 第一次 / 暴击 |
| `scripts/caption.gd` | 全屏 / 阶段字幕：整行 WordArt |
| `scripts/autopilot.gd` | 冒烟测试机器人 + 截图 |
| `assets/shaders/` | `wordart_compose` / `wordart_warp`（艺术字）、`fever_rainbow`（狂热遮罩）、`rainbow`（实体彩虹字）、`desaturate`（冷开场灰） |

### 一次涌现的路径

```
玩家松开 → player._release()
  ├ 吸住的东西被甩出：set_hot() + player_shot_until（打击感用）
  └ 正前方的固定物体：trigger(…, by_player=true)
甩出的东西撞上别的 → emergent_body._on_body_entered → other.trigger(hitter)
trigger():
  配方命中？→ 变成别的东西
  否则按 def.emits 喷东西（world.spawn_body，继承发射者的体型 k）
  → Stats.record_emergence(def, emitted, pos, n, by_player, crit)
       → 连涌 / 狂热 / 发现 / 涌现度 → signal emerged → HUD 出字幕
Stats 每 0.25 s 检查同类聚集 → _collapse() → world.spawn_after(上一级)
```

---

## 5. 调参位置（最常改的）

| 想改 | 位置 |
|---|---|
| 什么喷什么、几个凑一起坍缩、配方 | `content/emergence_table.csv`（改完跑 `validate_table.py`） |
| 阶段节奏 | `stats.gd` → `STAGE_GOALS`（现在 300 / 900）；`record_emergence` 里的计分 |
| 狂热 | `stats.gd` → `FEVER_COMBO`、`FEVER_MIN_TIME`；加成在 `player.gd` 搜 `Stats.fever` |
| 连锁太猛 / 太弱 | `stats.gd` → `CHAIN_RATE_CAP`、`COLLAPSE_COOLDOWN`、`MAX_BODIES`；`world.gd` → `_do_spawn` 里碎片变"活"的概率 |
| 暴击 | `emergent_body.gd` → `CRIT_BASE`、`CRIT_POWER` |
| 吸 / 推手感 | `player.gd` 顶部常量；`SIZE_GRIP`（大东西多难拖） |
| 速度 | `player.gd` → `SPEED`、`body_speed`（挖掘机 1.9） |
| 城市尺度 | `world.gd` → `CITY_K`（3.5）、`CITY_BUILDINGS` |
| 艺术字粗细 / 描边 / 波浪 | `wordart_line.gd` 顶部变量（和 `tools/wordart_preview.py` 同名） |
| 物体字幕大小 / 颜色 | `object_caption.gd` → `setup()` |

---

## 6. 已经拍板的设计决定

按时间顺序，都是和你来回确认过的：

1. **核心动词 = 吸 + 推**，没有"纳"、没有肚子；所有坍缩都发生在世界里。（`docs/design/01_核心交互.md` 里"吐纳 / 肚子坍缩"那部分已过时，见该文件顶部说明）
2. **3D、千禧年中文互联网语气**，一本正经。
3. **字幕**：
   - 阶段 / 全屏字幕整行 WordArt 波浪。
   - 物体字幕只有名字是 WordArt，后缀「涌现出来了。」是不动的 POP 字，制造反差。
   - 第一次见到 / 暴击时句尾变「！」，各有不同特效。
   - 字体：思源黑体 Black，直角不圆边；名字用 4 套海报渐变（避开浅黄浅青）+ 白边 + 深紫粗框 + 硬阴影。
4. **场景里所有东西都有物理**，包括房子和高楼；扎根的东西很重、站得住，蓄满力或重物砸中才倒。
5. **进城市换身体成挖掘机**；体型 ×3.5。
6. **连涌 20 以上不再慢动作**，改为「涌现狂热」（参考 Love Spinnin' 的 fever）。
7. **地球只演一次**，之后停在"第三幕 未完待续"。

完整视觉规范见 `docs/design/03_视觉与字幕.md`，结构与过渡时间轴见 `02_结构与插曲.md` §4。

---

## 7. 已知问题 / 没做的

**手感与表现（建议优先）**
- 阶段节奏只被机器人测过（城市约 50 秒跑满）；人玩应慢不少，需要实测后调 `STAGE_GOALS`。
- NPC 走到镜头跟前会挡住画面（弹簧臂只避开地面）。
- 挖掘机从高处俯视像一个黄方块，挖斗动作不明显，可以做大或加镜头特写。
- 城市阶段巨人状态下按住，会一次榨到街上一堆小东西（尺寸判定可以只榨"够大"的）。
- 右上角连涌计数还是旧的单层 RichTextLabel 波浪字，没换成 WordArt（数字变化太频繁，重建开销大）。

**技术**
- 每条 WordArt 字幕用 2 个 SubViewport（出现时渲染几帧后冻结），连锁很密时会同时有好几条；桌面 GPU 没问题，低端机要留意。
- NPC 的 FBX 会报 `FAMILY0x_D_1.png` 找不到：无害，材质在代码里覆盖了。
- 内容表以 `keep` 方式导入（`content/emergence_table.csv.import`），**不要改回翻译导入**，否则导出的游戏读不到表、场景是空的。
- 第一幕"冻结的街道"里的物体关掉了碰撞，是纯装饰。

**设计里有但还没做**（见 `docs/design/02_结构与插曲.md`）
- 插曲 B（系统碎片 → 游戏性）、蓝屏、桌面插曲（鼠标指针身体、内存不足、回收站）
- 插曲 C（网吧显示器拉远）、第三幕可操作的地球、终幕「涌现」大字 + 名单递归
- 图鉴 UI、真人配音（「力量——涌现出来了！」）、BGM

---

## 8. 下一步建议

1. 自己完整玩两遍，按 §5 调节奏和手感（这是目前最缺的信息）。
2. 做**蓝屏 + 桌面插曲**：设计最完整、复用"吸 / 推"最自然，也最能体现梗。
3. 录配音：全组每人录一版「力量——」「涌现出来了！！！」，替换 `assets/sounds/hum.wav` 的蓄力占位。
4. 再决定第三幕是可玩还是演出。

---

## 9. 本地用 Claude Code 继续

根目录 `CLAUDE.md` 写了项目约定和容易踩的坑（GDScript 类型推断、导入设置、验证流程），本地 Claude Code 会自动读。
