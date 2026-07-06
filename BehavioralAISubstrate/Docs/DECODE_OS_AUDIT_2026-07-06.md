# Decode-OS 论纲审计 (2026-07-06)

操作员论纲:**"最强 decoder 不是一个会生成 token 的模型,而是一个会管理状态、记忆、候选、验证、缓存和硬件的解码操作系统。"**

方法:9-agent 工作流(7 支柱盘点员 × 全代码库 file:line 取证 + 对抗批评者 + 架构综合者,131 万 token,231 次工具调用)。原始输出:session 任务 `wb2b3yjt9`(临时,已摘录于此)。

## 总裁决

**论纲半对——而对的那一半不是口号说的那一半。**

- 打穿 25.0 tok/s 带宽墙的不是"OS",是**一条被削到骨头的车道**(fused MTP 25.7):每一分赢都来自**减少每轮工作**(单 forward、单 packed readback、tCap=5 躲 qmv 悬崖、in-graph cumprod)。
- 战役的诚实负面全部共享同一个道德:**管理机器输给周期成本**(DFlash 0.57× 且接受度完美、tree 0.76×、draft-model 0.88×、B4 duty-shaping 15 vs 25.3)。
- 但"已经是 OS"的自我形象在**每一条组合缝**上被证伪(下节 8 条)。真正的执法机制不是代码,是 ADR-014 社会流程(opt-in→Mac 门→设备协门→default-on+kill-switch)——这才是项目真正的王冠。

**改写论纲**:最强 decoder = 一条削到骨头的车道 × 一个让**组合**保持诚实的操作系统。OS 的职责不是让 token 更快(那是物理),而是保证组合不出错:状态不复活、路由不失忆、闸门看得见彼此、预算只有一种货币。(= 14 层"弱器官+强控制"哲学在 L2 内部的缩影。)

## 六支柱记分牌

