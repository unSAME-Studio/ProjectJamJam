# content/

`emergence_table.csv` 是全项目**唯一的内容真相源**。设计在这里改，引擎从这里生成。

## 列

| 列 | 含义 | 格式 |
|---|---|---|
| id | 英文唯一 id，也是 prefab / 资源名 | `snake_case` |
| name | 显示名（中文） | |
| act | 第几幕首次出现 | 1 / 2 / 3 |
| tier | 尺度层级，只用来排序和校验（产出 ≤ tier+1，坍缩 = tier+1） | 1 物体 · 2 生物 · 3 机构 · 4 系统 · 5 社会 · 6 现实 |
| pattern | 涌现语法 | container / reproduce / concept / system / recursive，可空 |
| emits | 被打中喷什么 | `名字×数量`，多个用 `; ` 分隔 |
| collapse_n | 多少个同类聚一起会坍缩 | 整数，空 = 不坍缩 |
| collapse_into | 坍缩成什么 | 另一行的 name |
| eats | 吃什么、吃多少 | `名字×数量`，多种用 `\|` |
| eat_emits | 吃够了喷什么 | `名字×数量` |
| recipes | 被特定东西撞到的特殊结果 | `撞它的东西→结果`，多个用 `; `，`*` = 任何东西 |
| line | 系统通报字幕或 NPC 台词 | 通报体以句号结尾 |
| status | 进度 | idea → approved → modeled → in-game → cut |
| owner | 谁在做 | |
| notes | 备注 | |

## 规则

- 新想法先加一行 `idea`，不要直接做资产
- `approved` 之后才建模型 / 做 prefab
- `collapse_into`、`emits`、`recipes` 里引用的名字必须在表里存在（校验脚本会报错）
- 每一幕 8–12 个 `approved`，超了就先砍再加

## 流程（待实现）

```
emergence_table.csv  →  tools/import_table.gd（编辑器脚本）  →  res://data/emergence/*.tres
```

校验：孤儿引用、tier 跳级、没有 line 的 approved 行。
