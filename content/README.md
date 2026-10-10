# content/

`emergence_table.csv` 是全项目**唯一的内容真相源**。设计在这里改，引擎从这里生成。

改完跑一次校验：

```
python3 tools/validate_table.py
```

## 列

| 列 | 含义 | 格式 |
|---|---|---|
| id | 英文唯一 id，也是 prefab / 资源名 | `snake_case` |
| name | 显示名（中文），其他列按 name 引用 | 唯一 |
| act | 首次出现在哪段 | `1` `2` `3` = 三幕；`D` = 桌面插曲；`0` = 特殊（玩家） |
| tier | 尺度层级（产出 ≤ tier+1，坍缩 = tier+1）。身体 = 0 | 1 物体 · 2 生物 · 3 机构 · 4 系统 · 5 社会 · 6 现实 |
| pattern | 涌现语法 | container / reproduce / concept / system / recursive，可空 |
| size | 能不能被吸：相对**本幕身体**的大小 | `S` `M` `L` `XL`；`-` = 不是实体（效果、状态、身体） |
| anchored | 固定在地上：吸不动时会被"榨"（持续吸 1s → 涌现），身体够大时整个吸走 | `y` 或空 |
| emits | 被撞中 / 被榨时喷什么 | `名字×数量`，多个用 `; ` |
| collapse_n | 多少个同类会坍缩（丹田里用这个数，世界里 ×1.5） | 整数，空 = 不坍缩 |
| collapse_into | 坍缩成什么 | 一个 name |
| eats | 吃什么、吃多少 | `名字×数量`，多种用 `\|`，`*` = 任何东西 |
| eat_emits | 吃够了喷什么 | `名字×数量` |
| recipes | 被特定东西撞到的特殊结果 | `撞它的东西→结果`，多个用 `; `；`*` = 任何东西；结果写在 `( )` 里 = 效果而不是物体 |
| line | 字幕（系统通报）或 NPC 台词 | 通报体以句号结尾 |
| status | 进度 | idea → approved → modeled → in-game → cut |
| owner | 谁在做 | |
| notes | 备注 | |

## 吸的尺寸档位

| 身体 / 丹田等级 | 能吸 | 能榨 |
|---|---|---|
| 小人 1 级 | S | 固定的 S / M |
| 小人 2 级 | S M（含固定 M，比如 ATM） | 固定的 L |
| 小人 3 级 | S M L（含网吧） | — |
| 鼠标指针 | S M | 固定图标 |
| 挖掘机 1→3 级 | M → L → 固定 L | 固定 L / XL |
| 地球 1→3 级 | L → XL | — |

## 规则

- 新想法先加一行 `idea`，不要直接做资产
- `approved` 之后才建模型 / 做 prefab
- 所有名字引用必须在表里存在（校验脚本会报错）
- 不给单个物体写专属脚本；需要新行为就加一种通用行为，再在表里引用

## 流程（待实现）

```
emergence_table.csv  →  tools/import_table.gd（编辑器脚本）  →  res://data/emergence/*.tres
```