| 支柱 | 已有(认证级) | OS 裁决 |
|---|---|---|
| 状态 | fused 快照恢复、BASSessionKVStore(唯一 offset-correct)、GDN 2-slot 契约 | 快照习语 **6 份逐字复制**,4 种回滚机制并存;盘级=服务,解码级=复制粘贴 |
| 记忆 | 池+LRU+spill+GC+warm-park(55/55 认证) | 接近 OS,但"死亡"坏了(见缝 #2)+ 第二份不 spill 的逐出副本 |
| 候选 | MTP 自适应-K(生产)、sampling 车道、DFlash(封存)、prompt-lookup | 路由海拔=管理;源海拔=N 条手写循环,无契约 |
| 验证 | fused verify + packed readback + ADR-039 无损契约 | 一条认证内核,但**5 个 verify 循环各自重实现**,不变量靠注释执法 |
| 缓存 | 权重/KV/prompt/buffer-pool/盘快照 5 层 | 各层有主,**跨层压力仲裁不存在**;唯一执行器接在退役车道上 |
| 硬件 | B4 预测器(先验已持久化)、tCap、jetsam 纪律、59GB/s 地面真相 | **5 个独立 thermalState 读者=5 种意见**;3376MB 常数比实测过期 2.9GB |
| 控制面 | planner、B2 探针 v2、B3、0.60 粘性地板、~20 个 kill-switch | 无一个决策点同时看到(难度,热,内存,目的);效率环大脑休眠 |

## 审计抓到的 8 条渗漏缝(组合缺陷,多数在 default-on 车道)

1. **capped-fused 车道无热闸**(MLXOrganAdapter.swift:1213-1247 只查 temp/cap/history):serious+ 时照跑 MTP——恰是认证测得 0.52-0.62× 损失、planner 存在就为了避开的区间。最新 default-on 流量逃出了最老的认证保护。**认证回归级。**
2. **clearSession 不删 spill 文件**(:1478-1498 只清 RAM 层):spill 或 dream-loop warm-park 之后 clear,下一 turn 从盘上**复活已清对话**——违反"fresh start"契约,主权基座上的隐私缺陷(Caches 未加密)。
3. **spill 文件名碰撞**(:1388-1389 '#'→'_'):`a#scout` 与 `a_scout` 同名——一个座位可温启动到**另一个座位的对话**(跨会话 KV 泄漏)。失败的 restore 也不删陈旧文件。
4. **路由类变形=无声失忆**:fusedTranscripts 座位收到一个 temp>0/uncapped/cap>384 请求 → 落入 pooled fresh-session 分支(:1265-1273 从不读 fusedTranscripts)→ transcript 永不迁移。endurance cert 没抓到:每个 cert 座位形状固定。
5. **profiler 三种货币一本账**:mtpSpec 记 accepted/round(~3.38 尺度),model-free 车道记真 proposed(≤1.0 尺度),同一个 0.05 地板横跨;B3 早退路径还会多记 accepted(至多 kNow−closeAt−1/代)。任何按一种货币调的地板会静默错闸另一车道。
6. **draft-model 两道闸全是装饰**:2.7 地板永远冷(executor 不出 accept 遥测)、熵闸三个生产调用点全传 nil。哪天 host 一行配置装上同族 draft 模型,greedy free-form 直通设备实测 0.88× 损失——两道"看着已认证"的闸在纸面武装、在数据流里惰性。
7. **内存"唯一真相"过期 2.9GB**:代码 3376MB ActiveHard vs 实测 ~6.29GB(只活在账本里)。fit 预算/水位线/admission 全按错误天花板校准(会拒绝设备明明跑得动的负载);唯一的压力→执行器连线(U1)驱动的是已退役 draft-model 常驻。
8. **B2/热控可对打 + 逐出优先级反转**:难题+过热的 capped 会话 turn:B2 只看 hidden state 说"+1 档预算",热控说"刹车",无组件同时看到两者 → 设备最需要省的时候花得更多。另:_evictBeyondCap 在调用者 turn 路径上同步 await 受害席的整段生成+多 MB 写盘(第 17 席阻塞);2-slot decode governor 只在 pooled 路由获取——default 的 capped-fused 类不受 jetsam-margin 治理。

## 批评者对"大一统"的三条否决(全部有测量背书)

- **verify 内核统一已被尝试并回滚过**:sampling 车道委托 lean fusedLink 数值,acceptance 0.72→0.59 掉穿 0.60 地板自灭(decoder.swift:138-143 钉住 fat mtpForward)。"6 份 verbatim 复制"里有一部分是**伪装成重复的承重 per-lane 数值**。统一快照机制可以,统一数值不行。
- **每 turn 冻结热快照会撤除在飞逃生舱**:adaptedK 的 per-round ProcessInfo 读是 384-token 长 turn 中途 tier 翻转时的 K=1 钳制;冻结一次=按 fair 区间 0.91-0.99× 的损失 K=3 跑完全程。中央化以架构整洁换掉一条被测量的保护。
- **DraftSource 协议是给 N=1 客户做泛化**:唯一赢的耦合车道是 fused MTP,其余租户全是测量损失。协议等 token-recycling 真要上再立。

## 架构师的最小统一案(提取,非发明;~4 value type + 1 协议 + 1 枚举扩展;零 per-token 新机器)

按 (收益确定性 ÷ 爆炸半径) 排序,每步 ADR-014,以**字节恒等 + tok/s 平价(>1% 即中止)**为数值中止判据:

1. **BASTrunkCheckpoint**——6 份快照复制→1 个所有者(泛化 n-slot 走 BASSessionKVStore 的通用枚举;只统一机制,per-lane 数值原样);+3 条 emit 位点常驻断言(L≤kNow、行区间、违约 fail-close 到 plain);2 个钉住测试(GDN 2-slot、offset-unused)。天级可发。
2. **Step-0 热补丁**——capped-fused 两个入口条件加 `_thermalThrottled()`。独立于一切抽象的认证回归修复,**本周可发**,热相 endurance 复跑作门。
3. **SessionSeat 生命周期所有者**——先修 4 bug(clear 达盘、文件名哈希、transcript 迁移、逐出单源化+吸收 fusedTranscripts),再合并 struct;门=混合流量 endurance 批次**扩一个 07-06 认证漏掉的形状:同席 capped→uncapped**。附带:spill 目录设 `.completeUntilFirstUserAuthentication`(一行)。
4. **SpecVerifyKernel(谨慎版)**——generateSpecKFused 本体改名为内核、MTP 链为唯一 provider 的无操作重构;tok/s 平价不过就放弃协议只留内部提取。sampling 车道以 0.60 地板活体金丝雀作第二 provider;generateSpecK/compiled* 冻结为数值锚,永不迁移;DFlash 循环不迁(B1 复活触发才移植)。回报:token-recycling 成为第一个"按 provider 价格"而非"按整循环重移植价格"认证的新源。
5. **DecodeContext + 压力梯子**——每 turn 组装一次 (目的,温度,cap,热姿态,内存余量,会话估计,profiler 快照) 的**值**,穿给 planner/路由/解码器;**保留 adaptedK per-round 重读作在飞逃生舱**;每 turn 一行"谁在刹车、为什么"日志。梯子:先重基 6.29GB 常数(纯赢),再 opt-in `BAS_PRESSURE_LADDER`(顺序=按实测回收成本:warm-park 冷席→drop mtpDecoderBox→clearAllSessions→cacheLimit 收缩;drainGPUCache 保持诊断级,per-iteration 有毒的负面立着);合成内存猪认证。**不建**:统一"压力分数"标量、in-decode 内存检查、学习型路由器、调度线程。

预期直接 tok/s 收益 ≈ 0——这个计划买的是**正确性、生存性、和下一根杠杆边际成本降 10×**(59GB/s 的部件已在 plain 天花板之上解码,剩下的速度只在下一个候选源里)。

## 状态

审计=评估交付,未动生产代码。缝 #1-#3 是可立即立项的认证回归/隐私修复;#7 的常数重基是纯赢。等操作员指令。

## 修复轮 (2026-07-06 "开工 按序修 8 条缝 最严苛")

全部 8 条缝按序修复,每缝:亲手复核指控 → 测试先行 → 修复 → Mac 门 → 设备证据。
提交链:a0af3c20c (缝1-4) → 70f03f0c4 (缝5-6) → 131512b02 (缝7-8) → 设备批。

| 缝 | 修复 | 关键证据 |
|---|---|---|
| 1 热闸 | 共享被调方 `_generateMTPSpecFromMessages` 热时走 `generatePlain`(原位长出 EOS+B3 traceExit,含 primed-in-think 扫描——门测试抓到未 primed 时 budget guard 死火烧满 cap 的真 bug);路由类不变;`BAS_THERMAL_FORCE` 测试缝(只许保守方向) | Mac+设备门:fallback=plain、trace-exit budget 点火、召回 ZEPHYR、席位留 transcript-land、答案尾存活 |
| 2 清除达盘 | clearSession/clearAllSessions 删 spill 文件+pending 项;`_persist` 单缝设 iOS Data Protection | 纯门 3/3:达盘、旁观者存活、全清空目录 |
| 3 文件名 | SHA256(key) 文件名(a#scout≠a_scout);restore 失败消费损坏文件+计数 | 纯门碰撞对;模型门:损坏文件被消费、fresh 席正常 |
| 4 路由失忆 | pooled fresh 分支前插 fusedTranscripts 迁移(同 init(history:) 契约) | 模型门:capped 种 OBSIDIAN → uncapped 召回、transcript 消费、落池 |
| 5 货币 | Run 增真 `proposed`(fused Σ kEff/轮);emaHitRate 全车道 ≤1;每轮口径地板(0.15/0.60/2.7)读 emaAccepted 不动校准;B3 force-close 丢弃尾退账(原 LOW-4"immaterial") | 纯合同门 + 直播 .mtpSpec 折账 hitRate≤1 |
| 6 硬闸 | `draftModelTelemetryAvailable`(恒 false 直到遥测管道存在)∧ draftModelLoaded 才入候选——诚实负面由构造执行 | 全 purpose 结构性拒绝门;车道逻辑经遥测武装夹具原样保留,38/38 |
| 7 重基 | `resolvedActiveHardCapBytes()` = os_proc_available_memory+phys_footprint(权限感知);3376MB 降级保守回退;admission/governance/catalog 运行时点升级 | **设备:解析 6144MB vs 常数 3376MB(entitled 宿主找回 ~2.8GB 准入)**;Mac 解析 nil→回退,13/13 确定性保持 |
| 8 三件 | (a) pending-spill 侧表:逐出不再内联 await 受害席写盘(优先级反转),代际防陈旧覆盖,活体回收零成本;第二份不 spill 的逐出副本单源化 (b) 2-slot governor 盖住 capped-fused(peakSessionDecodes 遥测) (c) 热节流时 B2 只降不升 | 逐出双路径召回 GRANITE(即时=pending 回收/settled=落盘恢复,spilled=4/restored=4);4 并发 capped 峰值≤2;升/降档对测 |

Mac 全量回归:15,988 用例,0 新增失败(3 个预存于 HEAD,stash 验证)。

**设备认证批 (iPhone Air, 全缝合并后)**:
- jetsam 探针:解析上限 **6144MB**(vs 旧常数 3376MB,entitled 宿主找回 ~2.8GB 准入余量)
- 缝1 热强制门:fallback=plain ×2、B3 budget 点火 (think=16)、召回通过、席位留 transcript-land
- capped-fused 召回再认证:6/6、pooled=0(v2 探针 + 全缝叠加下)
- **spill endurance 重认证 PASS**(pending-spill 新机械):67 轮、召回 12/12、63 spill/61 restore、
  serious 热态全程、零挂起(376s)
- **capped-fused endurance mixed 重认证 PASS**(热闸+governor 叠加下):17 轮、跨路由类召回 5/5、
  transition 照常触发、pooled=2、零挂起(680s)

8/8 缝闭合,全部带 Mac 门 + 设备证据,ADR-014 纪律全程(kill-switch:BAS_THERMAL_FORCE 只许保守方向;
其余修复为认证回归/正确性修复,恢复既有认证语义,不引入新 opt-in 面)。

## 统一案轮 (2026-07-06 "继续 最小统一案 按序 1-5 最严苛")

提交链:a1bb73dc2(案1)→ [缝1即案2,已闭] → 案3(同链)→ a2fef7601(案4)→ 3a0e98d17(案5)。

**案1 BASTrunkCheckpoint — SHIPPED**:6 份 `(m, m[0], m[1])` 快照复制 → 1 个 value type(机制统一,
per-lane 数值原样;n-slot 通用枚举与 BASSessionKVStore 同源)。新增旧习语没有的常驻保护:trim 返回值
受检(under-run → 各车道 fail-close)、fused 入口组合守卫(不支持的缓存组成 → 直落 generatePlain 且
B3 保留)、emit 位点 L∈[0,kNow] 不变量。钉住:暖 MambaCache=2 槽、卷绕 Rotating 拒组合、
**Qwen3.5 forward 不推进 ArraysCache.offset(设备级钉住 PASS)**。门:F1 保真/trace-exit/F6/
sampling E2E+lossless/K=1 全绿。DFlash 循环仅设备 A/B 可练(封存车道,同机制,诚实记录)。

**案2 Step-0 热补丁 — CLOSED-BY-SEAM-1**(修复轮已提前落地并设备认证)。

**案3 车道选举纯函数 — SHIPPED**:三段内联守卫链 → `_sessionLane`(opt-in fused > capped-fused >
pooled,溢出迁移显式入类型);两相成本门控保留旧短路轮廓(warm pooled 轮不付权重 stat/token 估算);
池内获取序保持缝认证原样。门:7 例形状矩阵(每个缝-4 失忆形状钉 .pooled)+ 行为锚复跑
(热门/OBSIDIAN 迁移/损坏 spill)。决策:byte-accounting 池界不做——footprint 直读的梯子取代。

**案4 谨慎内核 — SHIPPED**:`BASTrunkDraftProvider`(类绑定,每轮一次派发,GPU 常驻草稿,
自掩蔽状态契约)+ `BASQwen35ChainDraftProvider`(adaptedK/draftAndCommit 原文搬迁,EMA 仍持久在
decoder,per-round 热逃生舱留在 provider——批评者对冻结热快照的否决执行)。按否决:sampling 车道
(fat-mtpForward 数值)、generateSpecK/compiled*(数值锚)、DFlash(封存)**不作 provider**。
回报:token-recycling/DFlash 复活按 provider 价格认证。门:F1 保真锚 + trace-exit + F6 + 直播货币。

**案5 DecodeContext + 压力梯子 — SHIPPED**:每轮一次组装(purpose/temp/cap/热/内存余量)穿两个
eager planner 位点(委托重载=字节恒等);BAS_DECODE_CTX=1 每轮一行"谁能刹车"。梯子
(BAS_PRESSURE_LADDER=1 opt-in):纯滞回机(按解析 cap 的余量分数;触发即闩锁,阈值+带宽以上才
重臂防抖);rung1=缝8a pending-spill park 冷席(零内联阻塞)/rung2=释放 MTP decoder(车道自愈
重量化)/rung3=清全部+收缩 MLX 池。**设备认证(合成猪 vs 解析 cap 6144MB):3158→854MB 触
rung1(被 park 席温恢复、对话无损)→521MB 触 rung2(decoder 释放、capped 车道自愈)→进程存活、
回收 3491MB,fired=[1,2] 严格按序**。rung3 不实弹(5% 余量下故意猪=jetsam 轮盘;纯门钉逻辑,
诚实记录)。不建清单执行:无热+内存标量、无 in-decode 采样、无学习路由。

**回归**:Mac 16,006 用例 0 新增失败(3 预存);设备 floor 探针 rawBW=60GB/s(地面真相一致)。
Follow-up(独立测量战役,非本轮):cacheLimit {256,512,768,∞} × 混合流量 A/B。

**案4 设备 tok/s 平价判决(诚实版)**:sustained 探针直呼 generateSpecKFused(仪器有效)。两轮
(热饱和 / 13.5min 冷却后)min00 完全相同 21.4 tok/s(暖起点下确定性可复现),平台保持率 56-61%
与文档 57% **形状吻合**;绝对值(平台 12.5-13.1 vs 文档 14.2)差异与起点热标度一致
(21.4/24.9≈0.86 ≈ 12.8/14.2≈0.90),但**跨热基线的绝对比较不可判**(机身连跑 2h 热饱和,
13.5min 冷却后 min00 仍 thermal=2)。>1% 中止判据的物理界:provider=每轮 3 次动态派发
(~百 ns / ~50-80ms 轮)≪0.01%,且 F1 保真锚=草稿逐 token 相同⇒接受度/轮数相同。
**判决:无回归证据;绝对平价复测记 rider——下一个冷机会话先跑一次 sustained
(min00 对 21.4-24.9 带、平台对 14.2 带),先于任何加热负载。**

**案4 平价·冷机 phone-2 复测 (2026-07-06 晚,操作员改派整日零负载的第二台 Air)**:
min00=22.0 @ thermal=1(fair——模型加载突发+首分钟满负荷即离开 nominal)、平台 min1-5 =
13.4-13.7 @ 61-62%(thermal=2 从 min5)、总 8448 tok/10min。判决:**平台平价 IN BAND**
(14.2±7% ⇒ [13.2,15.2],实测 13.4-13.7;保持率形状 61-62% ≥ 文档 57%);首窗绝对值
仍受起点热态混淆(fair@min00,且跨设备/环境温差),**不可判也非回归证据**。首窗终判
= 明早 07:52 定时任务(job 6e5dc1ae):phone-1(基线同设备)过夜真冷后直跑 sustained。

**案4 平价·phone-1 当晚即跑 (操作员指令"现在就跑",闲置 ~1h 后)**:min00=19.5 @ thermal=2
(起点仍 serious → 按判据首窗不可判、顺延)。平台 12.2-13.2 @ 62-68%。关键观察:phone-1 今晚
三轮同一二进制的平台**单调回升**(11.4 → 12.0-13.1 → 12.2-13.2),随散热改善上移 —— 差值由
热主导的直接证据;冷机 phone-2 同一二进制平台 13.4-13.7 带内。首窗终判仍 = 明早 07:52
定时任务(phone-1 过夜真冷)。

**案4 平价·终判 (2026-07-06 晚,同机同晚新旧二进制 A/B — 决定性)**:基线二进制(65d432103,
今晨 M4 测量所用)经 worktree 重建,phone-2 上 B1(旧)→A1(新)背靠背:
- **10 分钟总产出逐字节相等:旧 34 代/6528 tok = 新 34 代/6528 tok**(饱和热态,热为共模)
- B1(旧,较冷槽位)min00=20.8 —— 旧二进制同样呈现晚间暖起点抑制,且低于新二进制更早槽位的
  22.0/22.4;A1(最热槽位)min00=11.1、保持率 ~100%(起点即热地板,burst 余量耗尽)
- 叠加:冷机 phone-2 平台 13.4-13.7 ∈ 晨基线带 [13.7-15.0] 下沿、F1 保真锚、物理界 ≪0.01%

**判决:8 缝 + 统一案 1-5 全链 tok/s 无回归 —— CONFIRMED(同条件 A/B,强于任何跨日比较)。**
今晨 24.5 的 min00 是晨间真冷机环境条件,当晚整日热浸后不可复现(2h+ 冷却不复位机身热质量);
明早 07:52 定时任务保留为完整性数据点(nominal 起点 24.5 的复现记录),平价问题本身已闭。
方法教训入册:①跨热基线绝对 tok/s 不可判,同机同晚二进制 A/B 才是仲裁器;②保持率在热饱和
起点下失义(min00=地板 ⇒ retention≈100% 是伪信号);③"冷却 N 分钟"不等于冷机 —— 机身热质量
以小时计,真冷机只有过夜。

---

# 归档章 (2026-07-06 深夜 — DECODE-OS 三部曲 CLOSED)

**一天完成的完整弧**:操作员论纲("最强 decoder = 解码操作系统")→ 9 员审计(裁决:半对——赢的是
削到骨头的车道;OS 当施工蓝图重蹈 DFlash、当组合审计清单抓出 8 条真缝)→ 8 缝按序修复+设备认证
→ 最小统一案 1-5 全落地 → 新旧二进制同机 A/B 平价终判(无回归)。

**提交链(13 commits,d78a87fee 尾巴收殺 → 98c45ff87 平价终判)**:
a0af3c20c(缝1-4)· 70f03f0c4(缝5-6)· 131512b02(缝7-8)· cc277b7f8(设备批)·
a1bb73dc2(案1 checkpoint)· e58d02081(案3 车道选举)· a2fef7601(案4 谨慎内核)·
3a0e98d17(案5 上下文+梯子)· b8daeb79e/98d3c03ce/67eee8faf/98c45ff87(账本+平价)。

**生产面变化(全部恢复/加固既有认证语义,零新 default-on 行为)**:
- 修复:热闸覆盖会话车道 · clear 达盘+文件保护 · SHA256 spill 文件名 · 路由迁移 · profiler 真
  proposed · draft-model 结构性拒绝 · 6144MB 运行时解析 cap · pending-spill 异步逐出 ·
  governor 全覆盖 · B2 热抑制
- 结构:BASTrunkCheckpoint(1 所有者+3 常驻不变量+3 钉住)· _sessionLane 纯选举 ·
  BASTrunkDraftProvider(下一根杠杆按 provider 价格认证)· BASDecodeContext(每轮一次事实)
- 新 opt-in:BAS_PRESSURE_LADDER(设备认证 rungs 1-2)· 新测试缝:BAS_THERMAL_FORCE(仅保守向)·
  BAS_DECODE_CTX(遥测)
- 回归:Mac 16,006 用例 0 新失败;设备:spill endurance 67轮 12/12 · capped-fused mixed 17轮 5/5 ·
  压力梯子存活认证 · 同机二进制 A/B 6528=6528

**立着的 rider**:①07-07 07:52 晨任务(nominal 起点 24.5 复现,完整性数据点,cron 6e5dc1ae,
session 态)②cacheLimit {256,512,768,∞} A/B(独立测量战役)③token-recycling = 第一个新 provider
(有 tok/s 上行空间的下一根杠杆)。

**本战役的元结论**:最强 decoder = 一条削到骨头的车道 × 一个让组合诚实的 OS。这一天把后半句从
隐喻变成了机器:不变量从注释进了代码,路由从守卫链进了类型,清除到达了磁盘,预算只剩一种货币,
而全部代价 —— 以同机二进制 A/B 为证 —— 是零个 token 每秒。
