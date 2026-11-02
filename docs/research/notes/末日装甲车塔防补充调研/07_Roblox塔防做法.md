# Roblox 塔防怎么做：设计惯例、载具/主动角色变体、技术实现

调研时点：2026-11-02。前置阅读：`06_Roblox数据.md`（Dead Rails、A Dusty Trip、TDS、Toilet TD、Anime Defenders、Build and Kill Zombies 的访问量/CCU 已在那里，本文不重复）。

来源标注约定：
- 无标注 = 已打开原页面核对过。
- **（仅搜索摘要）** = 只在搜索引擎摘要里看到，没打开原页核对。
- **（第三方）** = 粉丝 wiki、攻略聚合站或数据追踪站，不是开发者/Roblox 官方口径。
- Roblox 官方 API 数据抓取于 2026-11-02（`games.roblox.com/v1/games`、`apis.roblox.com/universes/v1/places/{id}/universe`、omni-search）。
- 粉丝 wiki（fandom）直接打开返回 402，TDS wiki 的 Elevators、Farm、Cash 三页通过 MediaWiki 页面原文读取，其余 wiki 内容来自搜索摘要。

---

## 0. 一页结论

- **Roblox 塔防的标准形态**：大厅里走进「电梯/传送台」→ 选人数（最多 3–4 人）→ 倒计时约 20 秒 → 传送到独立对局服 → 固定路径地图，按波次刷怪 → 每人各自的局内现金，放塔/线性升级 → 跳波投票 → 打 Boss → 结算局外货币。TDS 是这套模板的原型。
- **局外循环分两派**：
  - 「解锁派」：TDS，用金币直接买塔，不抽卡。截至 2026-10 它仍是 CCU 第一的塔防。
  - 「抽卡派」：Anime Vanguards、ASTD、ALS、Toilet TD 等，玩法是卡池 + 保底 + 词条重随 + 进化 + 交易。Anime Vanguards 2026 年起把「进化任务链」做成主要成长路径，抽卡退到次要位置。
- **政策风险集中在「付费随机物品」上**。Roblox 要求：
  - 公示数值概率；
  - 接入 `PolicyService` 的 `ArePaidRandomItemsRestricted` / `IsPaidItemTradingAllowed` 两个开关；
  - 对英国、澳大利亚、巴西、比利时、荷兰等受管地区的用户屏蔽付费抽取，并屏蔽交易付费所得。
  - 规则在 2024–2026 年持续收紧。
- **「车即基地」的 Roblox 塔防已经有人做过**：Wild Rails Tower Defense（2025-04，7,972 万访问）、Death Train（2025-12 重制，最多 6 人）、Defend The Train（射击向，最多 10 人）。不过除 Dead Rails 本体外都不大。**「玩家本人跑动干活 + 模块塔防」的组合，没找到成规模的先例。**
- **技术共识**：
  - 敌人不用 Humanoid，也不放在服务器 Workspace 里。服务器只存数据表，按 1/6 帧率批量下发压缩坐标，客户端插值渲染。
  - 塔的索敌在服务器上做，用空间划分，并且降低索敌频率。
- **移动载具上站人是 Roblox 公认的老大难**：CFrame 驱动会抖，物理约束驱动在高速下仍会随 ping 抖。社区里最干净的解法是**「车不动，地形和敌人动」**（跑步机方案）。这和我们的俯视角、所有玩家都在车上的设定正好契合。

---

## 1. 头部 Roblox 塔防的设计惯例

### Takeaway

Roblox 塔防的局内规则高度趋同：固定路径、每塔放置上限、线性 5 级升级（少数用双路线）、各自独立的现金、经济塔、跳波投票和倍速、多档难度、1–4 人合作。各家拉开差距主要靠局外：解锁派还是抽卡派，以及抽卡之上叠了多少层养成。

### Cited Findings

