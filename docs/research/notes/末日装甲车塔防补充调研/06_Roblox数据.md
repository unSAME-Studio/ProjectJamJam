# Roblox 同类作品数据核查：载具即基地 + 丧尸 + 塔防/增量

数据时点说明：
- 「visits / 当前在线 / favorites / 赞踩 / created / updated」全部来自 Roblox 官方公开 API，抓取时间 **2026-11-02 14:40 UTC**（`games.roblox.com/v1/games`、`/v1/games/votes`、`groups.roblox.com/v1/groups`、`apis.roblox.com/game-passes`）。下文用「API」指代这次抓取。
- API 的 `created` 是 universe（游戏容器）创建日期，**不等于公开上线日**；Roblox 游戏常先私下开发数周到数月。
- 历史峰值 CCU 来自第三方追踪站 Rolimons（2026-11-02 访问），口径是该站自己的采样，可能和 Roblox 内部数据有出入；Rolimons 对 2022 年以前的老游戏可能没有完整记录。
- 好评率 = 赞 /（赞 + 踩），用 API 的 votes 自行计算。

## 1. 原文稿列出的 7 款作品：基础数据

### Takeaway
七款里只有 Dead Rails、A Dusty Trip、Tower Defense Simulator 至今仍有 1.8 万–3.2 万的稳定在线；Toilet Tower Defense 约 9 千；Anime Defenders 已基本死亡（154 人）；原文稿里的 Build and Kill Zombies 是 **2026-08 才出的新游戏**（峰值约 14 万，现在不到 2 千）；「Zombie Defense Tycoon」同名作品体量很小，原文稿描述无法对应到具体某一款。

### Cited Findings

数据表（API，2026-11-02 14:40 UTC；峰值来自 Rolimons）：

| 作品（当前标题） | 开发者 Group（所有者） | universe 创建 / 最近更新 | 总访问 | 当前在线 | 历史峰值（日期） | 收藏 | 赞 / 踩（好评率） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [👻EVENT] Dead Rails | RCM Games（RiccoMiller），认证 | 2025-01-01 / 2026-10-31 | 6,638,050,920 | 25,869 | 1,476,198（2025-04-19） | 6,171,812 | 3,353,012 / 269,517（92.6%） |
| a dusty trip [🎃HALLOWEEN] | Jandel's Road Trip（用户 jandel），认证 | 2024-02-16 / 2026-10-31 | 2,611,871,886 | 18,642 | 572,612（2024-05-18） | 2,354,416 | 2,034,865 / 225,041（90.0%） |
| Build and Kill Zombies | Zombie Car Crusher（misfitsbsthree），认证 | 2026-08-19 / 2026-10-26 | 62,659,657 | 1,705 | 139,882（2026-09-26） | 1,314,379 | 291,514 / 6,052（98.0%） |
| Zombie Defense Tycoon 💥 | BG Tycoons，未认证 | 2024-01-19 / 2026-04-19 | 28,858,300 | 22 | 未查 | 1,667,225 | 15,983 / 3,695（81.2%） |
| Undead Defense Tycoon（同类老牌大亨，补充） | Box Games | 2020-09-09 / 2026-05-08 | 277,128,134 | 78 | 未查 | 910,137 | 355,420 / 24,885（93.5%） |
| [🌙 NIGHT 4] Tower Defense Simulator | Paradoxum Games（BelowNatural） | 2019-06-05 / 2026-10-31 | 5,058,753,833 | 31,560 | 159,824（2025-10-04，Rolimons 口径） | 3,538,422 | 2,087,927 / 130,447（94.1%） |
| [🔨FIXES] Toilet Tower Defense | Telanthric Development | 2023-06-17 / 2026-11-02 | 6,203,099,518 | 9,333 | 522,376（2024-03-09） | 1,546,733 | 1,349,928 / 227,499（85.6%） |
| Anime Defenders | Small World Games x Anime Defenders，认证 | 2024-04-05 / 2026-10-21 | 3,434,673,704 | 154 | 377,836（2024-07-21） | 918,143 | 2,025,319 / 68,884（96.7%） |

