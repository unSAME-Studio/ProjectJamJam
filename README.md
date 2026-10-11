# 涌现出来了！

Game jam 项目（主题：涌现）。Godot **4.7**（4.6 也能跑），GL Compatibility。

- 设计文档：[docs/design/](docs/design/README.md)
- 内容总表（唯一真相源）：[content/emergence_table.csv](content/README.md)
- **交接文档 / 现状 / 调参 / 已知问题：[docs/HANDOFF.md](docs/HANDOFF.md)**

## 跑原型

用 Godot 4.7 打开本目录（`project.godot`），F5。

| 输入 | 作用 |
|---|---|
| WASD / 左摇杆 | 走 |
| 鼠标 / 右摇杆 | 转镜头 |
| **按住 空格 / 鼠标左键 / A / RT** | **吸**：前方锥形范围里的东西被拉到面前聚成一团；对着固定物体（ATM、树、网吧……）按住 ≈1 秒 = 榨它，它涌现 |
| **松开** | **推**：面前的一团朝镜头方向甩出去；喷出去的东西撞到什么，什么就涌现 |
| 滚轮 | 镜头远近 |
| T | 调试：面前掉一个随机物体 |
| N | 调试：直接跳到下一段（街道 → 城市 → 地球预览） |
| R | 重开 |
| Esc | 释放鼠标 |

顶部「涌现度」条满了会自动进入下一段：

1. **街道**（300）→ 街道冻结成模型地台，城市从地里长出来，你变大 3.5 倍、换成**挖掘机**。
2. **城市**（900）→ Powers of Ten 式拉远到地球，「第三幕 未完待续。」，然后回到城市接着玩。
3. **地球**：只演一次，之后进度条停在「第三幕 未完待续」。

第一次见到的东西加分最多，所以四处戳新东西最快。

- **连涌 20+ = 涌现狂热**：屏幕边缘彩虹旋转、视野变宽、更快、甩得更远、暴击更多；不再有慢动作。
- **暴击 / 第一次见到**：字幕句尾变「！」，暴击喷两倍。
- 场景里所有东西都有物理；扎根的（房子、树、高楼……）很重，蓄满力或重物砸中才会倒。

规则全在 `content/emergence_table.csv` 里：`emits` 被撞喷什么、`collapse_n / collapse_into` 多少个同类聚一起坍缩成什么、`eats` 吃什么、`recipes` 被什么撞变什么。改表不用改代码；没有模型的东西用它名字的彩虹 3D 字当模型。

## 无头冒烟测试

```
godot --headless --path . -- --autopilot
```

自动走到固定物体旁边、按住、松开、重复 40 秒，打印账本（涌现 / 坍缩 / 回收次数）后退出。其他参数：`--run=60`、`--stages-at=12,30`（强制跳阶段）、`--fever-at=10`（强制狂热）、`--shots=/some/dir --shots-at=2,9.5`（非 headless，定时截图）。

- 校验内容表：`python3 tools/validate_table.py`
- 艺术字样张（游戏内）：打开 `scenes/wordart_specimen.tscn`，F6
- 艺术字设计稿（离线）：`python3 tools/wordart_preview.py OUT_DIR`

## 借用的素材

- `assets/models/city/`、`assets/models/npc/`、`assets/sounds/`：来自 unSAME 的 Love-Spinnin
- `assets/fonts/`：文泉驿正黑（GPL + font exception）；站酷庆科黄油体、站酷快乐体、志莽行书、马善政楷书、思源黑体 SC Black、得意黑（均为 OFL）。许可证见同目录
- `assets/sounds/{didi,error,whoosh,hum,pop,chime,dialup,startup}.wav`：脚本合成的占位音