**1.1 大厅与匹配（电梯 / 派对）**
- TDS 的电梯：
  - 玩家走进大厅里的实体电梯，先选这局要几人，计时随即开始，计时结束后传送。
  - Survival 电梯最多 4 人、最多等 20 秒，每个难度 2 台，共 12 台；进去后在「Survival Intermission Lobby」里投票选地图，难度由走进哪台电梯决定。
  - Hardcore / Voidcore 电梯最多 3 人，地图每分钟轮换。
  - Story 电梯最多 4 人，由第一个进入的人选关。
  - 派对（Party）由队长带全队进电梯。
  - 来源：[TDS Wiki: Elevators](https://tds.fandom.com/wiki/Elevators)（第三方）
- TDS 另有「Play 按钮」主匹配；派对成员会被匹配进同一局 — [TDS Wiki: Matchmaking](https://tds.fandom.com/wiki/Matchmaking)、[TDS Wiki: Party](https://tds.fandom.com/wiki/Party)（第三方，仅搜索摘要）
- 实现层面：
  - `TeleportService:TeleportAsync` 配合 `TeleportOptions.ReservedServerId` 把一组玩家送进私有对局服。
  - 用 `Player.PartyId` 加 `SocialService:GetPlayersByPartyId()` 可以直接拿到 Roblox 平台派对的成员。
  - 传送数据对客户端可见、不加密，不能拿来传货币或背包。
  - 来源：[Creator Docs: Teleport between places](https://create.roblox.com/docs/projects/teleport)
- Anime Vanguards 单服最多 24 人，这是大厅服的人数，不是单局人数 — [bloxpedia](https://bloxpedia.pages.dev/games/anime-vanguards/beginners)（第三方，仅搜索摘要）

**1.2 地图结构与放置规则**
- 全部头部作品都是**固定路径**：敌人沿预设路线走，单位放在路边。Anime Vanguards 攻略写「enemies walk along set routes」 — [Earnaldo](https://earnaldo.com/blog/anime-vanguards-beginner-guide)（第三方，仅搜索摘要）；ASTD 是「path-based map」 — [bloxmeta ASTD 新手指南](https://bloxmeta.gg/games/all-star-td/guides/beginners-guide)（第三方，2026-04 更新）
- **每塔放置上限**是标配：
  - TDS Farm 每人最多 10 个，PVP 下 8 个 — [TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)（第三方）
  - TDS Mortar 上限 5，Soldier 上限 12 — [TDS Wiki: Mortar](https://tds.fandom.com/wiki/Mortar)、[Sportskeeda](https://sportskeeda.com/roblox-news/tower-defense-simulator-all-towers)（仅搜索摘要）
  - Anime Vanguards 部分强力单位只能放 1 个或 3 个；还有词条用「强力加成换成只能放 1 个」 — [findingdulcinea 等](https://findingdulcinea.com/anime-vanguards-tier-list-best-units/)、[earlygame 词条表](https://earlygame.com/guides/mobile-gaming/anime-vanguards-traits)（第三方，仅搜索摘要）
  - Wild Rails TD 也有单位上限和放置费用 — [roonby](https://roonby.com/2025/04/30/wild-rails-tower-defense-guide-best-unit-trade-value/amp/)（第三方）
- **悬崖塔 / 地面塔**：
  - TDS 的塔分 Ground / Cliff 两种落点，例如 Farm 是 Ground，Mortar、Sniper、Ranger 是 Cliff，Gatling 两种都能放；悬崖塔要放在地图预设的悬崖格上 — [TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)（第三方）、[techwiser](https://techwiser.com/all-towers-in-tower-defense-simulator-roblox/)、[bloxodes](https://bloxodes.com/wiki/tower-defense-simulator)（第三方，仅搜索摘要）
  - 塔还有占地 footprint，Farm 是 1.75，比一般塔大 — [TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)（第三方）
- 「隐身 / 飞行 / 铅甲」检测是 TDS 塔的属性字段，靠敌人类型逼玩家搭配阵容 — [TDS Wiki: Farm（infobox 字段 hidden/lead/flying_detection）](https://tds.fandom.com/wiki/Farm)（第三方）

**1.3 升级结构**
- **线性 5 级（TDS 模板）**：Farm 从 0 级升到 5 级，每级一个名字和一次数值跳升，卖出价随投入上涨 — [TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)（第三方）
- **双路线互斥（TDX，BTD 式）**：每座塔有上、下两条路线；两条都能升到 2 级，任一条升到 3 级就锁死另一条 — [itemlevel: TDX how good is it](https://itemlevel.net/tower-defense-x-how-good-is-it/)（第三方，2023-11 公测期文章）
- **抽卡派的两层升级**：
  - 局内花钱升级；
  - 局外用重复卡升星，或用素材升级/进化。ASTD 建议主 DPS 升到 5 星，AoE 4 星，单体 3 星 — [bloxmeta ASTD](https://bloxmeta.gg/games/all-star-td/guides/beginners-guide)（第三方）
  - ASTD 的局外升级「permanently kept」，局内升级每次付钱 — [gamerempire](https://gamerempire.net/all-star-tower-defense-roblox-character-guide/)（第三方，仅搜索摘要）

**1.4 局内经济**
- TDS 现金来源：
  - 塔对敌人造成伤害（主要来源）；
  - 每波结算奖励；
  - 经济塔（Farm、DJ Booth、Cowboy）。
- 局内现金不带出局。「别人赚的钱分给你多少（shared cash）」按模式不同。加入开发者 Group 开局多给 $100 — [TDS Wiki: Cash](https://tds.fandom.com/wiki/Cash)（第三方）
- 合作模式下每人各管一份经济；人数越多，敌人数量和血量越高 — [dungeonpath co-op 指南](https://dungeonpath.com/posts/tower-defense-simulator/coop-guide/)（第三方）
- **经济塔数值样本（TDS Farm）**：
  - 放置 $300，基础每波 $60；
  - 1–5 级升级费分别为 $200 / $600 / $1,250 / $2,500 / $4,500；
  - 对应每波收入 $100 / $225 / $500 / $900 / $1,500；
  - **在每波开始时一次性发钱，波中不产出**；
  - 来源：[TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)（第三方）
  - 推论：越早跳波，越早拿到下一笔 Farm 收入，所以「跳波」本身是一个经济决策。
- TDX：金币主要来自击杀，敌人越强给得越多；也可以直接买货币跳过刷 — [itemlevel](https://itemlevel.net/tower-defense-x-how-good-is-it/)（第三方）、[Sportskeeda TDX 新手](https://sportskeeda.com/roblox-news/beginner-s-guide-roblox-tower-defense-x)（仅搜索摘要）
- 抽卡派也普遍有「farm 单位」给后期高价升级攒钱，因为升级很贵 — [Anime Vanguards 攻略](https://findingdulcinea.com/anime-vanguards-tier-list/)（第三方，仅搜索摘要）

**1.5 波次 / Boss / 跳波 / 倍速 / 难度 / 时长**
- TDS 模式和波数（第三方 wiki 汇总，以游戏内为准）：

| 模式 | 波数 | 人数 | 最终 Boss |
| --- | --- | --- | --- |
| Easy | 20 | 1–4 | Brute |
| Casual | 30 | 1–4 | Grave Digger |
| Intermediate | 30 | 1–4 | Patient Zero |
| Molten | 35 | 1–4 | Molten Warlord |
| Fallen | 40 | 1–4 | Fallen King |
| Frost | 40 | 1–4 | Frost Spirit |
| Hardcore | 45 | 1–3 | — |
| Voidcore | 50 | 1–3 | — |
| PVP | — | 1v1 / 2v2 | — |

  - 其他规则：Hardcore 禁用消耗品；Voidcore 还禁用技能；难度按玩家等级逐档解锁（如 Intermediate 5 级、Fallen 30 级、Hardcore 50 级）。
  - 来源：[bloxodes TDS modes](https://bloxodes.com/wiki/tower-defense-simulator/modes)（第三方）
- 「跳波」按钮一亮就点是 TDS 单人刷钱的常规建议 — [findingdulcinea](https://findingdulcinea.com/how-to-farm-coins-in-tower-defense-simulator/)（第三方，仅搜索摘要）
- Anime Vanguards 的「Auto Skip Waves」是设置里的免费开关，不卖 — [allthings.how](https://allthings.how/anime-vanguards-how-to-skip-waves-auto-skip-waves-setting/)（仅搜索摘要）
- 倍速常被做成付费便利项：
  - ALS 的「3x Speed」通行证在交易价值表里是高需求物品 — [progameguides](https://progameguides.com/?p=880454)（第三方，仅搜索摘要）
  - Anime Tower Defense 可调 1x / 1.5x / 2x，2x 可免费找 NPC 拿，也含在 VIP 里 — [VGC](https://www.videogameschronicle.com/guide/anime-tower-defense-codes/)（仅搜索摘要）
- 抽卡派的模式套路：Story（多张地图 × 多个 Act）→ Infinite / Endless（无尽，排行榜）→ Challenge / Raid / Legend Stage → 周期性活动。
  - ALS：Story、Infinite、Challenges，外加单独的 AFK 区（独立服务器，挂机按时长给 Coins 和 Emeralds） — [itemlevel ALS 新手](https://itemlevel.net/anime-last-stand-complete-beginners-guide/)（第三方，2024-03）
  - Toilet TD 的 Endless 有排行榜，按排名发钻石 — [Sportskeeda](https://www.sportskeeda.com/roblox-news/toilet-tower-defense-endless-mode-guide)（仅搜索摘要）
  - Anime Vanguards 的 Worldlines 是 50 层 roguelike 爬塔，版本更新时重置奖励逼老玩家重刷；它还有地牢、Raid、PvP、Land Conquest、关卡编辑器 — [RoWatcher: AV Update 11.5](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)（第三方）
- **单次游玩时长**（追踪站口径，是会话时长，不是单局时长）：TDS 11 分钟、Anime Vanguards 37 分钟、TDX 16 分钟、Garden TD 14 分钟、ASTD 7 分钟、Alliance TD 11 分钟 — [Adellion 2026-10](https://adellion.com/roblox-tower-defense)（第三方）

**1.6 人数**
- 合作上限通常是 4 人，高难模式 3 人（TDS）；单人可玩是默认 — [TDS Wiki: Elevators](https://tds.fandom.com/wiki/Elevators)（第三方）
- Toilet TD 的 PvP 限时模式做到 1v1 到 5v5 — [Sportskeeda TTD PvP patch notes](https://www.sportskeeda.com/roblox-news/toilet-tower-defense-pvp-update-patch-notes)（仅搜索摘要）

**1.7 局外循环（meta）**
- **解锁派（TDS）**：
  - 「No summoning」，新单位靠打败更强的 Boss 或花金币解锁；例如 Farm 在商店卖 2,000 金币。
  - 2026-10 时 TDS 30 日峰值 104,491，是 Anime Vanguards（44,979）的两倍多。
  - 来源：[Adellion](https://adellion.com/roblox-tower-defense)（第三方，Rolimons 数据）、[TDS Wiki: Farm](https://tds.fandom.com/wiki/Farm)
- **抽卡派公共组件**：
  - 卡池 / 保底：
    - Anime Vanguards 单抽 50 宝石（VIP 40），十连 500；约 400 抽保底神话（Mythic）；特别卡池每小时轮换；概率 Rare 75.496% / Epic 20% / Legendary 4% / Mythic 0.5%。来源：[anime-vanguards.pages.dev](https://anime-vanguards.pages.dev/blog/anime-vanguards-summon-guide)、[animevanguards-org](https://animevanguards-org.pages.dev/guides/beginners)（第三方，仅搜索摘要）
    - ALS 概率 Rare 70% / Epic 27.5% / Legendary 2% / Mythic 0.5%，60 抽保底传说、250 抽保底神话 — [itemlevel ALS](https://itemlevel.net/anime-last-stand-complete-beginners-guide/)（第三方，2024-03）
    - ASTD 单抽 50、十连 450；完整一轮保底约 4,500 宝石；每周免费约 300–400 宝石 — [bloxmeta](https://bloxmeta.gg/games/all-star-td/guides/beginners-guide)（第三方）、[gamepur](https://gamepur.com/guides/how-to-get-gems-in-roblox-all-star-tower-defense)（仅搜索摘要）
  - 稀有度 + 闪光（Shiny）变体：自动出售默认跳过 Shiny 和带词条的单位 — [animevanguards-org](https://animevanguards-org.pages.dev/guides/beginners)（第三方，仅搜索摘要）
  - **词条（Traits）重随**：在大厅 Traits NPC 处消耗 Trait Token 之类重随，词条分 Monarch、Ethereal 等档 — [Sportskeeda traits](https://www.sportskeeda.com/roblox-news/anime-vanguards-traits-guide)、[destructoid](https://destructoid.com/?p=595905)（仅搜索摘要）。ASTD 的 Trait Burner 从剧情关掉落，建议等 5 星后再随 — [bloxmeta](https://bloxmeta.gg/games/all-star-td/guides/beginners-guide)
  - **进化（Evolution）**：
    - 用素材加任务链进化。Anime Vanguards 2026 年把「evolution quest chains」做成主要成长路径，以此区别于纯抽卡 — [RoWatcher](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)（第三方）
    - ALS 的单位进化需要神方块（God's Cube）、元素精华、碎片，进化品不可交易 — [deltiasgaming](https://deltiasgaming.com/?p=309892)（仅搜索摘要）
  - **交易**：
    - Toilet TD 有交易广场，社区自己维护价值表，部分单位只能交易获得 — [gamertweak](https://gamertweak.com/get-units-toilet-tower-defense)（仅搜索摘要）
    - ALS 被玩家要了约一年才加交易 — [progameguides](https://progameguides.com/?p=880454)（仅搜索摘要）
    - Wild Rails TD 用 Gold 标价，单位价值从 1 到 12,500 Gold — [roonby](https://roonby.com/2025/04/30/wild-rails-tower-defense-guide-best-unit-trade-value/amp/)（第三方）
  - **每日登录 / 任务 / 兑换码 / 挂机**：ALS 每周登录最多 500 Emeralds，兑换码总计 5,300，另有 AFK 服 — [itemlevel ALS](https://itemlevel.net/anime-last-stand-complete-beginners-guide/)
  - **Battle Pass**：
    - TDX 有通行证，并做「通行证代币 +50% 限时」活动 — [Adellion](https://adellion.com/roblox-tower-defense)
    - Anime Vanguards 是赛季通行证 — [RoWatcher](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)
- **更新节奏**：
  - Anime Vanguards 每 2–4 周一个大版本 — [RoWatcher](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)
  - SpongeBob Tower Defense「substantial updates every week」，开发方把留存归功于周更 — [MaxPower Gaming 访谈 Zach Letter](https://www.maxpowergaming.co/post/growing-spongebob-tower-defense-top-25-monetizing-roblox-game)（2025-03）
  - Garden TD 固定每周六 13:00 UTC 更新 — [Adellion](https://adellion.com/roblox-tower-defense)
  - TDS 团队约 30 人，两周一个冲刺；预告片控制在 30 秒以内，在更新前约一周发，好兼作缩略图 — [DevForum: BelowNatural Creator Spotlight](https://devforum.roblox.com/t/creator-spotlight-belownatural%E2%80%99s-journey-building-paradoxum-games/3027035)（2024-06）

**1.8 2025–2026 新起量的塔防**（Adellion 2026-10-03 快照，数据来自 Rolimons，第三方）
- **Garden Tower Defense**：2025-05 上线，历史峰值 197,872（2025-09-06），近 30 日峰值 18,606；以植物当塔，有「变身成自己的单位直接战斗」模式 — [Adellion](https://adellion.com/roblox-tower-defense)
- **Alliance Tower Defense**：2026-06-25 上线，30 日峰值 20,822，抽卡派 — [Adellion](https://adellion.com/roblox-tower-defense)
- **Retro Tower Defense**：2025-05 上线，峰值 35,470（2026-08）；混合制，英雄靠抽、塔靠买，可交易，有 Casual 到 Hard 以及 Endless — [Adellion](https://adellion.com/roblox-tower-defense)
- **Slop Tower Defense**：2026-07-19 上线，峰值 25,122，抽卡加合成，好评只有 79.3% — [Adellion](https://adellion.com/roblox-tower-defense)
- **Anime Vanguards**（开发者 Kitawari）：2024-09 上线后 6 天内峰值 340,167；2026-03 版本更新后 7 日峰值 101,375，平时谷底约 5.5 万 — [RoWatcher](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)（第三方）

**1.9 变现模式与平台政策**
- **常见付费点**：
  - VIP 通行证（抽卡打折、经验加成、挂机收益翻倍）；
  - 倍速通行证；
  - Shiny Hunter 通行证；
  - 赛季 Battle Pass；
  - 直购宝石；
  - 付费单位 / 付费箱子；
  - 皮肤。
  - 来源：[RoWatcher AV](https://rowatcher.com/news/anime-vanguards-update-11-5-how-this-tower-defense-game-holds-55k-players)、[itemlevel AV](https://itemlevel.net/anime-vanguards-complete-beginners-guide-tips-tricks/)（仅搜索摘要）
  - Toilet TD 的 Event Crate 要 Robux，Coin Crate 免费 — [ginx](https://www.ginx.tv/en/?p=69835)（仅搜索摘要）
  - 塔防通用付费点还有付费塔、皮肤、额外塔槽位 — [obby.fun 教程](https://www.obby.fun/blog/how-to-make-tower-defense-roblox)（仅搜索摘要）
- **Roblox 付费随机物品（Paid Random Items）规则**，官方文档：
  - **覆盖范围**：直接或间接用 Robux 买的随机物品都算，包括宝石转盘、抽蛋、宝箱、强化、合成、改概率道具（幸运药水、保底、概率提升卷）。
  - **公示要求**：购买前列出全部结果和数值概率，百分比合计 100%；条目太多时放在写有「Info / Details」字样的弹窗里，单独一个 (i) 图标不算；每人限得一次的物品，要按该玩家当前情况动态更新概率；钥匙、重随券这类间接购买，也要在花游戏币前公示；改概率道具生效时，显示的概率要实时更新。
  - **免费路径**：靠游玩免费获得的随机奖励不需要公示。
  - **受限用户**：用 `PolicyService:GetPolicyInfoForPlayerAsync()` 读取开关。`ArePaidRandomItemsRestricted = true` 的用户不能用 Robux 或 Robux 买来的货币参与随机抽取，开发者可选的处理方式有：给一条免费获取路径、改成固定顺序、按期望价值直售具体结果、隐藏、报错拦截、把玩家移出相关区域。`IsPaidItemTradingAllowed = false` 的用户不能交易随机产出或其他付费物品。
  - 来源：[Creator Docs: Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- **2026-05-26 DevForum「Clarifying Requirements for Paid Random Items」**：
  - 补充了几条：每个结果都必须给玩家带来某种好处；把随机物品捆进付费礼包，整个礼包就算付费随机物品；嵌套箱子要公示每个最终结果的概率。
  - 点名的受管市场（测试用）：澳大利亚、比利时、荷兰、英国、巴西，并说明名单会变。
  - 违规后果：游戏下架、账号封禁。
  - 来源：[DevForum](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622)
- **分地区时间线**：
  - 英国：2024 年起，声明含付费随机物品但没接 `ArePaidRandomItemsRestricted` 的游戏，对英国 18 岁以下用户自动不可见 — [DevForum 公告](https://devforum.roblox.com/t/update-on-paid-random-items-restriction-for-uk-users-under-18/3072183)（仅搜索摘要）
  - 澳大利亚：随后扩展到澳大利亚用户 — [DevForum 公告](https://devforum.roblox.com/t/update-on-paid-random-items-restriction-for-australian-users/3153602)（仅搜索摘要）
  - 巴西：2026-03-17 起禁止 18 岁以下用户的付费随机物品；2026-03-31 起，18 岁以上但未做年龄验证的巴西用户也禁止 — [Bloxy News](https://www.threads.com/@bloxy.news/post/DWA_v6VlW8B/to-ensure-roblox-games-are-compliant-with-regional-restrictions-paid-random)、[DevForum](https://devforum.roblox.com/t/i-got-this-message-and-don%E2%80%99t-know-what-to-do/4526581)（仅搜索摘要）
- **内容成熟度标签（直接影响丧尸射击题材）**：

| 标签 | 默认可见人群 | 暴力 | 血 |
| --- | --- | --- | --- |
| Minimal | Roblox Kids（5–8 岁）、Roblox Select（9–15 岁） | 轻微、偶发 | 不写实、偶发 |
| Mild | 同上 | 轻微、反复（例如「生命归零的瞬间尸体消失」） | 不写实、频繁 |
| Moderate | 9–15 岁和 16 岁以上 | 写实但不血腥 | 少量写实血，例如远处的血溅 |
| Restricted | 仅 18 岁以上已验证用户 | 强烈 | 大量写实血 |

  - 来源：[Creator Docs: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
  - 2025-09-30 之后，没填 Maturity & Compliance 问卷的游戏不可游玩 — [DevForum](https://devforum.roblox.com/t/important-updates-unrated-experiences-and-changes-to-experience-pages/3899317)（仅搜索摘要）

### Inferences
- 我们的「效率 vs 自动化」升级分叉，和 TDX 的「两条都能升到 2 级、到 3 级锁死另一条」结构几乎一样。Roblox 玩家对这种结构熟悉，可以直接借这套交互语言。
- TDS 证明「不抽卡、直接解锁」在 Roblox 上能活得最久（运营 7 年，2026 年仍排第一）。抽卡派来得快去得也快：Anime Defenders 已几乎归零，见 06 号笔记。
- Roblox 上的「跳波 + 经济塔在每波开始时发钱」是一对天然搭配。我们的锅炉 / 燃料循环可以借这个节奏：每段路程开头结算一次产出。
- 如果做「尸体当燃料」并让尸体留在场上，大概率被判成 Moderate（写实死亡描绘），会丢掉 Roblox Kids（5–8 岁）的默认受众（Moderate 仍对 9–15 岁的 Roblox Select 开放）。改用「击倒即化为燃料块 / 灰烬」更可能拿到 Mild。这是我们按官方描述做的推断，需要实际填问卷确认。

### Gaps
- TDS 的投票跳波细节（几人同意、是否全员）、倍速有无，没找到原文。
- Anime Vanguards、ALS、ASTD 的单局人数上限没有可靠来源（大概率也是 4 人）。
- Toilet TD 的当前模式表、箱子概率，只有搜索摘要。
- 没找到任何一家抽卡塔防的官方收入或付费率。

---

## 2. 「车即基地」或「玩家本人参战」的 Roblox 塔防 / 波次防守

### Takeaway

车即基地的塔防在 Roblox 上至少有三种做法：
1. 单位放在行进的火车上自动打（Wild Rails TD、Death Train）；
2. 玩家本人拿枪守火车（Defend The Train，射击向）；
3. 开放世界生存加车载炮塔（Dead Rails）。

「玩家亲自打 + 放置防御物」的混合形态有 Zombie Rush Survival（2026）和 Garden TD 的变身模式。没有找到「玩家在车内跑动、做杂务维持模块运转」的成规模作品，这仍是空位。

### Cited Findings

**Wild Rails Tower Defense 🚂**（universe 7513026554）
- 简介：「Build your Army and jump onboard the Train to defeat the hoards of Enemies」。
- 标签里直接写了 Dead Rails、1899、Zombies，是蹭 Dead Rails 的塔防。
- 自带 `/trade`（交易广场）和 `/afk`（挂机服）两个指令；支持主机手柄放置和旋转单位。
- API 数据：2025-04-09 创建，访问 79,719,526，当前在线 86，单服 25 人。
- 来源：[Roblox Games API](https://games.roblox.com/v1/games?universeIds=7513026554)
- 机制：
  - 守一辆行进中的火车，单位放在车上，对抗丧尸、狼人和 Boss；Bonds 是抽单位的主货币，也有 Eggs — [deltiasgaming](https://deltiasgaming.com/?p=223822)、[sportskeeda codes](https://sportskeeda.com/roblox-news/wild-rails-tower-defense-codes)（仅搜索摘要）
  - 单位有放置上限，有 farm 单位，可交易，价值以 Gold 计；一篇攻略说它融合了 Ball TD 和 Five Nights TD — [roonby](https://roonby.com/2025/04/30/wild-rails-tower-defense-guide-best-unit-trade-value/amp/)（第三方）

**Death Train**（universe 9329963026，「GAME REMAKE」）
- 简介：「PROTECT THE DIAMONDS / Hire & Upgrade Soldiers / Deploy on Train / Start Riding!」
- API 数据：2025-12-10 创建，访问 12,065,968，当前在线 6，单服 6 人，最近更新 2026-01-16。
- 来源：[Roblox Games API](https://games.roblox.com/v1/games?universeIds=9329963026)
- 机制：火车一直沿轨道走，不能蹲点，所以要规划车上的防御布局；保护车上的钻石核心，钻石同时也用来开武器箱（50 / 120 / 450） — [bo3.gg](https://bo3.gg/games/articles/death-train-a-beginners-guide)、[ofzenandcomputing](https://ofzenandcomputing.com/roblox-death-train-beginners-guide/)（仅搜索摘要）
- 旧版有「停车进城搜刮，逗留太久会刷出追击者」的设计 — [Sportskeeda Death Train](https://www.sportskeeda.com/roblox-news/death-train-a-beginner-s-guide)（仅搜索摘要；无法确认重制版是否保留）

**Defend The Train**（Banded Top Hat Games，universe 1566011973）
- 简介：「defending a moving train from incoming waves of enemies using 3 classes」，无尽难度递增，火车炸了或全员同一波阵亡就结束。是 2011 年 gombob 原作的重制。
- API 数据：单服 10 人，访问 1,334 万，当前在线 15，2026-10-29 仍在更新。
- 来源：[Roblox Games API](https://games.roblox.com/v1/games?universeIds=1566011973)
- 2026-10-28 的 0.8.5 版更新日志：
  - 武器有枪、近战、治疗枪；
  - 敌人「Boarders」会爬梯子登车（修了「从车厢缝掉下去」的问题）；
  - 有自爆敌人；有 perk 系统；
  - 载具速度不再随难度缩放。
  - 来源：[DevForum: Defend The Train Changelog](https://devforum.roblox.com/t/defend-the-train-changelog/4961655)
- 这是「玩家本人守车」的纯射击做法，没有塔。

**Iron Rail Defense**（Nexa Interactive）
- 简介：「Inspired by Tower Defense Simulator & Train Sim」，火车可以作为兵种；背景是幸存者躲在地铁站。
- API 数据：访问 657 万，当前在线 27。
- 来源：[Roblox Games API](https://games.roblox.com/v1/games?universeIds=6591692417)

**Dead Rails 的车载防御**
- 可以在 Gunsmith 花 $125 买 Maxim 炮塔，它对进入射程的敌人自动开火，需要专用弹药，攻略建议把弹药焊在炮塔上 — [gamertweak](https://gamertweak.com/how-to-use-turret-in-dead-rails)（仅搜索摘要）
- 狼人会爬上车顶拆炮塔 — 同上（仅搜索摘要）
- 有玩家在官方反馈板请求做「360° 车载机枪座」，说明目前没有专门的炮位 — [BetaHub feature request](https://app.betahub.io/projects/pr-7482253316/feature_requests/778)（仅搜索摘要）

**混合射击塔防 / 玩家本人参战**
- **Zombie Rush Survival**（2026，Undead Dev.）：
  - 开局一把手枪，按波次打丧尸，局内花钱升级武器和防御。
  - 职业决定能部署哪三种防御物：Rookie 是自动炮塔、路障、爆炸桶；Medic 是脉冲炮塔、增益路障、治疗站；Trapper 是特斯拉塔、地刺、冰冻雷。
  - 职业用局外 Credits 解锁，价格 5 万到 40 万。
  - 来源：[allthings.how 职业指南](https://allthings.how/zombie-rush-survival-classes-guide-costs-and-equipment/)（2026-09 更新）
  - 06 号笔记记录它当前约 8 千在线。
- **Garden Tower Defense**：「morph into your own units」，可以变身成自己的植物单位直接战斗 — [Adellion](https://adellion.com/roblox-tower-defense)、[RoWatcher](https://rowatcher.com/games/7703614594/garden-tower-defense)（第三方）
- **Zombie Stories**：被描述为「CoD Zombies × Bloons TD」，玩家亲自打，同时买自动防御，最多 6 人 — [stealthygaming](https://stealthygaming.com/top-10-best-zombie-games-in-roblox/)（第三方，2024 年列表，仅搜索摘要）

### Inferences
- 车载塔防在 Roblox 上已有现成的玩家认知：Wild Rails TD 靠蹭 Dead Rails 拿到近 8 千万访问。但这些作品都把车当成「会动的地图」，玩家仍是上帝视角放塔，**玩家角色本身在车内没有职责**。
- Defend The Train 证明「登车敌人 + 爬梯子」这类近身威胁在 Roblox 上可行，不过它的体量很小。
- 我们的差异点「一个人在车里跑动、做杂务、从窗口射击」，在 Roblox 上更接近 Zombie Rush Survival 的「本人打 + 部署物」，再加上 Dead Rails 的「烧燃料、焊东西」，而不是传统塔防。

### Gaps
- Wild Rails TD 的车是真在物理上移动，还是地图滚动，没找到说明。
- Death Train 重制版的完整机制没有核实到原页面。

---

## 3. 技术实现（Roblox / Luau）

### Takeaway

成熟做法是**服务器做纯数据模拟、客户端做表现**：敌人没有 Humanoid、不受物理影响、服务器上不存在对应的 Part；坐标量化后低频批量下发，客户端线性插值。塔的索敌在服务器上用空间划分并降频。俯视相机用 Scriptable 相机加低 FOV。移动载具上站人，用物理约束驱动仍会随 ping 抖动，「世界动、车不动」最稳。

### Cited Findings

**3.1 数百敌人怎么跑**
- **方案演化**（2022 年的 DevForum 讨论）：

| 尝试过的方案 | 结果 |
| --- | --- |
| Humanoid:MoveTo / 寻路 | 卡，会冲过路点 |
| TweenService | 约 100 个时掉帧、瞬移 |
| BodyMover | 约 100 个时 desync |
| Heartbeat 逐帧移动 | 能跑约 1,000 个，但不同帧率的客户端会永久不同步 |

  - 推荐做法：服务器只存表（血量、CFrame、速度），「not using any models or parts at all on the Server」；Heartbeat 更新；**每 10 次 Heartbeat 发一次 RemoteEvent**，用 Vector2int16 / Vector3int16 压缩；客户端按需创建模型，用 0.2 秒 Linear tween 插值。
  - 实测：约 500 个敌人、60 FPS、约 100 KB/s 下行；到 2,000 个时客户端变卡。
  - 来源：[DevForum 1877615](https://devforum.roblox.com/t/how-to-move-a-lot-of-objects-smoothly-on-server-and-client-and-at-the-same-time-without-delay-and-desynchronization-enemy-units-system/1877615)
- **压带宽**（2023 年的 DevForum 讨论）：
  - 起点：约 200 个敌人，每 0.05 秒全量广播，几百 KB/s。
  - 字符串键改数字索引，再加上只发 Y 轴旋转（Vector2int16），从约 250 KB/s 降到 75 KB/s。
  - 其他建议：停着的敌人不发；按敌人类型分表；双端运行同一套移动逻辑，服务器只定期纠偏。
  - 来源：[DevForum 2517970](https://devforum.roblox.com/t/tower-defense-game-has-high-recv-network-traffic-performance-issue/2517970)
- **Astro Force（Roblox RTS）的「带宽降 60 倍」**（Atrazine，2021-05-03，这一领域最常被引用的文章）：
  - V1：服务器 Part 每帧 CFrame，靠引擎自动复制，带宽很贵。
  - V2：
    - 服务器上不放 Part，自定义碰撞；
    - 复制频率从 60 Hz 降到 10 Hz，客户端线性插值；
    - 只发位置变了的单位；
    - Y 坐标由客户端从高度图算，朝向只发 Y 轴；
    - int16 量化（坐标 ×5、角度 ×100）；
    - 100 个移动单位从 35 KB/s 降到 10 KB/s。
  - V3：bit32 打包成每次更新 32 bit（11 bit 单位 ID、7 bit 朝向、8×8 网格内 6 bit 偏移），再减半。
  - 参照：一般射击游戏约 50–80 KB/s。
  - 来源：[DevForum: Astro Force](https://devforum.roblox.com/t/how-we-reduced-bandwidth-usage-by-60x-in-astro-force-roblox-rts/1202300)
- **每个敌人每帧发一个 UnreliableRemoteEvent 是常见反例**，应合并成一个包；该帖的回复直接指向 Astro Force 的文章 — [DevForum 3051325](https://devforum.roblox.com/t/help-me-optimize-the-enemies-in-my-tower-defense-game/3051325)（2024-07）
- `workspace:BulkMoveTo()` 可以批量移动，有人反映性能提升明显，也有人觉得不够平滑 — [DevForum 1877615](https://devforum.roblox.com/t/how-to-move-a-lot-of-objects-smoothly-on-server-and-client-and-at-the-same-time-without-delay-and-desynchronization-enemy-units-system/1877615)、[搜索摘要](https://devforum.roblox.com/t/how-to-optimize-tower-system/2830931/9)
- **Humanoid**：
  - 社区经验是约 100 个 NPC 以上开始卡，常见替代是 AnimationController 播动画、属性存状态。代价是不支持衣服，并且要自己处理贴地。
  - 也有人测出 Humanoid 反而更快，所以要先用 MicroProfiler 实测 — [DevForum: Humanoid Optimisation and 500 NPCs](https://devforum.roblox.com/t/humanoid-optimisation-and-500-npcs/312738)、[Optimizing hundreds of moving NPCs](https://devforum.roblox.com/t/optimizing-hundreds-of-moving-npcs-rendering/3074292)（仅搜索摘要）

**3.2 塔的索敌：服务器还是客户端**
- 案例（2024-02）：
  - 现象：敌人在客户端渲染，读 CFrame 属性，1,000 个都流畅；**卡顿全部来自塔每帧遍历所有敌人**。
  - 回复的建议：在服务器上更新敌人位置，保证索敌准确；用 `GetPartBoundsInRadius` 或四叉树 / 八叉树做粗筛（有人实测八叉树大幅提升）；每 1–2 秒或目标丢失时才重新索敌；目标出了射程要释放。
  - 来源：[DevForum 2830931](https://devforum.roblox.com/t/how-to-optimize-tower-system/2830931)
- 结论：命中判定和经济放服务器（防作弊），客户端只放特效。

**3.3 网络库（buffer 序列化）**
- 社区主流是 Blink、Zap（IDL 编译成 buffer 收发代码）和 ByteNet（MIT）。Blink 作者自称带宽比原生 Remote 低几个数量级。
- 各库互相 benchmark，有分支（BlinkBlox）修过「恶意客户端 buffer 越界解析」的安全问题。
- 来源：[Blink](https://devforum.roblox.com/t/blink-an-idl-compiler-written-in-luau-for-roblox-buffer-networking-0185/2959671)、[ByteNet](https://devforum.roblox.com/t/bytenet-an-advanced-modern-networking-library-for-roblox/2733365)、[BlinkBlox](https://devforum.roblox.com/t/blinkblox-buffer-networking-that-checks-everything-a-client-sends/4898948)（仅搜索摘要）
- **Server Authority**：Roblox 官方的服务器权威加客户端预测 / 回滚。2026 年转正式版，需要用 InputAction 接管所有影响模拟的输入，主要卖点是防飞人、穿墙、加速外挂 — [DevForum Full Release](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)、[Roblox Newsroom 2026-07](https://about.roblox.com/newsroom/2026/07/creating-responsive-cheat-resistant-games-roblox-server-authority)（仅搜索摘要）

**3.4 教程 / 开源框架**
- GnomeCode 的 YouTube 塔防系列是入门事实标准，另有「Tower Defense Addons」续集，例如第 15 集讲跳波。有人反映老代码在新引擎上跑不起来 — [DevForum 2331906](https://devforum.roblox.com/t/need-help-with-developing-a-tower-defense-game-like-tower-defense-simulator/2331906)（仅搜索摘要）
- 其他资源：
  - GitHub「KaarinGaming/TowerDefenceTutorial」 — [GitHub](https://github.com/KaarinGaming/TowerDefenceTutorial)（仅搜索摘要）
  - BuiltByBit 上有付费「Tower Defense Template」 — [BuiltByBit](https://builtbybit.com/resources/tower-defense-template.117231/)（仅搜索摘要）
  - 免费大厅 / 电梯模型 — [DevForum: Free advanced lobby model](https://devforum.roblox.com/t/free-advanced-lobby-model-for-multiplayer-games/2272494)（仅搜索摘要）
- 没找到被头部作品采用、可以直接拿来用的开源塔防框架。头部作品都是自研。

**3.5 俯视 / 等距相机**
- 官方教程「Control the user's camera」：
  - 每帧用 `BindToRenderStep` 跟随 HumanoidRootPart，优先级 `Camera.Value + 1`；
  - 偏移 `(D, D, D)` 加 `CFrame.lookAt` 得到等距视角；
  - 建议 `FieldOfView = 20`，把距离从 24 拉到 64 补偿，画面就变「扁」；
  - 改偏移即可得到正俯视。
  - 来源：[Creator Docs](https://create.roblox.com/docs/tutorials/use-case-tutorials/input-and-camera/control-the-users-camera)
- **Roblox 没有正交投影**，只能用低 FOV（最低 1°）加远距离来近似。代价是相机离得越远，光照、渲染越容易出问题。
- 「Project Zomboid 式」遮挡墙和屋顶的处理，社区多用 Invisicam 式透明，效果一般 — [DevForum: Isometric Camera View](https://devforum.roblox.com/t/isometric-camera-view/3167056)、[Project Zomboid camera](https://devforum.roblox.com/t/how-would-i-go-about-making-a-camera-like-project-zomboid-in-roblox/3306965)（仅搜索摘要）

**3.6 移动载具上站人（重点）**
- **引擎原理**：Roblox 角色只会跟着「被物理驱动」的平台走；直接改 CFrame 或手设速度会让这个机制失效 — [DevForum: Jailbreak train platform system](https://devforum.roblox.com/t/jailbreak-train-platform-system/236339)、[Characters on Moving Platforms - Now Live](https://devforum.roblox.com/t/characters-on-moving-platforms-now-live/183385)（仅搜索摘要）
- **社区复刻的 Dead Rails 火车**（2025-04）：
  - 驱动：PrismaticConstraint（Motor 模式），用 VehicleSeat 的 Throttle 控制速度；轮子用 HingeConstraint 电机；整车用 WeldConstraint 焊成一个 assembly。
  - 轨道：每帧向下射线检测，前方无限生成。
  - 网络所有权：司机换人时所有权转移会「顿一下」。
  - 作者结论：**高速时站立玩家的抖动「can't be fixed」，跟 ping 有关**，这是所有用约束移动玩家的游戏的通病。
  - 来源：[DevForum: Train Move System [Dead Rails]](https://devforum.roblox.com/t/train-move-system-dead-rails/3619607)
- **「做 Dead Rails 类游戏，火车一快玩家就前后抽搐、物品乱飞」**（2025-05/06）：
  - 加摩擦无效；SetNetworkOwner(nil) 未见效果。
  - **最后的解法：改成地形移动、火车不动**，抖动和乱飞都消失了，代价是要做地形的加载 / 卸载优化。
  - 回帖指出这个方案最适合「所有玩家都在车上」的情况。
  - 来源：[DevForum 3672458](https://devforum.roblox.com/t/players-glitches-when-standing-on-a-fast-moving-platform/3672458)
- **敞篷货车上，别的玩家看到你「滑下车」**（2025-04）：
  - 原帖作者观察到 Dead Rails 没有这个问题，Jailbreak 的火车有。
  - 建议：服务器持有所有权；各客户端手动同步「玩家相对车厢的 CFrame」；或者改用新的物理角色控制器（ControllerManager + GroundController，能继承平台速度）。
  - 「Dead Rails 大概是临时把玩家锚定在车上，或者在服务器端移动」只是回帖者的猜测。
  - 来源：[DevForum 3622790](https://devforum.roblox.com/t/players-sliding-while-moving-on-car-urgent-please-help/3622790)
- **Jailbreak 老方案**：每个客户端算出「自己 HRP 相对列车根部的 CFrame」，复制给别人，别人按列车位置还原 — [DevForum 236339](https://devforum.roblox.com/t/jailbreak-train-platform-system/236339/41)（仅搜索摘要）
- **官方角色控制器**：ControllerManager 加 GroundController / AirController，物理驱动，可调 GroundOffset、加减速时间 — [Creator Docs: Character controllers](https://create.roblox.com/docs/physics/character-controllers)（仅搜索摘要）
- Dead Rails 官方实现没有公开文档。
- **网络所有权**：服务器默认把未锚定零件分给附近的客户端模拟；锚定零件永远归服务器；客户端模拟的物理服务器无法校验 — [Creator Docs: Network ownership](https://create.roblox.com/docs/physics/network-ownership)（仅搜索摘要）

**3.7 StreamingEnabled**
- 新建的 place 默认开启。StreamingMinRadius 默认 64，TargetRadius 默认 1024。
- 物理 assembly（含约束）作为整体一起流入；客户端物理只在已流入区域运行。
- 模型可以设 Atomic 或 Persistent。客户端脚本必须能容忍零件被流出（`WaitForChild` / `PersistentLoaded`）。
- 来源：[Creator Docs: Instance streaming](https://create.roblox.com/docs/workspace/streaming)
- 「跑步机」方案中车一直在原点附近，Streaming 的问题会小很多；无限生成的路面需要自己做池化回收。（推论）

### Gaps
- Dead Rails、Wild Rails TD 的真实车辆实现没有公开。
- 没测 Server Authority 对「车上射击」的实际手感。

---

## 4. 美术管线：Blender → Roblox

### Cited Findings
- **网格**：
  - 单个网格最多 **20,000 三角面**，超了就拆成多个 MeshPart；必须封闭（watertight），不能有零厚度面；
  - 蒙皮每个顶点最多 4 根骨骼影响；骨骼变换要冻结，根骨骼放在原点；
  - 一个网格只能导出一条动画轨道。
  - 来源：[Creator Docs: Mesh specifications](https://create.roblox.com/docs/art/modeling/specifications)
  - 有开发者反映 3D Importer 实际放到约 21k，Asset Manager 只有 10k — [DevForum](https://devforum.roblox.com/t/roblox-import-3d-bug/2506325)（仅搜索摘要）
- **贴图**：
  - 最大 **4096×4096**；单独上传的 UV 贴图上限 1024×1024；
  - 官方建议按物体大小选分辨率：5 stud 物体用 256，10 stud 用 512，20 stud 用 1024；
  - 格式 png / jpg / tga / bmp；
  - SurfaceAppearance 的 PBR 通道：Color、Normal（**只支持 OpenGL 切线空间**）、Roughness、Metalness、Emissive Mask；
  - **每个网格只能有一个材质、一套 UV**，UV 必须在 0–1 内。
  - 来源：[Creator Docs: Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)
- Blender 多材质物体导入后会丢贴图，要先按材质拆分网格 — [DevForum](https://devforum.roblox.com/t/roblox-import-3d-bug/2506325)（仅搜索摘要）

### Inferences
- 《逃离鸭科夫》式的俯视低模加手绘或 PBR 风格完全在 Roblox 的限制之内。要注意的是：
  - 「一网格一材质」要求我们从一开始按材质拆模型，或者烘到一张图集上；
  - Godot 那边若用 DirectX 法线，要翻转 G 通道；
  - 车内模块是数量多、体积小的物件，按官方建议用 256–512 的贴图即可。
- 我们目前的 Godot 原型不能直接迁移（GDScript 对 Luau）。只有美术资产（FBX 加 PBR 贴图）可以复用。

---

## 5. 对我们的建议

**直接采用**
1. **局内骨架照搬 Roblox 塔防惯例**：
   - 开局前的「电梯 / 车库出发」倒计时（约 20 秒，最多 4 人）；
   - 每个模块有放置上限；
   - 「两条都能升到 2 级、到 3 级锁死另一条」的效率 / 自动化分叉，与 TDX 同构；
   - 「每段路开始时结算」的经济模块（类似 TDS Farm）；
   - 自动跳波免费给，倍速可以做成付费便利项。
2. **局外学 TDS 和 Anime Vanguards 2026 的方向**：车库里用局外币直接解锁模块，用任务链升级或「进化」车辆，不靠付费抽卡。这样可以绕开英国、澳大利亚、巴西、比利时、荷兰的付费随机物品限制，也不用处理交易资格。如果以后要加随机要素，只做「免费获得的随机奖励」，不需要公示概率。
3. **技术栈**：
   - 敌人纯数据，服务器 10 Hz 下发量化坐标（Blink 或 Zap 打包），客户端插值，渲染用 AnimationController，不用 Humanoid；
   - 塔和窗口射击的命中判定放服务器，用空间网格粗筛、降低索敌频率；
   - 枪口火焰锥形特效只在客户端渲染。
4. **移动载具用「跑步机」**：车（及车内玩家）固定在原点附近，地面、路边物件和尸群往后滚动。俯视镜头本来就跟着车，玩家看不出区别；同时一次性避开物理平台抖动、玩家滑下车、Streaming 三个坑。这正是 DevForum 上 Dead Rails 类开发者最终跑通的方案。
5. **相机**：Scriptable 相机，FOV 15–25，固定 45° 俯视。车顶不要建模，或者在本地设透明；墙体遮挡用 LocalTransparencyModifier，按角色射线命中的部件逐个处理。

**避免**
- 敌人用 Humanoid 加 MoveTo，或在服务器 Workspace 里每帧改 CFrame。
- 车辆用 CFrame 或 Tween 驱动（玩家不会跟着车走）。
- 用物理约束驱动高速载具又让玩家在上面自由走动（随 ping 抖，社区认为无解）。
- 早期就做付费抽卡加交易（合规成本高，而且抽卡塔防的生命周期短，见 06 号笔记里 Anime Defenders 的例子）。
- 尸体常驻加写实血。这会把成熟度标签推向 Moderate，失去 Roblox Kids（5–8 岁）的默认受众。建议「击倒即化为燃料块」，既满足 Dead Rails 式「尸体当燃料」的乐趣，又更可能拿到 Mild。

**差异化定位**
- Roblox 上「车载塔防」（Wild Rails TD、Death Train）和「本人守车射击」（Defend The Train）都已经有人做，但没人把「一个人在车内跑动做杂务（加煤、冷却、补弹）+ 从窗口射击 + 模块塔防」做成成品。这个组合是我们相对 Roblox 存量的真正卖点；宣传素材应该围绕「手忙脚乱的车内管家」，而不是「又一个塔防」。
- Roblox 头部塔防靠周更或双周更维持（TDS 两周一个冲刺，Anime Vanguards 2–4 周一个大版本，SpongeBob TD 周更）。如果要上 Roblox，必须预先规划好内容管线：新模块、新路线、新尸种、节日活动。