- 上表 visits、在线、收藏、赞踩、日期 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7018190066,5650396773,10741654282,5543744826,1998877948,1176784616,4778845442,5836869368)、[Votes API](https://games.roblox.com/v1/games/votes?universeIds=7018190066,5650396773,10741654282,5543744826,1998877948,1176784616,4778845442,5836869368)
- Group 所有者 — [Groups API: RCM Games](https://groups.roblox.com/v1/groups/11867394)、[Jandel's Road Trip](https://groups.roblox.com/v1/groups/33097934)、[Zombie Car Crusher](https://groups.roblox.com/v1/groups/171280950)、[Paradoxum Games](https://groups.roblox.com/v1/groups/4914494)
- 峰值：Dead Rails 1,476,198（2025-04-19） — [Rolimons](https://www.rolimons.com/game/116495829188952)；A Dusty Trip 572,612（2024-05-18） — [Rolimons](https://www.rolimons.com/game/16389395869)；Build and Kill Zombies 139,882（2026-09-26） — [Rolimons](https://www.rolimons.com/game/105011592530400)；TDS 159,824（2025-10-04） — [Rolimons](https://www.rolimons.com/game/3260590327)；TTD 522,376（2024-03-09） — [Rolimons](https://www.rolimons.com/game/13775256536)；Anime Defenders 377,836（2024-07-21） — [Rolimons](https://www.rolimons.com/game/17017769292)
- 原文稿 RoTrends id 5650396773 就是 A Dusty Trip 的 universeId（根 placeId 为 16389395869） — [Universe API](https://apis.roblox.com/universes/v1/places/16389395869/universe)（反查 place→universe 的接口实测可用）
- Roblox 搜索「zombie defense tycoon」返回的同名游戏「Zombie Defense Tycoon 💥」，其简介实为「Military Defense Tycoon」：建军事基地、扛丧尸波次、开坦克飞机 PvP，「按按钮赚钱、杀丧尸赚钱」 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=5543744826)
- Build and Kill Zombies 核心循环：在基地「roll」抽零件 → Build Mode 装到底盘 → 开车冲过丧尸场，按距离和击杀拿现金 → 油耗尽（0% fuel）停车结算 → 现金再投入抽零件和技能树；攻略建议把武器装在车头先接触丧尸、技能先点 Luck — [allthings.how 新手指南](https://allthings.how/build-and-kill-zombies-on-roblox-how-to-play-your-first-run/)、[allthings.how 造车指南](https://allthings.how/build-and-kill-zombies-beginner-s-guide-to-building-a-zombie-crushing-car/)
- Build and Kill Zombies 简介：「Build your car! / Add crazy weapons & defenses! / Crush waves of zombies! / Earn cash and upgrade your build! / How far can YOUR car survive?」 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=10741654282)

### Inferences
- 原文稿把 Build and Kill Zombies 列入「已有作品」时没有时间信息；实际它 2026-08-19 才创建，属于 2026 年下半年的新爆款，**说明「拼车冲尸群 + 距离结算 + 增量」这个最接近我们的形态在 2026 年仍能起量**，但也说明它衰退极快：峰值约 5 周后在线只剩约 1.2%。
- 「Zombie Defense Tycoon」只是一个泛指的大亨子类，原文稿对它的描述（踩按钮买墙炮塔、转生解锁新区域）符合 Roblox tycoon 惯例，但无法对应到具体某款；这一行最好改为「丧尸防御大亨类（Undead Defense Tycoon、Zombie Battle Tycoon 等）」。
- Anime Defenders：好评 96.7%、34 亿访问，当前在线 154，峰值后约 2 年衰减到 0.04%，是「抽卡塔防热潮来得快去得快」的典型样本。

### Gaps
- Zombie Defense Tycoon、Undead Defense Tycoon 的历史峰值未查（Rolimons 有 Cloudflare 拦截，只能逐页 WebFetch，预算不够）。
- TDS 的真实历史峰值可能在 2020–2021 年更高，Rolimons 的 159,824 只能当作「其追踪期内的峰值」。
- 无法从公开 API 得到「公开上线日」，只能用 universe 创建日 + 媒体报道近似。

## 2. Dead Rails 与 A Dusty Trip：峰值、访问和当前趋势

### Takeaway
Dead Rails 峰值约 100 万–148 万 CCU（2025 年 3–4 月），现在约 2.6 万，只有峰值的约 1.75%，但 2025 年底以来已企稳、靠节日活动小幅回升；A Dusty Trip 峰值约 57 万（2024-05），现在约 1.9 万（约 3.3%），同样是「爆发后长尾」形态。两者都是长线存活，但都远离巅峰。

### Cited Findings
- Roblox 官方：2025 年 3 月 Dead Rails「spiked to 1 million concurrent users, using all available CPU capacity」（文章 2025-06-24 发布） — [Roblox Newsroom](https://about.roblox.com/newsroom/2025/06/roblox-infrastructure-supporting-record-breaking-games)
- Rolimons：Dead Rails 历史峰值 1,476,198（2025-04-19） — [Rolimons](https://www.rolimons.com/game/116495829188952)
- RoWatcher 显示「All-time peak players: 1.4M (April 2025)」，并估算月收入约 $334,088（置信度 0.61，约 $4M/年，属第三方估算） — [RoWatcher](https://rowatcher.com/games/7018190066/event-dead-rails)
- RoWatcher「是否在死亡」页：当前 26K、7 日均 22K、30 日均 18K、30 日变化 +22.2%（同期 Roblox 整体 +4%），并给出「79K 峰值（2025-11-28）」——这个 79K 明显只是其追踪区间内的峰值，与 1.4M 矛盾，应以 Rolimons / Roblox 官方为准 — [RoWatcher dying](https://rowatcher.com/games/7018190066/event-dead-rails/dying)
- GameAnalytics 博文称 Dead Rails 从几百人涨到 10 万+，「over 200K players at once during peak times (CCUs climbed to over 600K this past weekend)」，未注明具体日期；文中提到 2025 年 2 月下旬获 Roblox 推荐位 — [GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)
- Gameranx（2025-03-31）称游戏上线约三个月、玩家「crossed one million」——是累计玩家，不是 CCU — [Gameranx](https://gameranx.com/updates/id/533597/article/roblox-dead-rails-hits-million-mark-with-players)
- Dead Rails 当前：在线 25,869、访问 66.4 亿、收藏 617 万、好评 92.6%；universe 创建 2025-01-01，最近更新 2026-10-31（标题挂 [👻EVENT]，说明仍在做节日活动） — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7018190066)
- A Dusty Trip 峰值 572,612（2024-05-18） — [Rolimons](https://www.rolimons.com/game/16389395869)；RoWatcher 各标题版本页给出的峰值为 5 万–5.8 万（2024-07 / 2024-12），同样应视为其追踪区间峰值 — [RoWatcher](https://rowatcher.com/games/5650396773/a-dusty-trip-halloween)
- A Dusty Trip 当前：在线 18,642、访问 26.1 亿、收藏 235 万、好评 90.0%；universe 创建 2024-02-16，最近更新 2026-10-31 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=5650396773)
- GameAnalytics 当时引用 A Dusty Trip「1.4B+ visits」作为对比 — [GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)

### Inferences
- 当前/峰值：Dead Rails 25,869 / 1,476,198 ≈ 1.75%；A Dusty Trip 18,642 / 572,612 ≈ 3.3%。两者都是「一次性爆发 + 节日活动维持 2 万上下」的长尾，属于 Roblox 上中上游的存量游戏，而非上升期。
- Dead Rails 在 2026 年并没有「死」：30 日 +22% 主要来自万圣节活动，这是季节性回升，不应解读为品类复兴。

### Gaps
- 没拿到 Dead Rails / A Dusty Trip 的逐月 CCU 曲线（RoMonitor、RoTrends 页面未成功抓取）。
- 官方收入数字没有公开；RoWatcher 的收入是模型估算。

## 3. Dead Rails 机制核查（原文稿声明逐条）

### Takeaway
「喂锅炉（引擎炉）、尸体可当燃料、把东西焊上车、局外货币 Bonds 买职业和火车」均属实；「焊上车的东西有重量、会拖慢加速」**只能部分证实**——找到的说法是「重量越轻越省煤」，没有找到「拖慢加速」的直接来源。

### Cited Findings
- 燃料：「anything that can be burned … is fuel」，可以烧僵尸、狼人等生物的尸体，也可以烧椅子、书、轮子等杂物；放进「engine furnace」后燃料表上涨，涨幅取决于物品；燃料距离在火车起速后才准确（文章 2025-04-23） — [Beebom](https://beebom.com/dead-rails-fuel/amp/)
- 煤是最好的燃料但稀缺，前期依赖在堡垒（fort）买煤；一块煤满速约跑近 4,000 米 — 搜索摘要，来源 [Beebom](https://beebom.com/dead-rails-fuel/amp/)、[Bluestacks 新手指南](https://www.bluestacks.com/blog/game-guides/roblox/rl-dead-rails-beginners-guide-en.html)（未逐页核对）
- 焊接：拖动物品时按 Z 焊到车上；不焊的话贵重物和尸体会从车上飞出；队友倒地要把身体焊上车带走 — 搜索摘要，来源 [Bluestacks](https://www.bluestacks.com/blog/game-guides/roblox/rl-dead-rails-beginners-guide-en.html)、[itemlevel 新手指南](https://itemlevel.net/dead-rails-complete-beginners-guide-how-to-play/)（未逐页核对）
- 重量：一份火车指南写「less weight means you burn less coal」；Wooden Train 标称普通 75 km/h、Conductor 加成 97 km/h、每次装 3 块煤 — 搜索摘要，来源 [DeltiasGaming Wooden Train](https://deltiasgaming.com/?p=268084)（页面 WebFetch 返回 405，未直接核对）
- 局外：Bonds 是局外货币，在大厅买职业和起始物品；Doctor、Miner 等职业约 15 Bonds；Wooden Train 285 Bonds、Ghost Train 325 Bonds；Conductor 职业让火车更快并自带 2 块煤，Miner 挖煤更快 — 搜索摘要，来源 [DeltiasGaming 火车排行](https://deltiasgaming.com/?p=222098)、[DroidGamers 职业指南](https://www.droidgamers.com/guides/dead-rails-train-classes-guide/)
- 通关：完成 80 km 路程、击败 Boss「Nikola Tesla」，获胜得星级和 Bonds — 搜索摘要，来源 [DeltiasGaming Bonds](https://deltiasgaming.com/?p=230372)
- 背景设定：1899 年「Zombie Plague」，解药在墨西哥，和朋友一起坐火车穿越丧尸荒漠；单服最多 16 人 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7018190066)
- GameAnalytics 概括：「Players defend a steam-powered train from the undead … while scavenging for fuel and parts」，提到车载炮塔（train-mounted turrets） — [GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)
- 每局随机、带 roguelike 元素、可选职业、燃料管理 — [Gameranx](https://gameranx.com/updates/id/533597/article/roblox-dead-rails-hits-million-mark-with-players)

### Inferences
- 原文稿「尸体当燃料」「焊东西上车」「局外货币买职业和车型」可保留。
- 「重量拖慢加速」建议改成「车上负重影响油耗（据攻略）」，或注明未核实。
- Dead Rails 有「车载炮塔」，所以原文稿「它没有塔防」的差异化说法要收紧：它没有**模块化的塔防布局与升级树**，但并非完全没有车载防御。
- 视角：原文稿说 Dead Rails 是「第一人称」；Roblox 默认第三人称、可切第一人称，未找到 Dead Rails 强制第一人称的来源，建议改成「多人 3D 第三/第一人称」。

### Gaps
- 粉丝 wiki（dead-rails.fandom.com、roblox.fandom.com）返回 402，未能打开核对。
- 「Bonds 能否直接用 Robux 买」未核实（开发者商品 Developer Products 无公开列表接口）。

## 4. 开发者身份与是否被收购

### Takeaway
Dead Rails 由 RCM Games（Group 所有者 RiccoMiller，530 万成员）开发，没有找到任何被收购/出售的报道；A Dusty Trip 所在 Group「Jandel's Road Trip」的所有者账号是 jandel——即 Grow a Garden 背后 Splitting Point 的 Janzen「Jandel」Madsen 一系，但「原创还是收购」来源不一致。

### Cited Findings
- RCM Games Group（id 11867394）所有者 RiccoMiller（userId 106439014），成员 5,230,668，认证 — [Groups API](https://groups.roblox.com/v1/groups/11867394)
- 搜索「Dead Rails RCM Games acquired sold」无任何收购报道；2026-03-31 的 games.gg 文章仍称 RCM Games 为开发商 — [games.gg](https://games.gg/zh-CN/news/dead-railsroblox僵尸游戏/)
- Gameranx 称 Dead Rails 出自「an experienced creator studio」，其上一作没破百万 — [Gameranx](https://gameranx.com/updates/id/533597/article/roblox-dead-rails-hits-million-mark-with-players)
- Steam / Epic 上另有一个同名「Dead Rails」（温哥华电影学院学生作品、双摇杆射击），与 Roblox 版无关 — [Epic Games Store](https://store.epicgames.com/p/dead-rails-81078e)
- Jandel's Road Trip Group（id 33097934）所有者账号 jandel（userId 10916243），成员 7,371,155，认证 — [Groups API](https://groups.roblox.com/v1/groups/33097934)
- Janzen「Jandel」Madsen 的公司叫 Splitting Point，对 Grow a Garden 做 live service、每周更新，称 Grow a Garden 峰值 2,230 万 CCU（采访 2025-09-07） — [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/)
- 粉丝站说 Grow a Garden 原作者是 BMWLux，Splitting Point 后来入股；A Dusty Trip 与 Jandel 的关系说法不一：一处称「purchased or partnered」（自称推测），韩文 namu wiki 称由 Jandel 的表亲 Jhailatte 参与开发、Jandel 收购 — [gag2-wiki 历史](https://gag2-wiki.pages.dev/history/original-game/)、[namu.moe Jandel](https://namu.moe/w/Jandel)（均为非权威粉丝来源）
- Grow a Garden 当前 Group「The Garden Game」所有者为 DevNamedDavid — [Groups API](https://groups.roblox.com/v1/groups/35789249)
- Build and Kill Zombies 的 Group「Zombie Car Crusher」所有者 misfitsbsthree（显示名 ben），成员 763,409 — [Groups API](https://groups.roblox.com/v1/groups/171280950)

### Inferences
- A Dusty Trip 背后是 Roblox 头部发行/运营方（Splitting Point 系），这类作品的成功高度依赖发行方的买量、推荐位和每周更新节奏，小团队复制的难度被低估。
- Dead Rails 被收购的说法不成立（至少到 2026-11-02 没有公开证据）。

### Gaps
- 没有找到 RCM Games 团队规模、RiccoMiller 背景的权威报道；也没有 Bloomberg / The Verge 对 Dead Rails 的商业报道。
- A Dusty Trip 原始作者与收购时间无官方说法。

## 5. 2025–2026 同赛道其他作品

### Takeaway
2025 年 3 月 Dead Rails 爆红后马上出现大量「火车/沙漠公路/丧尸」跟风（Army Roads、Dead Sands、A desrt、Mad Road），多数一两个月就停更、在线跌到几百；2025 年底到 2026 年的新起量作品转向「搜刮+建防御扛尸潮」（Survive the Apocalypse、Zombie Rush Survival、Survive Zombie Arena）和「拼车冲尸群」（Build and Kill Zombies）。整个大盘的绝对头部已是 99 Nights in the Forest、Steal a Brainrot 这类生存/偷窃玩法。

### Cited Findings

API 数据（2026-11-02 14:40 UTC）：

| 作品 | 开发者 Group | universe 创建 / 最近更新 | 总访问 | 当前在线 | 收藏 | 好评率 | 类型（据简介/标题） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Army Roads 🚂 | JMJ games | 2025-03-14 / 2025-04-09 | 190,500,914 | 959 | 146,899 | 96.0% | 火车穿越，Dead Rails 跟风；更新一个月后停 |
| Dead Sands | Emperor Games. | 2025-03-19 / 2026-07-17 | 89,925,689 | 113 | 5,479,184 | 95.0% | 沙漠载具生存 |
| A desrt [SANDBOX] | DarkCodes studio | 2025-03-18 / 2026-11-02 | 285,166,632 | 17,145 | 431,737 | 89.5% | Dusty Trip 式沙漠公路沙盒，仍有 1.7 万在线 |
| [UPD] Mad Road | Century Nomads | 2025-06-18 / 2025-09-24 | 86,369,601 | 915 | 1,975,009 | 93.5% | 公路载具冒险 |
| [🎃EVENT] 🧟 Survive the Apocalypse | Rubicon South | 2025-11-04 / 2026-10-27 | 281,808,283 | 11,757 | 478,547 | 94.1% | 搜刮城市、建防御、扛丧尸、尝试逃离 |
| [🎃] Zombie Rush Survival 🧟‍♂️ | Undead Dev. | 2026-05-08 / 2026-10-24 | 150,891,487 | 8,120 | 194,802 | 97.4% | 无尽波次，买武器升级，放炮塔/路障/陷阱 |
| [🎃] Survive Zombie Arena | Nectarforge Studios | 2025-12-13 / 2026-11-01 | 763,786,722 | 3,552 | 703,385 | 95.4% | 丧尸竞技场生存 |
| [🎃] Tower of Zombies 🧟 | Undead Dev. | 2025-07-23 / 2026-10-29 | 330,124,889 | 1,428 | 2,302,538 | 95.2% | 丧尸主题爬塔 |
| [☠️] build ur base ⚔️ | High Quality Games! | 2025-08-05 / 2026-03-16 | 227,893,728 | 543 | 8,363,626 | 94.6% | 建基地防御 |
| [UPD] 🧟 Zombie Battle Tycoon 🧟 | InfinityBattles | 2022-12-21 / 2026-03-31 | 196,488,061 | 750 | 263,146 | 91.0% | 丧尸大亨 |
| 99 Nights in the Forest 🔦 | Grandma's Favourite Games | 2025-03-04 / 2026-10-31 | 30,379,787,402 | 190,418 | 10,155,436 | 90.5% | 多人森林生存（参照：大盘头部） |
| [🎃] Grow a Garden 🌶️ | The Garden Game | 2025-03-25 / 2026-11-01 | 36,004,276,756 | 19,568 | 11,465,249 | 89.9% | 种田放置（参照） |
| [💀] Steal a Brainrot | BRAZILIAN SPYDER | 2025-05-16 / 2026-11-01 | 74,311,283,769 | 89,242 | 29,680,693 | 85.1% | 偷窃大亨（参照） |

- 上表数据 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7373989866,7400570888,7398552394,7939389895,9098570654,10138624079,9348272796,8238863102,8353962342,4202932581,7326934954,7436755782,7709344486)、[Votes API](https://games.roblox.com/v1/games/votes?universeIds=7373989866,7400570888,7398552394,7939389895,9098570654,10138624079,9348272796,8238863102,8353962342,4202932581,7326934954,7436755782,7709344486)
- Survive the Apocalypse 简介：「Loot the City / Build Defenses / Survive the Zombies / Will you Escape?」；Zombie Rush Survival 简介：「Fight endless waves of zombies, get upgrades, defeat bosses, and build defenses … Place turrets, barricades, and traps!」 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=9098570654,10138624079)
- Roblox 搜索「dead rails」「zombie car」还返回 Steal A Deadly Rails、Snowy Rails、Frost Rails、Build a Deadrails!、Deadly Rails Roleplay、Build a Car to Kill Zombies 等大量跟风，当前在线多在两位数到一百多 — [Roblox Omni Search API](https://apis.roblox.com/search-api/omni-search?searchQuery=dead%20rails&sessionId=abc123&pageType=all)
- 另有「Wild Rails Tower Defense 🚂」（universe 7513026554）这类火车主题塔防 — [RoWatcher](https://rowatcher.com/games/7513026554/wild-rails-tower-defense)
- 有 YouTube 视频标题「99 Nights in the Forest is what Dead Rails should've been」，说明玩家把两者视为同一波「多人生存」潮 — [YouTube](https://www.youtube.com/watch?v=q922bPJT8G8)
- 99 Nights in the Forest 当前在线 190,418，是此次抓取中最高 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7326934954)

### Inferences
- 跟风作品的共同命运：上线 1–3 个月内吃到 Dead Rails 的搜索流量（Army Roads 1.9 亿访问），然后停更衰退；真正留下来的只有有持续运营的 A desrt（仍有 1.7 万在线）。
- 2026 年的增量在「丧尸波次 + 放炮塔/路障」（Zombie Rush Survival 2026-05 起，1.5 亿访问、好评 97.4%）和「拼车冲尸群」（Build and Kill Zombies）上，而不是「火车穿越」本身。我们「车 + 车载模块塔防 + 增量」正好落在这两者交集，但都是短生命周期品类。

### Gaps
- 这些作品的历史峰值未逐一抓取；核心循环只依据官方简介，未实测。
- 没找到 Roblox 官方或第三方的「品类 CCU 汇总」数据，无法量化「火车/载具生存」子品类在 2026 年的总盘子。

## 6. 变现方式

### Takeaway
同类作品主流变现是 Game Pass 直接卖强力武器/载具/背包/数值（A Dusty Trip 30+ 个通行证，单价 99–699 Robux），以及抽卡倍率（Build and Kill Zombies 卖「永久幸运」「双倍现金」「更快抽」）；TDS 卖塔和 VIP；Dead Rails 的 Game Pass 很少（4 个武器/背包），主要靠局外 Bonds 进度。

### Cited Findings
- Dead Rails Game Pass：Tommy Gun 175、+5 Storage 95、Mauser C96 148、Sawed-Off Shotgun 148（Robux） — [Game Passes API](https://apis.roblox.com/game-passes/v1/universes/7018190066/game-passes?passView=Full&pageSize=50)
- A Dusty Trip Game Pass（节选）：Minigun 599、Railgun 499、Nuke Launcher 599、Orbital Cannon 599、SUV 599、Flame Truck 699、Classic Bus 450、Trailhawk 699、Quad Bike 699、10 SLOT BACKPACK 679、extra health (300% more) 150、sprint (20% faster run) 99、Car Radio 129 — [Game Passes API](https://apis.roblox.com/game-passes/v1/universes/5650396773/game-passes?passView=Full&pageSize=50)
- Build and Kill Zombies Game Pass：4x Permanent Luck 229、2x Permanent Luck 149、2x Cash 179、Faster Roll 129、Premium Paint 99 — [Game Passes API](https://apis.roblox.com/game-passes/v1/universes/10741654282/game-passes?passView=Full&pageSize=50)
- Tower Defense Simulator Game Pass（节选）：VIP 375、Engineer 1690、Hacker 2249、Mercenary Base 1350、Sandbox Plus+ 7999、限时塔 Harvester 799 / Executioner 799 — [Game Passes API](https://apis.roblox.com/game-passes/v1/universes/1176784616/game-passes?passView=Full&pageSize=50)
- Dead Rails 收入为第三方估算约 $33.4 万/月 — [RoWatcher](https://rowatcher.com/games/7018190066/event-dead-rails)
- Grow a Garden 方 Madsen 称「we put our product first. Our decisions are made for players」，并强调每周更新的 live service — [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/)

### Inferences
- Roblox 同类作品普遍「付费买强」（武器、载具、倍率），与原文稿「开箱、交易、付费倍率都不抄」的取向冲突：如果做 Roblox 版，不卖倍率/强力武器，收入会明显低于同类；若卖，又会损害我们的增量设计。
- Developer Products（一次性消耗品、Bonds 包等）没有公开接口，实际收入结构可能比 Game Pass 列表显示的更依赖消耗品。

### Gaps
- 无 Developer Products 数据；无任何官方收入数字。

## 7. 市场判断：「载具即基地 + 丧尸」在 2026 年是热、升还是退？Roblox 版值不值得做？

### Takeaway
这个细分在 Roblox 上**已过巅峰、处于存量长尾**：Dead Rails（2025 春 100–148 万 CCU → 现 2.6 万）和 A Dusty Trip（2024-05 57 万 → 现 1.9 万）都只剩峰值的 2–3%，2025 年的跟风作品大多已死；2026 年仍有新作起量（Build and Kill Zombies 2026-09 峰值约 14 万），但衰退极快（5 周后约 1.2%）。结论：题材有现成受众、可以短期起量，但不是上升赛道；以 game jam 小团队来说，Roblox 版更适合做「低成本验证/引流实验」，不适合当主平台。

### Cited Findings
- Dead Rails：峰值 1,476,198（2025-04-19），现 25,869 — [Rolimons](https://www.rolimons.com/game/116495829188952)、[Roblox Games API](https://games.roblox.com/v1/games?universeIds=7018190066)
- Dead Rails 近 30 天 +22.2%（万圣节活动），同期 Roblox 整体 +4% — [RoWatcher dying](https://rowatcher.com/games/7018190066/event-dead-rails/dying)
- A Dusty Trip：峰值 572,612（2024-05-18），现 18,642 — [Rolimons](https://www.rolimons.com/game/16389395869)
- Build and Kill Zombies：创建 2026-08-19，峰值 139,882（2026-09-26），现 1,705，访问 6,266 万，好评 98.0% — [Rolimons](https://www.rolimons.com/game/105011592530400)、[Roblox Games API](https://games.roblox.com/v1/games?universeIds=10741654282)
- 跟风作品 Army Roads 2025-04-09 后停更、现 959 在线；Mad Road 2025-09 后停更、现 915 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7373989866,7939389895)
- 同期大盘头部：99 Nights in the Forest 190,418 在线、Steal a Brainrot 89,242 在线 — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7326934954,7709344486)
- Roblox 头部爆款背后常有专业运营方（Splitting Point 每周更新、live service） — [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/)
- Dead Rails 爆红与 2025 年 2 月下旬的 Roblox 推荐位相关 — [GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)

### Inferences
- **热度判断：退潮中的成熟子品类**。2024（A Dusty Trip）→ 2025 春（Dead Rails 及跟风）是高峰；2025 下半年起大盘注意力转向多人生存（99 Nights）、偷窃/种田大亨；2026 年该子品类以「丧尸波次塔防」和「拼车冲尸群」的形态零星起量，单作生命周期以周计。
- **Roblox 版的利**：受众对「车 + 丧尸 + 增量」已有认知；Build and Kill Zombies 证明 2026 年一个新 Group 也能做到 14 万峰值、6 千万访问；Roblox 天然多人，正好解决原文稿「单人还是合作」问题。
- **Roblox 版的弊**：(1) 需要整套用 Luau 重写，Godot 原型无法复用；(2) 起量依赖推荐位 / 买量 / 每周更新，jam 团队难以持续；(3) 品类主流变现是付费买强，与我们设计取向冲突；(4) 爆款后极速衰退，跟风窗口通常只有 1–3 个月，现在追 Dead Rails 已晚 1.5 年。
- **建议**：主线仍做 PC/Steam（差异点「剖面里有人在跑」在 Roblox 3D 环境里也不易呈现）；如想试 Roblox，可做一个极小的「拼车冲尸群 + 车载炮塔 + 局外升级」体验做市场探针，目标是验证「车载模块塔防」在 Roblox 玩家里的留存，而非收入。
- 原文稿措辞修订建议：「Roblox 上已经有同类爆款和现成受众」→ 改为「Roblox 上有过同类爆款（Dead Rails 2025 春峰值约 148 万），但现已回落到 2–3 万在线的长尾，2026 年的新作起量快、退得也快」。

### Gaps
- 无 Roblox 官方品类级数据（Roblox Discover 分类趋势、推荐位机制、ARPDAU），无法定量判断子品类总盘子的同比变化。
- 没有找到 2026 年针对「载具生存」品类的权威行业报道（Bloomberg、The Verge 等此次搜索未命中）。
- 对 Roblox 版开发成本、团队 Luau 能力未评估（不在本调研范围）。
