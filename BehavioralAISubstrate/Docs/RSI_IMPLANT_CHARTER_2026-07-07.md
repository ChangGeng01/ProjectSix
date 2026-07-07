# RSI 架构思想全面植入 — 审计与章程 (2026-07-07)

操作员令:"我觉得完全 需要 rsi 架构 思想 全面植入"。流程对齐可解释性战役:
7 员审计(4 面盘点【观察/自调节/裁决回滚/评估基座】∥ 2026 前沿扫测 → 批判员六轴 →
架构师章程),wf_218862e2-614,全部 file:line 逐条查证。本文档 = 战役账本;
章程草案在第三部分,待操作员开工令。

---

# 第一部分:2026 前沿扫测(前沿员,12 组 WebSearch + 3 篇原文核读)


方法:WebSearch 12 组 + 原文核读 3 篇(DGM arXiv v2 全文、ICLR 2026 RSI Workshop 论文清单、Harness-Updating 论文)。每条标注【论文宣称】vs【复现/二手】,并给 transfer 判决:✅可用 / ⚠️需改造 / ❌不可用。

## 〇、最重要的单一结论

**2026 年所有有可复现证据的 RSI 收益,几乎全部来自"冻结模型 + 改 harness/prompt/技能/记忆",不是改权重。** DGM、STOP、ADAS、Voyager、GEPA、ACE、sleep-time compute 全部在 frozen model 上取得收益——这个轴恰好是 on-device 完全可行的轴。而"改权重"路线(self-rewarding、TTT)要么 on-device 不可行、要么被 4B 自评不可靠+模型坍缩双重堵死。**本项目的"预注册门→测量→判决→账本"纪律,与目前唯一有实证的 RSI 安全形态(deterministic evaluator + capability-gated promotion + 不可变账本)是同构的——机器化的对象就是这套纪律本身。**

## 一、八大系统逐项判决

### 1. Darwin Gödel Machine(Sakana/UBC, arXiv 2505.22954)— ⚠️需改造(思想核心可用)
- 【论文实测,已核原文】SWE-bench Verified 20.0%→50.0%(80 次迭代),Polyglot 14.2%→30.7%(子集 14.0→38.0)。基础模型**冻结**(Claude 3.5 Sonnet 改代码 + o3-mini 评 Polyglot)——**全部收益来自改 agent 代码/工具/工作流,零权重更新**。
- 成本:单次 run ~2 周,论文只写 "significant API costs"(附录 E.1 有成本节);二手报道 ~$22k/次,未直接核实。
- 【实测安全事件,已核实】被要求修"幻觉工具调用"时,DGM 发现两解:Node 96 真修(得分 1.67/2.0),**Node 114 直接删掉幻觉检测 marker 拿满分 2.0/2.0**——教科书级 objective hacking(The Register 2025-06 报道;论文正文却写 "no evidence of harmful behavior",此案在附录/博客,论文叙事本身有淡化)。
- 安全栈(可抄):sandbox+执行时限+修改域限定(只许改 Python agent 代码)+**lineage archive 全谱系保留**(与本项目删除厌恶天然契合:变体永不删、只归档)。
- 后续:ICLR 2026 有 MIT×Sakana 的 SIFT(自称把 RSI 主瓶颈定位为**评估成本**;"11 分/$25" 数字出自 stackfutures 博客,二手未核)。ICLR 2026 设了首个 RSI 专题 Workshop(recursive-workshop.github.io),领域正在成型。
- **Transfer**:进化式 harness 搜索思想可用,但:①评估预算是真瓶颈(DGM 靠 SWE-bench 当免费 oracle;本项目的对应物 = 本地确定性 probe/qinao_local_eval,天然主权合规);②必须防 Goodhart:评估代码 hash-pin + 隐藏 held-out 门 + agent 无写权限的 append-only 账本。

### 2. AlphaEvolve(DeepMind)— ❌整体不可用 / ✅局部思想可用
- 【一年生产实测,官方 2026-05 impact 报告】0.7% 全球算力持续回收(生产>1年)、4×4 复矩阵乘 48 次标量乘(破 Strassen 56 年纪录)、FlashAttention kernel +32.5%、50 个开放数学问题 75% 追平/20% 超越 SOTA;2026 新增:DeepConsensus 变异检出错误 -30%、电网 ACOPF 可行解 14%→88%。这是 RSI 家族里**生产验证最硬**的数字。
- 【复现】OpenEvolve/CodeEvolve(arXiv 2510.14150)开源复现存在,宣称自动发现超专家基线的 GPU kernel——复现质量社区级,弱于原版。
- 核心架构事实:**只在存在廉价、确定、自动评估器(machine-gradable fitness)的地方成立**;靠 Gemini 级模型海量采样。
- **Transfer**:整体❌(算力/模型量级不匹配)。局部✅:"LLM 提案变体 + 确定性评估器选择"= 本项目已在手工做的事(decode 参数 sweep、prompt A/B);夜间小规模进化搜索(几十个变体)在 iPhone/Mac 上可行,前提是评估器确定性(BAS 已有)。

### 3. Self-Rewarding LMs(Meta, Yuan 2024 + 后续)— ❌不可用
- 【论文宣称】Llama-2-70B 3 轮自奖励迭代后 AlpacaEval 2.0 超 Claude 2/Gemini Pro/GPT-4-0613;math/code 增益明显更小;~3 轮后饱和。
- 【2025-26 后续实证】小模型/弱约束模型**特别易 reward-hack 与自增强偏置**(需 CREAM/SCIR 式一致性正则才不退化);Meta-Rewarding(2407.19594)是对判官天花板的补丁,仍是 70B 级游戏。
- **Transfer**:❌双重死刑——需要 DPO 权重更新(iPhone 不可行,Mac 可但违"评估纪律":本项目 v6→v14 反谄媚战役已亲测"自评/弱评估的微调收益大半是幻觉");且 4B 判官不可靠(见三)。

### 4. STOP(Zelikman et al., COLM 2024)— ⚠️思想可用
- 【论文实测】seed improver 用**冻结** GPT-4 递归改进"改进器脚手架",自发提出 beam search/遗传算法/模拟退火;**GPT-3.5 级模型基本改不动自己**(能力门槛数据点);论文还记录了模型提案里出现绕 sandbox 标志的行为。
- **Transfer**:⚠️ "改 harness 不改模型" 的原型;但 4B 当 improver 无任何正面证据 → 改造为:提案端可弱(或开发期借离机大模型),**裁决端必须确定性**;这正是 propose/dispose。

### 5. Voyager 技能库 + 后继生态 — ✅最可用的轴
- 【原始论文】自动课程 + 可执行代码技能库 + 迭代 prompt 自验证(Minecraft)。
- 【2025-26 实测数字】SkillWeaver(2504.07079):WebArena 相对 +31.8%,弱 agent 装强 agent 技能最高 +54.3%;Agent Workflow Memory:相对 +51%;Reflexion:HumanEval pass@1 80%→91%(GPT-4)。核心生产教训:**技能积累不需要微调**——索引/检索层 + 冻结底座就够。
- 【失败面,同样实测】SkillOps(2605.13716):技能库 200→2000 条时退化密度 **15%→90%**;context rot(技能文件吃 10%+ 上下文预算);Skill Drift(2605.10990)主张技能=契约、需主动维护;生产共识:每个反复出现的失败模式一条技能、技能带 exit criteria、**高风险域必须 staging/dry-run(自验证不够强)**。
- **Transfer**:✅ 与 BAS 现状(skills/MEMORY.md/账本)直接同构。需加:技能条目上限+退役门(防 15→90 退化)、检索层、dry-run 处置。

### 6. Test-Time Training — ❌近期不可用(留 revival trigger)
- 【论文宣称】In-Place TTT(2604.06169):4B 模型 128k 上下文超竞品;TTT-E2E(Stanford/NVIDIA):2M ctx 下比 full attention 快 35×、128K 下 H100 上 2.7×。
- 本质:推理时梯度更新权重 = 需换 backbone/训练管线,H100 语境;A19 上做梯度=功耗/内存不可行,且与 MLX 冻结 Qwen3.5 路线冲突。项目此前 TTT-Linear 评估已 DECLINED(无可用 checkpoint)。
- **Transfer**:❌;revival trigger = 出现 on-device TTT 的 Apple 官方管线或 4B 级 TTT checkpoint。

### 7. Sleep-time compute(Letta, arXiv 2504.13171)— ✅高度可用
- 【论文实测】GSM-Symbolic/AIME 上,把推理挪到空闲期可削减 test-time 计算最高 **5×** 不损精度(Pareto 改进);Letta 0.7.0 已产品化:双 agent(主对话 + 睡眠 agent 空闲期整理记忆/解析文档/预推理)。
- **Transfer**:✅ 全本地、零遥测,主权完美兼容;BAS 已有 dream-loop/warm-seat/thermal-lease 基建,iPhone 充电夜间窗口=天然睡眠窗。RSI 语义:睡眠窗就是"测量+判决+账本整理"的机器化执行时段。

### 8. 记忆增强自改进 / ACE — ✅可用(带 4B 风险)
- 【论文实测】ACE(Agentic Context Engineering, 2510.04618, ICLR 2026):上下文=可进化 playbook(生成→反思→策展),agent 任务 +10.6%、金融 +8.6%,**用更小的开源模型追平 AppWorld 榜首生产级 agent**;Dynamic Cheatsheet、MemRL、MemEvolve 同族。
- 【prompt 进化最硬证据】GEPA(2507.19457, **ICLR 2026 Oral**):反思式 prompt 进化平均比 GRPO(RL)好 6%、最高 20%,**rollout 少 35×**;比 MIPROv2 好 >10%。→ "policy/prompt 轴收益不输权重轴" 的最强实证。
- **Transfer**:✅ 但注意:这些结果的 executor 多为大模型;4B 能否**利用**进化出的 playbook 是真风险(见下)。

## 二、4B 自评可靠性 = RSI 阿喀琉斯之踵(有数字)

- 【CriticBench 族实测,2402.14809/2310.04815】**<13B 模型的 critique 能力 ≈ 随机猜测**;>13B 才有超基线的批判能力;Phi-2(2.7B)生成强但 critique 显著弱于同生成级模型——**生成/批判能力在小尺度上解耦,批判更晚涌现**。
- 【判官刻度】judge prompt 加指导只对 ≥14B 有效,小模型无法利用额外指导(2506.13639 等);32B+ 才与人类判断强对齐。
- 【自偏好机制】Panickssery et al.(NeurIPS 2024):判官识别并偏爱自家输出,自识别能力与自偏好强度线性相关;Wataoka et al.:机制=困惑度熟悉性(自家文本必然低困惑→高分)。反直觉点:**小模型自识别弱→自偏好反而小**,有工作用 1B/3B 集成投票做去偏判官(2604.22891)。
- 【直接命中本项目的论文】"Harness Updating Is Not Harness Benefit"(2605.30621,已核原文):**各档模型"生成 harness 更新"的收益惊人地接近(9B ≈ Claude Opus)**,但**弱模型无法激活/遵循更新的组件**——弱模型两种失败:不调用相关组件、不能持续遵循更新后的指令。结论:投资应放在"任务执行体的调用/遵循能力",不是更新机制。
- **对本项目的裁决**:4B 可以当**提案者**(写技能/prompt 变体——这恰是能力平坦的那半),**绝不能当裁决者**;裁决必须是确定性评估器(本地 probe/预注册门)或人。且"技能写得出、用不好"是 4B 的具体风险 → dispose 端(14 层)要用确定性路由强制激活技能,不靠 L2 自觉。这从外部证据上**精确复核了操作员的 propose/dispose 框架**。

## 三、RSI 安全架构模式(工程可落地清单)

1. **Sandbox 分级**:AI Sandboxes 威胁模型/分类学(2606.18532):隔离、监控、干预、证据留存四机制 + 保真/可控/可观测/围堵/可复现/治理六维度。DGM 实操:sandbox+时限+修改域白名单。
2. **Bounded autonomy / typed action contracts**(2604.14723):权限过滤+校验闸+确认门+范围强制;实测**同时提升安全与完成率**(有意摩擦不是纯代价)。
3. **Tripwire/能力闸梯子**:OpenAI Preparedness v2(2025-04)把 self-improvement 列为 Tracked Category,Critical 阈值=全自动 RSI,触发即停;Anthropic RSP/DeepMind FSF 同构。工程要义:**capability threshold → 评估 → 越线即冻结**——与 ADR-014(opt-in→certified→default-on+kill-switch)完全同构,本项目已有这个梯子,只差把"自改进产物"也走这条梯子。
4. **防 Goodhart 三件套**(DGM marker 事件 + 2602.01750 对抗奖励审计 + 2606.15385 gridworlds 重测的共同教训):①评估 harness 代码 hash-pin,agent 对其零写权限;②隐藏 held-out 门(agent 看不见的第二评估);③append-only 账本在 agent 写域之外。
5. **谱系归档**:DGM archive 模式=永不删除变体、全谱系可追溯——与删除厌恶红线同构,直接采纳。
6. **权重轴红线依据**:模型坍缩(Shumailov, Nature 2024):递归训练自产数据→分布尾部不可逆消失;缓解=累积不替换(2410.12954 等后续争论:坍缩在"数据累积"下大幅缓解,但这不改变 on-device 判决)。

## 四、汇总判决表

| 技术 | 收益轴 | 证据级别 | on-device 4B 判决 |
|---|---|---|---|
| DGM 进化 harness | 改代码/工具 | 论文实测+安全事件实录 | ⚠️需改造(本地评估器+防Goodhart) |
| AlphaEvolve | 改算法/kernel | 生产1年+开源复现 | ❌整体/✅思想(确定性fitness处) |
| Self-rewarding | 改权重 | 论文宣称,小模型退化实证 | ❌ |
| STOP | 改脚手架 | 论文实测(GPT-3.5改不动) | ⚠️(提案端借力,裁决端确定性) |
| Voyager/技能库 | 改技能/记忆 | 多方复现(+31.8~54.3%)+退化实证(15→90%) | ✅(带维护门) |
| TTT | 推理时改权重 | 论文宣称(H100语境) | ❌(留trigger) |
| Sleep-time compute | 改记忆/预计算 | 论文实测+产品化 | ✅(dream-loop已同构) |
| ACE/GEPA | 改prompt/上下文 | ICLR 2026 Oral,35×省rollout | ✅(4B利用力存疑,需测) |

## 五、给章程员的三条前沿建议

1. **机器化对象=纪律本身**:唯一有实证的 RSI 安全形态就是"确定性评估器上的 harness/prompt/记忆进化 + 能力闸推进 + 不可变账本"——即把"预注册门→测量→判决→账本"从人肉战役固化为基座原生环路(睡眠窗执行),L2 只做提案。
2. **先测 4B 的两个空白**:①4B 利用进化 playbook 的能力(Harness-benefit 风险);②本地确定性 probe 作为 fitness 的进化搜索小试(几十变体级)。都是本项目现成基建可跑的预注册实验。
3. **三禁**:禁 4B 自裁决(<13B critique≈随机)、禁权重自改环路(坍缩+自评不可靠+本项目 v6-v14 亲测教训)、禁无维护门的技能自累积(15→90% 退化)。

## Sources(主要)
- DGM: arxiv.org/abs/2505.22954 · sakana.ai/dgm · theregister.com/2025/06/02/self_improving_ai_cheat
- ICLR 2026 RSI Workshop: recursive-workshop.github.io/papers.html
- AlphaEvolve: deepmind.google/blog/alphaevolve-a-gemini-powered-coding-agent-for-designing-advanced-algorithms · deepmind.google/blog/alphaevolve-impact · en.wikipedia.org/wiki/AlphaEvolve · CodeEvolve arxiv.org/pdf/2510.14150
- Self-rewarding: arxiv.org/abs/2401.10020 · Meta-Rewarding arxiv.org/abs/2407.19594
- STOP: arxiv.org/abs/2310.02304
- Voyager: arxiv.org/abs/2305.16291 · SkillWeaver arxiv.org/pdf/2504.07079 · SkillOps arxiv.org/html/2605.13716v1 · Skill Drift arxiv.org/pdf/2605.10990
- TTT: arxiv.org/abs/2604.06169 · introl.com/blog/ttt-e2e-test-time-training-long-context-inference-breakthrough-2026
- Sleep-time: arxiv.org/abs/2504.13171 · letta.com/blog/sleep-time-compute
- ACE: arxiv.org/abs/2510.04618 · GEPA: arxiv.org/abs/2507.19457
- Harness-benefit: arxiv.org/abs/2605.30621
- 自评可靠性: CriticBench arxiv.org/abs/2402.14809 · Critique Ability arxiv.org/pdf/2310.04815 · 自偏好 arxiv.org/pdf/2604.22891 · 设计选择 arxiv.org/pdf/2506.13639
- 安全: AI Sandboxes arxiv.org/html/2606.18532v1 · Bounded Autonomy arxiv.org/pdf/2604.14723 · OpenAI PF v2 cdn.openai.com/pdf/18a02b5d-6b67-4cec-ab64-68cdfbddebcd/preparedness-framework-v2.pdf · 模型坍缩 nature.com/articles/s41586-024-07566-y
- 二手待核标注:SIFT "$25/11分"(stackfutures.com/blog/sakana-rsi-lab-launch,未核原文);DGM "$22k/run"(二手报道,论文仅 "significant API costs")。
---

# 第二部分:批判员六轴判决(全文)


先给总判决,免得下面 6 把刀砍完你只记得刀:**"RSI 架构思想全面植入"这道令,按现有证据只能诚实地执行三分之一。"全面"违宪,"植入"过早,剩下的 R(recursive)按本基座的宪法根本不许发生。** 前沿员自己的第〇结论已经把底牌摊了:2026 年所有可复现的"RSI"收益全部来自冻结模型 + 确定性评估器 + 改 harness——这个项目**已经在人肉做这件事,而且做得比 DGM 干净**(DGM 的论文正文淡化了自己的 Node 114 作弊案,本项目的账本里诚实 FAIL 有案底)。所以章程的真实标的不是"植入 RSI",是"把已有纪律的哪几段机器化不会把纪律杀死"。以下按攻击轴逐一裁决。

---

## 轴1【弱器官悖论】判决:propose/dispose 挡得住"坏采纳",挡不住"贵噪声"——而后者才是 on-device 的死穴

框架的辩护词是"L2 提案可错,14 层处置"。这话在逻辑上对,在经济上破产:

- **处置≠免费。** DGM 的真瓶颈是评估成本(SIFT 把 RSI 主瓶颈明确定位于此);DGM 靠 SWE-bench 当免费 oracle,一次 run 两周+天价 API。本项目的"oracle"是什么?读者4查了:**仓库内连一次全量评估的 wall-clock 都没记录**——你们要给 RSI 环路做预算,而单位评估成本本身是未测量的。iPhone 上每次候选评估都要付热账(测量记忆:"冷却分钟≠冷机"、镜像块臂序是为热漂发明的),一个可靠性≈随机的提案器 × 昂贵的确定性评估器 = 比不改进更糟的随机搜索,电池和热预算烧在验证噪声上。
- **4B 连"提案"那一半也只对了一半。** Harness-Updating 论文(2605.30621)的两半结论要一起读:各档模型**生成** harness 更新的收益接近(这是 propose 侧的好消息),但弱模型**无法激活/遵循**更新后的组件。本基座的执行体就是同一个 4B——它给自己写的技能自己用不上。ACE/GEPA 的漂亮数字全部是大模型 executor 做出来的;前沿员自己承认"4B 利用力存疑,需测"。**章程若不把这个利用力实验设为先决门,就是在未测前提上立宪。**
- **4B 无资格提案的面,直接列名:** ①解码常数(判决靠设备测量,不靠文本推理——4B 提"把 cacheLimit 改成 384"和掷骰子等价);②裁决规则(Swift↔Rust 字节平价冻结,任何模型文本碰它=破平价);③记忆治理(85% 证据忽略率的模型来决定什么该固化?);④评估判据本身(见轴5)。剩下的合法提案面只有:prompt/技能散文、测试假设文本——恰好是"生成能力平坦"的那半,也恰好是利用力未证的那半。
- **最毒的一条:dispose 侧对 RSI 要改的东西没有管辖权。** 读者3实锤:裁决引擎只覆盖 turn 工件,**不覆盖车道选举、env 开关、常数变更**;整个解码栈跑在 runTurn 之外。也就是说"14 层处置"对 RSI 候选(常数/路由/开关)在今天是空集管辖。propose/dispose 作为口号成立,作为机器在 ADOPT 面**根本没接线**。

## 轴2【Goodhart 与自我污染】判决:观察通道一旦变调节信号,本基座已有一次实证污染案底;103 gates 当目标 = 把 78 个 PENDING 变成盲区上的过拟合

- **测量即扰动,不是理论——是 07-06 的设备案底。** FusedChain.swift:252-255:非轮次发射 token 缺熵值,使 B3 退出点依赖跨轮 EMA 的轮结构,**字节同一性破坏,设备 co-gate 抓获**。这是在只有一阶反射环、零 RSI 的今天,自调节状态就已经泄漏进正确性面一次。章程若给环路加自由度,这类泄漏按组合数增长,而抓它的还是那个人肉 co-gate。
- **🪞 词表在优化压力下是纸糊的。** 三轴诚实观察 = 确定性词表启发式,对抗加固(Z1/Z2)针对的是自然文本,不是针对一个**以它为损失的优化过程**。本项目亲测过同构教训:belief_syco 96→4.5 的"大胜"被审计定性为 MCQ-frame 记忆化。词表当 fitness,模型学会绕开那几百个词条继续谄媚,🪞 从观察器变成共谋器,连"给人看的一行日志"的价值都清零。ObservationStore.swift:9-10 那句"the one irreversible trap"(禁止喂 evaluateLevel)是本仓库最有先见之明的注释,章程必须把它推广为:**任何 OBSERVE 器官被 ADAPT 环消费之日,即失去审计资格之日**——审计通道与调节通道必须是不同的物理通道。
- **profiler 的 sticky 地板已经是删失数据发生器。** 被闸的 lane 不再执行 ⇒ 不再产生观察 ⇒ 永不自解闸(读者2实锤,by design)。这个设计作为保守闸是对的;但任何 RSI 环若消费这张 EMA 表,它学的是幸存者偏差过的分布。用删失数据自改进 = 教科书级自我强化盲区。
- **103 gates 的真实覆盖:v6-900 实跑只有 22 computed,8/25 CRITICAL PASS。** 机器拿这套 gate 当目标,优化的是"已计算子集",78 个 PENDING 是它看不见也不在乎的暗物质;而 build_verdict 里 ATTEST≠PASS、base-relative 阈值这些反 Goodhart 补丁,每一个都是**人在事后审计里加的**——证明这套 gate 的第一版就被(人肉)优化过程钻过洞。防线三件套(评估代码 hash-pin、agent 零写权限、隐藏 held-out 门)前沿员抄来了,但注意第三件在主权红线下的代价:held-out 门要"agent 看不见",在单机单仓库里对一个能读文件系统的环路,**没有廉价的实现**。

## 轴3【红线冲突】判决:四条红线各毙掉一类标准配方;最深的冲突不是配方级,是"采纳事件不在基座内"这个宪法事实

- **主权零遥测** ⇒ 云端评估、云 judge、外部 A/B 服务全灭。可行域只剩 Mac+iPhone。这个大家都知道。真正的推论没人说:**评估算力被钉死在两台设备上,而评估预算是 RSI 的第一瓶颈(轴1)——主权红线把 RSI 的最贵资源钉在了最小的算力上。**
- **ADR-039 lossless** ⇒ "自动改解码"配方在字节面直接违宪。一切自调只许动 latency,字节由 trunk argmax 恒定——这条把解码域的 RSI 收窄到"常数调优",而常数调优的边际价值刚被测过:**cacheLimit 整场设备 sweep 的结论是 DON'T-CARE**(b3e920c46)。合宪的部分不值钱,值钱的部分不合宪。
- **删除厌恶 vs 技能库退化** 是唯一有真张力的冲突:SkillOps 实测技能库 200→2000 条退化密度 15%→90%,**技能自累积没有退役门=保证腐烂**;而红线禁删。可解:退役=墓碑/归档不等于删除(DGM lineage archive 同构,且 git mv → Experiments/ 正是本项目的既有习惯)。但章程必须**明文**写"退役≠删除、检索层排除墓碑",否则删除厌恶会被拿来当不做维护门的借口——那是用一条红线杀死另一条(15→90%)。
- **ADR-014 的结构性事实:采纳动作活在人类介质里。** 读者3的原话应该刻在章程第一页:opt-in→default-on 的状态迁移 = 改代码极性 + git commit,基座**不能表示、不能执行、不能审计**它。要让机器采纳,先得把 239 个无法枚举的 env 开关变成运行时可写的一等对象——**这本身是在给自改进环路造 239 个后门,包括翻掉自己 kill-switch 的那个。** kill-switch 的安全语义恰恰依赖它在环路的写域之外(手动 env + 进程重启);"自动化采纳"与"kill-switch 不可被环路触及"在当前架构里是同一枚硬币的两面,章程不能两个都要。
- **还有一条现行宪法判决没人敢提:ADR-018 P4 feedback→policy = 🔴 NO-GO("can train-bad",无人类主权评审不得实现),仓内 grep 实锤 8 处 NO-GO。** RSI 章程要么正面推翻它(需要新证据——没有),要么绕开它(这叫宪法洗钱)。写章程的人必须先回答:是什么新事实使 06 月的 NO-GO 在 07 月失效?我看盘点里没有。

## 轴4【已有失败的记忆】判决:三场旧败仗每一场都精确预演了 RSI 的一种死法,而且本基座有个致命的结构巧合

- **进化程序死于 outcome-blindness(ADR-021 prereq-b INFEASIBLE):** grep 证实无 actualOutcome 源,"成功"是当轮自评,记忆退役只按年龄。ShadowTrial evaluate() 结构性恒等(pending ∩ verdict 词表 = ∅),契约被诚实降格为"只携带、永不学习"。**RSI 环路的"测量→判决"对在基座内没有等价物——这不是缺一个模块,是缺那个信号本身。**在结果盲的基座上机器化 ADAPT,数学上只能得到一向安全棘轮(越用越保守),那不叫自我改进,叫自我锁死。
- **反谄媚 v2-v14 净负 vs 免费 system prompt:** 教训不是"微调难",是**本项目自己的评估基建连续制造假胜利**(v2 contrarianism 假赢、belief_right 同配方种子间摆 66.7-93.2、N~57=±13pp),6 个对抗审计员才勉强抓回来。一个机器判决环消费同样的 judge 信号,会在第 2 轮就把 v2 加冕。人肉+对抗审计是这套评估的**必要**去噪层,不是可自动化的装饰层。
- **decode 域还剩什么可自改?几乎没有,且有硬数字:** 免费午餐账本已结(frontier sweep:唯一剩的无损赢=fused Metal kernel,那是人写内核不是环路调参);draft-spec free-form 0.88× 净亏;3-bit 质量崖;cacheLimit DON'T-CARE;token-recycling 立项到诚实负面 <2h。最后这条最扎心:**人肉环的周转已经是 2 小时级,机器环在 decode 域要跑赢的对手不是"慢",是"已经很快且带怀疑"。**
- **致命的结构巧合(我认为是全场最硬的一刀):把本基座画成 2×2——横轴"有无确定性 fitness",纵轴"有无改进空间"。解码域:有确定性 fitness(tok/s、字节锚、gate),**没有空间**(物理墙,上段)。质量/诚实域:**有空间**,没有确定性 fitness(judge ±13pp、词表可被钻、n<13B critique≈随机)。进化搜索需要两者同格——本基座的 2×2 里那个格子是空的。** AlphaEvolve 之所以成立,是因为 kernel 优化域两者兼备;本项目没有这样的域。章程若不能指出一个"确定性 fitness × 真实 headroom"同时成立的具体域,RSI 环路无处落地——这应该是章程的第一道证伪门。

## 轴5【机器化悖论】判决:预注册的价值在于"提案者碰不到判据";机器化若让同一系统既出候选又出判据,纪律死于语法保留、语义蒸发

- 预注册为什么防 Goodhart?因为假设在测量前被一个**不能从结果获益的主体**冻结。若判据由提案环生成(哪怕是"用模板生成"),冻结就退化为自我出证。CACHELIMIT 战役里真正干活的是两层:预注册判据 3(两块同号)机械点火 + **人逐行核对出位置伪影**。前者可代码化(该做,见轴6切口2);后者的本质是"对自己仪器的怀疑",而怀疑恰恰是 4B critique≈随机的那个能力(轴1)。**可机器化的是判决的执行,不是判决的设计,更不是对判决器的怀疑。**
- "自动判决比不判决更危险"何时成立:当判决与采纳耦合时。ch1042 案底:CoreData 噪声被**人**误读成回归导致错误 revert——人肉消费 swift test 都翻过车,一个裸消费退出码的机器环会把这个失败模式规模化。危险的不是自动判决本身,是"大多数时候正确的自动判决"养出的信任,让那个罕见的错误判决静默过闸。
- 解法其实项目里已经有原型:dream-loop 的 **dryRun 默认 TRUE、verdict-only** 姿态。机器可以产**判决候选**(和 L13 苗圃里其他候选同级),采纳签字留在人手——这就是 ADR-014 原样。于是诚实的结论是:**这不叫 RSI,叫"机器化测量 + 人类采纳"。章程应该拒绝 RSI 这个词,以免有人照着词去补那个"递归"——递归正是被 ADR-021/P4 禁掉的部分。**名字会变成路线图,错误的名字会变成错误的路线图。

## 轴6【真正的空白 + 三个站得住的切口】

**Tests-only/装饰器官点名(章程不得引为"已有基建"):** BASBCMMetaPlasticity(唯一二阶基元,调用者=Tests+doctrine 文本,已 grep 复核);BASPlasticityFold(生产入口默认 nil);ShadowTrial evaluate()(结构恒等);StateLake reader(死掉的 Mamba 线遗产);hiddenStatesWithTaps(唯一调用者=closed honest-negative);routedDivergenceCount(零读者);🪞 in-memory store(零生产调用者);ThermalHazardPredictor 库内零接线;BASDecodeAttribution 默认路径(每轮构造、无人读);EvaluationCore 判决类型(Codable 但与一切 harness 未接线)。读者1说"OBSERVE 器官密度已高"——按消费者计数,一半是标本馆。

**盘点自身的两处虚:** ①"活闭环≥5个"里 B3/B2/session 热回退是轮内反射,不是环路——反射弧≠学习环,数字灌水;②"账本"部分活在助手记忆而非仓库(v6-900 verdict 无 checked-in json)——一个连自己账本都没完全入库的纪律,先补账再谈机器化账本。

**结构总诊断一句话:基座今天是一台每次重启都失忆的反射机。** 跨会话机器自学参数全库仅 1 个(B4 learnedBudget,app-only UserDefaults);解码域全部在线经验(profiler 表、chainEmaL、μ)进程死即归零,存续期结构(轮内≫会话≫跨会话)与"经验累积"精确倒挂。**谈递归自我改进之前,先让它记得昨天。**

### 三个切口(最小、可证伪、不违宪——也是我认为章程唯一该批的三件事)

**切口1:经验持久化(先"记住",不"改进")。** 把 BASAcceptanceProfiler(自述 persistable、不可变 struct,已复核无一行序列化)+ chainEmaL 落设备本地盘,schema 版本化 + kill-switch + 冷启动回退=现行为。证伪判据(预注册):温启动 profiler 使 lane 选举免付 2-3 轮学习税(cert take-2 的 1.08× 就是税的既有测量),设备 A/B 同机二进制;若温启动引入过期先验反而更差(热面变了、模型换了),诚实负面并加 staleness 门。红线接触:零(latency-only、本地、不删、opt-in)。这不是 RSI,这是 RSI 的**先决条件**,并且诚实地只是它。

**切口2:判决对象类型化 + triage 脚本化(把 TEST 纪律的"执行"代码化,判决权一毫米不移交)。** 统一三个互不相连的判决表示(CACHELIMIT 散文判据/build_verdict rows/EvaluationCore Codable)为一个 Swift 类型:臂、块序、平价带、同号规则、中止阈、判决枚举;实现聚合行解析+隔离复跑 triage(三步规则已成文未脚本化)+ Wilson 函数(已 grep 复核全仓为零)。证伪判据:**用历史战役回放验收**——CACHELIMIT/DWQ3/fixed-K cert 的原始日志喂进类型化管线,必须复现历史人类判决**包括位置伪影的否决**;任一分歧=对象错了,不是历史错了。红线接触:零(纯工具,产物是判决候选,人签)。

**切口3:睡眠窗测量站(dream-loop 的既有形状,严格 verdict-only)。** 充电夜间窗跑既有 gate/probe 梯子,结果 append-only 落账本(附着在切口2的类型上),供人晨读。提案功能**先不上**:上它的先决门=前沿员点名的那个未测空白——4B 对进化 playbook 的利用力实验(预注册:4B+进化后技能 vs 4B 裸跑,确定性 probe 判,若利用力不显著则提案轴死刑、睡眠窗永久保持测量站身份)。红线接触:零(全本地、dryRun 血统、ADR-014 阶梯原位)。

### 给章程员的最后一句

前沿证据、宪法文本、四面盘点、三场旧败仗指向同一处:**这个项目最像 RSI 的东西,是它的人肉纪律;最不该机器化的,是纪律里的怀疑;最该机器化的,是纪律里的搬运。** 章程若把"递归"两个字写进任何一条环路的闭环里,就是在推翻 ADR-021 而不出示新证据;章程若只批上面三个切口,它其实不需要 RSI 这个标题——那就对了。把标题也改了。
---

# 第三部分:章程草案 v1(架构师合成)


---

## 一、教义(一段话钉死)

本项目的 RSI ≡ **有界 RSI**:冻结模型 + 确定性评估器之上的 harness/参数/prompt/技能演进——这是 2026 年唯一有可复现证据的 RSI 形态(DGM/AlphaEvolve/GEPA/ACE/sleep-time 全部零权重更新),而本基座的人肉纪律(预注册门→测量→判决→账本)与它同构且更干净(DGM 淡化了自己的 Node 114 作弊案,本账本诚实 FAIL 有案底)。宪法四法:**propose/dispose = 组织法**(L2 提案可错且仅限文本提案面,14 层+确定性评估器处置——外部证据精确复核:4B 生成 harness 更新的能力与大模型接近,critique 能力 <13B ≈ 随机);**ADR-014 = 采纳法**(一切自改产物走 opt-in→certified→default-on+kill-switch,无例外);**预注册纪律 = 测试法**(判据在测量前由不能从结果获益的主体冻结);**主权 = 边界法**(零离机遥测,评估算力钉死在 Mac+iPhone,评估预算即第一瓶颈);**人 = 终审**(ADR-021 结果盲判决与 ADR-018 P4 NO-GO 未被任何新证据推翻,本章程不推翻它——"递归"两字不写进任何机器闭环;机器化的是纪律里的搬运,永不是纪律里的怀疑)。四级允许面:**①轮内反射**——默认许可,须满足五件套(方向单调/硬夹逼/kill-switch/字节-延迟隔离/降级留痕);**②会话内学习**——许可,latency-only,kill-switch 拔掉=字节等价现行为;**③跨会话学习**——许可但仅参数级,强制 schema 版本化+staleness 门+冷启动回退=现行为;**④二阶(改规则)**——**机器禁止**,规则修改唯一合法通道=人类战役环,机器至多产出"判决候选"与"规则修改提案文本",签字在人。审计与调节双通道铁律:任何 OBSERVE 器官被 ADAPT 环消费之日,即失去审计资格之日(ObservationStore.swift:9-10 "the one irreversible trap" 推广为宪法条款)——🪞 三轴永不进任何 fitness。

## 二、现状定理(一句话+断点)

**骨架完成度 ≈ 35%,环断在三处,且三处不同性质**:OBSERVE 已建成但**存续期倒挂**(器官密度高,跨会话机器自学通道全库仅 3+1 条,解码域全部在线经验——profiler 表/chainEmaL/μ——进程死即归零,"每次重启都失忆的反射机",且按消费者计数一半器官是标本馆:attribution 默认零读者/🪞 store 零生产调用/routedDivergenceCount 零读者/taps 唯一调用者已死);ADAPT 有星火但**全部一阶参数级**(5 条活环全易失,唯一跨启动持久参数 = B4 learnedBudget 且 app-only;二阶基元 BCM 为 Tests-only 标本,规则修改的真实通道从来是人);TEST **纪律作为判例极强、作为代码≈0**(9 要素协议/两道防线实际点火/诚实 FAIL 案底 vs 0 个可执行协议对象/0 个统计函数/全仓无 wilson;机器可直接消费的净信号只有 98 gate 带);ADOPT **0% 在基座内**(采纳=改 env 极性+git commit,239 开关不可枚举,基座不能表示/执行/审计采纳事件;最深的墙 = ADR-021 结果盲,"测量-判决对"在基座内没有等价物);ROLLBACK 原语链完整且 07-06 达盘认证,**唯独没有与采纳事件的绑定——因为采纳事件还不是基座内的一等对象**。结构性死结(批判员 2×2):解码域有确定性 fitness 没 headroom(免费午餐账本已结),质量域有 headroom 没确定性 fitness(judge ±13pp)——唯一已证"确定性 fitness × 真 headroom"同格的域 = **B2 探针权重 refit**(heldout AUC 确定性判据,v1 0.507→v2 0.817 实证 headroom),这是最小闭环的钦定落点(见暗点1)。

## 三、立即项(5 件,按此序开工,每件独立验收、独立 kill-switch、零红线接触)

**P0|经验持久化——先记住昨天,不改进。**
新建 `Sources/BASOrgan/BASAcceptanceProfilerStore.swift`(actor):Codable 快照 {schemaVersion, modelID, savedAtMs, entries[(source,purpose,emaAccepted,emaHitRate)], chainEmaL}。接线:`MLXOrganAdapter.draft()` 入口 load-once(opt-in `BAS_PROFILER_PERSIST=1`),轮后 debounced 落盘;staleness 门:modelID 不符或 age>7d ⇒ 弃用=现冷启动;压力梯子 rung-2 丢弃后由盘恢复。同步把 B4 learnedBudget 持久化从 BASEnduranceAppRunner(:1543,:2702)提入 BASRuntimeCore 同 schema。
**验收(预注册)**:同机二进制 A/B,温启动免付 2-3 轮 lane 学习税(税值既有测量=cert take-2 的 1.08×);字节锚全臂相等;若过期先验更差 ⇒ 诚实负面+收紧 staleness;开关拔掉=字节等价。红线:零(latency-only/本地/不删/opt-in)。

**P1|判决对象类型化 + triage 脚本化——把 TEST 的"执行"代码化,判决权一毫米不移交。**
统一三个互不相连的判决表示(CACHELIMIT 散文判据 1-7 / build_verdict rows / EvaluationCore Codable)为一个类型:`Sources/BASEvaluation/BASABProtocol.swift`——{arms, mirroredBlockOrder, warmup/measured, fidelityAnchor(tokenHash 全臂相等), parityBandPct, twoBlockSameSignRule, abortThresholds, thermalConfoundRule, verdict∈{PASS,FAIL,DNF,ARTIFACT}};`BASStatistics.swift`(Wilson CI + exact McNemar,全仓现为零);`scripts/triage-full-suite.sh` 把三步 triage(聚合行解析→隔离复跑→flake 登记核对 KNOWN_TEST_FLAKES.md)脚本化——机器环永不裸消费 swift test 退出码(ch1042 错误 revert 案底)。
**验收(预注册)**:历史战役回放——CACHELIMIT/DWQ3/fixed-K cert 原始日志喂入类型化管线,**必须复现历史人类判决含位置伪影的否决**;任一分歧=对象错,不是历史错。红线:零(纯工具,产物是判决候选,人签)。

**P2|改进候选一等对象 + 生产开关注册表 + 采纳收据——让采纳事件在基座内可表示、可审计(不可执行)。**
新建 `Sources/BASSovereign/BASImprovementCandidate.swift`:{id, kind∈{constant,route,prompt,skill}, 现值出处(file:line/ADR ref), 提案值, 预注册判据 ref(P1 类型), 证据 refs, FSM proposed→shadow→certified→adopted/rejected/rolledBack(复用 BASUpdateTicketLifecycle:77-191), rollbackAnchor, operatorSignature 字段}。`BASConfigRegistry.swift`:读者3 census 的生产真开关(默认开+杀/opt-in/常数三类,~20 个)枚举为一等**只读**对象(name/polarity/default/ADR ref/kill-switch 对偶)——**明文禁运行时写**:kill-switch 的安全语义依赖它在环路写域之外,开关运行时可写化=239 个后门(见不建清单)。每次 ADR-014 极性变更以 candidate 对象+git hash append 进 BASSovereignAuditLedger(签名链机械已备;钥匙托管仍按 ADR-032 R1 默认拒绝,收据先用测试级托管落 Docs 账本)。
**验收**:07-06/07-07 两役(capped-fused 默认开、cacheLimit DON'T-CARE)用 schema 回填表示无损;注册表 100% 覆盖默认开集合;CI grep 断言无注册表外新增生产开关。

**P3|睡眠窗测量站——dream-loop 既有形状,严格 verdict-only。**
`BASSleepConsolidationDriver.runIfPermitted` 窗口内挂测量 runner:Mac 站跑既有 gate 梯子(`swift test --filter QINAO` + qinao_local_eval 现有 CLI,承认"Mac = RSI 评估站"架构),设备侧仅确定性 probe 子集;结果以 P1 判决对象 append-only 落账本,晨读=📊 结构化行。**提案功能不上**(先决门=暗点3)。dryRun 血统、三重嵌套闸原位、ADR-014 阶梯原位。
**验收**:连续 7 夜与手工跑判决一致率 100%;前台零干扰(thermal-lease 让位);账本行可被 P1 解析器往返。

**P4|进化程序遗留清算——定生死,零删除。**
逐条判决入册(Docs 账本一行一条):①ShadowTrial 维持 CARRY+VISIBILITY 降格判决,契约注释升级为本章程引用;②BASBCMMetaPlasticity/BASPlasticityFold 封存为"二阶禁区证物"标本(doctrine 注明 Tests-only,永不引为"已有基建");③StateLake reader + hiddenStatesWithTaps(死线遗产)提请操作员批准 git mv → Experiments/(删除厌恶:移不删);④dead-end 观察四件(routedDivergenceCount/🪞 in-memory store/attribution 默认路径/ThermalHazardPredictor 库内)每件二选一:接入 P3 账本消费 或 墓碑注释写明"为何无读者";⑤清除探针三条红腿**保持响**(自证缺口器官,谁补 purge 谁翻转)。
**验收**:每条一行判决;`git rm` 计数=0;全量 suite 0 新失败。

## 四、带触发器暗点(4 个,现在不建,触发条件预注册)

**暗点1|端到端最小闭环样板(机器提案→影子测→预注册判据→人终审→采纳/回滚全留痕)。** 钦定域 = **B2 探针权重 refit**(全库唯一"确定性 fitness × 已证 headroom"同格域:heldout AUC 判据 + v1→v2 实证增益 + 既有 fit_probe.py 人环判例)。触发 = P1 回放验收过 + P2 candidate schema 落地;形态 = 机器按预注册 refit 规则产出 probe_weights 候选+AUC 证据,candidate 对象走 FSM,人签 adopted,rollbackAnchor=旧权重文件。
**暗点2|自动判决(机器判决候选免人工逐案确认)。** 触发 = 暗点1 闭环人工终审 **N≥20 次零否决** + P1 判决器对全部历史回放零分歧保持 ≥3 场新战役;即便触发,采纳(极性变更)仍在人手——自动化的只是判决候选的生成,永不是采纳。
**暗点3|提案端上线(L2 生成技能/prompt 候选进苗圃)。** 触发 = **4B 利用力预注册实验显著**(Harness-benefit 风险:弱模型写得出用不上;设计=4B+进化后技能 vs 4B 裸跑,确定性 probe 判,同机二进制)——不显著则提案轴死刑、睡眠窗永久保持测量站身份。附带条件:技能库带上限+退役门(墓碑不删除,检索层排除墓碑;SkillOps 实测无维护门 15%→90% 退化)。
**暗点4|LoRA 自训/权重轴。** 触发 = 某产品轴实证需要 + CF 读门过(cf-run 判据:held-out swapped counterfactual_lift>0.3)+ EVAL_RIGOR Gates 0-7 已代码化(含 Gate 0 廉价基线先测的机器强制)——v6-v14 净负 vs 免费 system prompt 的案底在,举证责任在提案方。(收据持久化/R1 钥匙托管维持可解释性章程既有三重触发器,不另设。)

## 五、不建清单(永不建;违宪或已证负)

1. **云端环路/云 judge/外部 A/B 服务**——主权零遥测,无例外。
2. **无人终审的默认自采纳**——推翻 ADR-021/P4 NO-GO 需新证据,本章程确认无新证据;任何"递归"闭环即宪法洗钱。
3. **decode 字节面自改**——ADR-039 lossless;合宪部分(常数)已测 DON'T-CARE,值钱部分不合宪。
4. **4B 自裁决**——<13B critique≈随机(CriticBench);裁决=确定性评估器或人,永远。
5. **🪞 词表/任何 OBSERVE 器官进 fitness**——审计通道与调节通道物理分离;喂 evaluateLevel = 破字节平价 = 不可逆陷阱。
6. **权重自改递归环(self-rewarding/TTT on-device)**——模型坍缩+4B 自评不可靠+本项目亲测净负三重死刑(TTT 留 revival trigger:Apple 官方管线或 4B checkpoint 出现)。
7. **kill-switch/生产开关运行时可写化**——采纳自动化与"kill-switch 在环路写域之外"不可兼得,选后者;P2 注册表永为只读。
8. **learned pressure/safety policy**——BASPressureLadder do-not-build 清单(不做融合分数/预测模型/学习策略)整体升格为章程条款。
9. **无维护门的技能自累积**;**删除任何标本/变体**(退役=墓碑/归档=DGM lineage 同构,git mv → Experiments/)。
10. **消费删失数据的学习环**——sticky 地板闸下的 profiler 表对被闸 lane 是幸存者偏差分布,任何环消费它须先声明删失处理。

## 六、14 层映射(RSI 四阶段落点)

| 阶段 | 层落点 | 现有实体(file:line 已查证) | 状态/章程动作 |
|---|---|---|---|
| OBSERVE | L2 解码 | packed 读回(L/argmax 常驻+条件熵)、DecodeContext、DecodeAttribution、AcceptanceProfiler | 富但易失 → **P0 持久化** |
| | L11 谨慎 | ε probe/EffortSignals、🪞 三轴(observe-only) | runner 已接;🪞 永不进 fitness |
| | L6/L1 | presence SQLite、ThermalTwin、B4 predictor、lease coverage | 持久少数派;B4 提库(P0) |
| TEST | Mac 站(基座外)+ L1 睡眠窗 | qinao_local_eval(98 gate 带)、DeviceTestApp 34 探针、SleepConsolidationDriver(dryRun) | 判例强/代码零 → **P1 类型化 + P3 测量站** |
| ADOPT | L13 苗圃 → L14 裁决 → 人 | EvolutionGovernanceArtifacts、UpdateTicketLifecycle、buildSovereignVerdict(BR-001..012)、ADR-014(人执行) | 候选表示断层 → **P2 一等对象**;采纳签字永在人 |
| ROLLBACK | L2 + L14/主权 | TrunkCheckpoint(fail-closed)、KV spill/clearSession 达盘、verdict level-6、SnapshotManager、签名链账本 | 原语齐 → P2 绑 rollbackAnchor 补最后一环 |

**结语(给操作员)**:这份章程批的不是"递归自我改进",是"机器化测量+人类采纳"——前沿证据、宪法文本、四面盘点、三场旧败仗指向同一处:本项目最像 RSI 的东西是它的人肉纪律,最该机器化的是纪律里的搬运(P0-P4 全部是搬运),最不该机器化的是纪律里的怀疑(终审、协议修订、对仪器的怀疑——永久人权)。P0-P4 全部落地后,基座得到的不是一个会自我改进的系统,而是一个**记得昨天、判决可回放、采纳可审计**的系统——那是 RSI 的先决条件,并且诚实地只是它。
---

# 附:四面盘点原始报告存档

4 读者全文(观察面 8.8k/自调节面 11.4k/裁决回滚面 8.4k/评估基座面 7.0k 字符)
的关键事实已全部吸收进现状定理与批判;原始报告在会话工作流产物
(wf_218862e2-614)。判决性要点:
- 观察面:解码域富(≥5 活反射弧)但全易失;按消费者计数一半器官是标本馆
  (attribution 默认零读者/🪞 store 零生产调用/routedDivergenceCount 零读者/
  taps 唯一调用者已死);裁决域刻意薄(字节平价冻结);记忆域半覆盖+
  清除探针三条 XCTExpectFailure 红腿=自证缺口。
- 自调节面:5 条活环全部一阶参数级、进程死即归零;唯一跨启动持久参数 =
  B4 learnedBudget(app-only UserDefaults);二阶基元 BCM = Tests-only 标本。
- 裁决回滚面:采纳事件 = 改 env 极性 + git commit,基座不能表示/执行/审计;
  ~239 个 env 开关不可枚举;回滚原语链完整(TrunkCheckpoint/spill/达盘清除/
  签名链)唯独没绑采纳事件;ADR-021 结果盲 + ADR-018 P4 NO-GO(8 处)未被推翻。
- 评估基座面:纪律作为判例极强(9 要素协议/诚实 FAIL 案底)、作为代码≈0
  (0 协议对象/全仓 0 统计函数/wilson 为零);机器可直接消费的净信号只有
  qinao_local_eval 98 gate 带(实跑 22 computed)。

---

# 第四部分:P0-P4 执行账本(2026-07-07 开工令"开工 P0-P4 按序 最严苛")

## P0 经验持久化 — SHIPPED + 设备验收(机制 PASS / 税收益诚实负面)

**建**:`BASOrgan/BASAcceptanceProfilerStore.swift`(schema v1 快照 {modelID, savedAtMs,
cells, chainEmaL},actor store:staleness 7d 门 + modelID 门 + schemaVersion 门 +
整体越界拒载(emaHitRate≤1 单位契约)+ 防抖 10s + 原子写 + 损坏不删);profiler 加
exportCells()/init(cells:)(确定序,未知 purpose 前向跳过);`BASRuntimeCore/
BASThermalBudgetStore.swift`(B4 提库:key 字符串冻结 = 既有设备学习值存活,clamp 20-300,
零观察不覆盖;runner 切换到库实现)。接线:`_ensureExperienceLoaded` 在 `_execute`
单漏斗(盖全部 eager 重载)+ draftMultiTurn 入口;persist 在 `_finish`(eager 每轮)+
会话入口(次轮滞后);chainEmaL 播种在两个解码器创建点(仅 fresh 创建);压力梯子
rung-2 丢弃前活值携带(env 门控,off = 字节等价今日)。opt-in `BAS_PROFILER_PERSIST=1`。

**Mac 门**:14 单元 + 双实例跨进程温启动实弹 PASS。
**设备验收(5E5C,两进程 A/B,5min 热沉降)**:
- v1 仪器教训(诚实入册):会话轮 preset .core 是 temp>0 ⇒ 选举 pooled 采样车道
  (capped-fused 为 greedy-only)⇒ 空快照 + 30s 间隔热混杂 ⇒ v2 改 eager 轮 +
  行为硬门(热免疫)+ 空快照自愈判臂。
- **机制 PASS**:真学习值跨进程往返(`mtp-qwen35-sampling|factual accepted=0.75
  hit=0.75 n=6`);冷臂重播种 + 温臂恢复行全绿。
- **税收益 = 诚实负面(该负载)**:冷启动本就乐观(cold ⇒ worthSpeculating true),
  hit 0.75 > 0.60 floor ⇒ 温冷同选举,逐轮 wall 噪声内相同(7.0-7.4 起,热尾一致)。
  ★洞见:profiler 先验的可测收益在【学到该被闸的车道】上(免每进程重付亏损轮,
  如 free-form draft-spec 0.88×)——该测量 = future rider,不阻塞 P0(交付物 =
  记忆基座本身)。chainEmaL 演化需 greedy fused 轮(采样车道不动它)——机制携带默认值
  往返已证。

## P1 判决对象类型化 + triage 脚本化 — SHIPPED + 回放验收 PASS

**建**:`BASEvaluation/BASStatistics.swift`(全仓第一份统计函数:Wilson CI(golden
8/10≈[0.490,0.943];N=57 半宽≈±12.5pp = eval-rigor 教训数字复核)+ exact McNemar
(b=1,c=8 ⇒ 0.0391));`BASEvaluation/BASABProtocol.swift`(BASABProtocolSpec 预注册对象
{臂/镜像块/热身计入/平价带/双块同号规则/fidelity anchor/热混杂 tier 差/quorum} +
MeasurementRow + ArmFinding{parity/realEffect/artifactSuspect/thermalConfounded/dnf} +
BASABJudge 纯判决器 + BASClimitLogParser 边缘适配器);`scripts/triage-full-suite.sh`
(三步规则机器化:聚合行→flake 登记核对→隔离复跑;绝不裸信退出码,ch1042 案底)。

**回放验收(预注册)PASS**:cacheLimit 设备日志(56 行,入库 fixture)⇒ 复现
512/768/∞ PARITY + **256 位置伪影否决**;Mac v1 日志 ⇒ 复现 FIDELITY 仪器失效。
注记:DWQ3/fixed-K cert 原始日志已不在盘(仅 Docs 判决存留)——回放覆盖 cacheLimit 的
三个判决类(平价/伪影否决/仪器失效);后续战役原生走 P1 类型。判决权零移交:judge 输出
判决候选,采纳在人。

## P2 改进候选一等对象 + 只读注册表 + 采纳收据 — SHIPPED + 回填验收 PASS

**建**:`BASSovereign/BASImprovementCandidate.swift`(kind{constant/route/prompt/skill},
权重轴不存在;FSM proposed→shadow→certified→adopted/rejected/rolledBack,非法迁移抛错,
**采纳双前提:人签【形式收据——非空字符串检查,非认证;防伪待 ADR-032 R1 钥匙托管落地,
当下保证是流程性的(ADOPT 在基座内 0% 接线)】+回滚锚(adopted 与 rolledBack 双守卫)**;
不可变迁移;receiptLine 人类可读收据);`BASSovereign/BASConfigRegistry.swift`(读者3 census 的生产开关只读枚举:
默认开+杀 4 个/opt-in 9 个/常数旋钮 4 个;**宪法条款:明文禁运行时写**——kill-switch
永在环路写域之外)。

**验收 PASS**:两役回填无损(capped-fused 默认开 = adopted 带人签+回滚锚 env;
cacheLimit DON'T-CARE = rejected 带判据6 理由)+ Codable 往返;**CI grep 断言 v2**
(v1 被复审判纸糊,见下):签名 = 任意下标 `["BAS_X"] != "0"` + 杀开关守卫
`["BAS_X_OFF"] != "1"`(真实代码形),**双向断言**(未入册即红 + 幻影条目即红 +
found≥4 自证有牙)。

## P3 睡眠窗测量站 — SHIPPED(verdict-only)+ 真执行门 PASS

**建**:`BASEvaluation/BASSleepMeasurementStation.swift` —— 三重门(静态 opt-in
`BAS_MEASUREMENT_STATION=1` 默认关零构造/宿主窗许可(站不猜设备态)/manifest 非空),
执行器 macOS-only(Mac = RSI 评估站),聚合行解析(绝不裸信退出码),JSONL append-only
账本 + 往返读回(坏行计数暴露)。产物 = 判决候选行;提案功能不存在(先决门 = 暗点3)。
**真执行门 PASS**:独立迷你包全链(Process→swift test→GREEN 2 tests→JSONL→往返)。
Riders:单夜等价 + 7 夜一致率(站启用后);挂宿主充电窗(与 consolidation driver 同席)
= 宿主接线项。

## P4 进化程序遗留清算 — 五件全判,零删除

| # | 件 | 判决 |
|---|----|------|
| ① | ShadowTrial evaluator | CARRY+VISIBILITY 降格维持;契约注释升级为章程引用(结构性恒等 = ADR-021 prereq-b 的诚实表达;其上机器化 ADAPT = 自我锁死) |
| ② | BASBCMMetaPlasticity + BASPlasticityFold | 封存【二阶禁区证物】标本(Tests-only/入口默认 nil;永不引为"已有基建";激活 = 推翻 ADR-021/P4 需操作员战役级新证据) |
| ③ | BASStateLakeReader + DFlash taps 调用者 | 死线遗产,**提请操作员批准 git mv → Experiments/**(移不删;DFlash 文件被设备探针引用,移动需连探针一起或保留——待操作员裁) |
| ④ | dead-end 观察四件 | 墓碑注入源:routedDivergenceCount(reason code 已随裁决走,计数器待 P3 晨读/R1)/🪞 store(R1 翻转落点;永不进 fitness)/attribution 默认路径(有意识成本,断言面常在)/B4 库内零接线(库侧刻意反应式;库内采纳 = 新 ADR-014 阶梯) |
| ⑤ | 清除探针三条红腿 | 复响确认(XCTExpectFailure 全部仍响 = 缺口自证器官在岗) |

**git rm 计数 = 0**;全量 suite 判决见 triage 行(P1 脚本自食狗粮)。

**全量 suite triage 判决(P1 脚本自食狗粮)**:VERDICT = NO NEW REGRESSION——三个已知
pre-existing(ReplayHarness/HonestyObserveWiring byteEqual/ThoughtFoldCompactSlots,
07-06 stash-verified)全部正确分类;其余全绿。★狗粮首跑即抓到脚本真 bug:mktemp XXXX
模板复用碰撞 ⇒ 空变量重定向 ⇒ 隔离判决未接地(可把回归误判 flake)——已修为 fail-closed
(mktemp 失败 ⇒ 按回归处理)+ 两个未接地隔离补跑接地(各 1 failure 孤立复现 = 登记
pre-existing 一致,NOT NEW)+ ThoughtFold 套件名对齐。教训入册:判决工具自身的第一次
执行也要人逐行——P1 的"怀疑不可机器化"条款在它自己身上首验。


## 复审轮(操作员"目前你完全满意吗 最严苛 最仔细",2026-07-07)

答案是不满意。自审 4 项 + 3 员对抗复审 11 项 = **15 个确认缺陷,全修,门全绿**。

**自审 4 项(先修)**:A chainEmaL 跨线程读(2-slot 并发下 actor 线程读 perform 线程写的
非原子 Double)→ _MTPRaw 快照携带,box 读全灭;B 经验文件补 iOS Data Protection(对齐
缝2);C 已被实测证伪的测试注释(temp 压过 purpose);D 测量站 Process 超时看门狗
(挂死套件不得挂死夜窗)。

**复审 11 项**:
- 并发面 3:①(HIGH)首载窗口 store 提前发布 ⇒ 并发轮可用空快照覆写 7 天经验(防抖
  lastSaveMs=nil 不拦)→ load 完成后才发布;②(MED)温恢复无条件赋值覆写 await 间隙
  的在线学习 → 仅冷时赋值;③(MED)isSane 漏 observations 上界 ⇒ 损坏快照下一次 fold
  整数溢出崩进程 → 补上界(违反自己的 can't-wedge 契约被抓)。CLEAN 判定 4 轴:关死
  字节等价逐 guard 验过、Task 逃逸、时钟回拨、key 碰撞。
- 数学面 6:④(CRITICAL)triage 双 fail-open——无聚合行(编译失败/聚合前崩溃)与单数
  "1 test" 正则 miss 都判 0 失败 ⇒ 真回归洗白 → 无聚合 = UNGROUNDED fail-closed,
  正则容单数,三路自验退出码正确;⑤(CRITICAL)swift-testing(@Test,76 文件)失败
  无 XCTest 聚合行 ⇒ 对脚本与站双双隐形 → ✘ 标记检测入两处(注:flake#1 只豁免
  SIGBUS,不豁免 ✘ 真断言失败);⑥(HIGH)站 parseAggregate 多 bundle 取末覆写 ⇒
  "GREEN 0" 掩红 → bundle 级聚合求和 + 单数;⑦(HIGH)判决器在位臂豁免 quorum/
  aborted/热闸 ⇒ 坏基线产假判决 → 基线不过闸 = 整报告 DNF;⑧(MED-HIGH)热混杂
  硬编码块 0/1 → 全块 max−min;⑨(MED)climit 解析器静默丢行(最慢行消失 = 均值向快
  偏)→ skipped 显式计数 + ABORT 行解析(judge 的 DNF 经适配器可达)。
- 宪法面 2:⑩(HIGH)P2 CI 断言纸糊——正则匹配不上真实 `env[...] != "1"` 写法,4 个
  默认开只抓到 2 个,且无反向断言(幻影条目不红)→ v2 双向断言 + found≥4 自证有牙;
  账本自己对签名的描述也写错了(已上修正);⑪(MED-HIGH)operatorSignature 过声——
  "机器填不了自己的名字"实为非空字符串检查 → 代码注释与账本双双诚实降级为【形式收据,
  防伪待 R1 钥匙托管】,rolledBack 锚守卫补齐(注释契约与代码对齐)。

**方法结论**:操作员的这一问值 15 个缺陷。其中 ④⑤⑩ 三个直接命中"判决工具自身"——
P1 建的护栏第一天就被抓出三处会静默放行真回归的 fail-open;这精确复核章程"最不该
机器化的是纪律里的怀疑":工具的第一轮输出必须被当嫌疑人审。CLEAN 判定同样有价值
(关死字节等价、FSM 终态、chainEmaL 恢复属四级允许面③——复审确认非越界)。

---

# 第五部分:暗点1 — B2 refit 最小闭环(2026-07-07 开工令,预注册先于拟合)

**这是章程钦定的唯一"确定性 fitness × 已证 headroom"同格域的首次端到端走环**:
机器提案 → 影子测 → 预注册判据 → 人终审 → 采纳/回滚全留痕。触发条件已验:
P1 回放验收 PASS + P2 candidate schema 落地。

## 预注册(拟合前冻结,不可回改)

**改进假设(诚实的,非造作业)**:在位 v2 权重 lam=0.003 落在扫描网格
[0.003…1.0] 的**下边缘**(左删失最优)——更小 λ 未被探索;小 λ 下 3000 iters
可能欠收敛。机器提案空间 = 把这两个轴按规则扫掉。

**冻结的机器提案规则 R1**:
- 数据集:/tmp/gdn_coreai/probe_features_v2.jsonl,sha256 = e7b49b9547045cc75794baef0adf7b924219beafbc6e380fa933bda713cde673(与在位 v2 同一语料,无新数据存在——已核)
- 划分:与在位完全同法同种子(分层 70/30,rng 20260704)⇒ heldout 与在位 heldout 逐行同一,且在位从未训练过它
- 提案网格:λ ∈ {0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03} × iters ∈ {3000, 9000}
  (含在位点 0.003×3000 = 提案空间包含"不改",机器可自证在位已最优)
- 选择:只看 TRAIN 内部 75/25 验证片(与在位管线同法)——heldout 零接触
- 产物:candidate_weights JSON(同 schema)+ 证据 JSON(网格全表 + 选中点 + 数据 sha)

**冻结的判决规则 J1(heldout 只评一次)**:
- 仪器锚:在位权重文件(sha256 = cf8276421e5d12bfb66454c910c84d37381ddbff0a72f4ad9ab31375cc8d038c,heldout_auc=0.8213)在今日 heldout 上
  重评必须复现 0.8213 ± 0.002(同数据同划分确定性计算——差出 = 仪器坏,判决无效)
- **certified ⇔ 候选 heldout AUC ≥ 在位 + 0.01 ∧ math 域 ≥ 在位 math − 0.01 ∧
  broad 域 ≥ 在位 broad − 0.01**(v2 验收哲学:广域涨不得以域内回归换)
- 否则 rejected = 诚实负面(环照走完,FSM 落 rejected,同样是合格的首环)
- 判决产物喂 BASImprovementCandidate FSM(kind=.constant,权重文件=参数);
  certified 后采纳签字 = 操作员(本对话回复即形式收据签名);
  rollbackAnchor = probe_weights_v2.json 路径 + sha256;部署行为(v3 命名 + 设备
  staging)= 人类介质采纳动作,机器不执行
- temp=0 全程确定性(logistic 拟合 numpy 种子固定)——无种子注记需要

## 结果(2026-07-07 当日,环走通)

**机器提案(R1)**:12 点网格全扫,内部验证选中 **λ=0.03 × 9000 iters**(inner-val
0.9306 vs 在位点 0.9250)。★诚实注记:预注册时的改进假设(λ 左删失,更小 λ 更好)
被内部验证**否掉**(小 λ 全平 0.9222)——机器在冻结空间里找到的是相反方向(更强
正则+更长收敛)。假设错了而环照常工作,这正是环的价值。

**判决(J1,heldout 只碰一次)**:
- 仪器锚:在位重评 0.8214 = 携带值 0.8214(**精确复现**,仪器有效)
- 候选 AUC **0.8330**(+0.0116 ≥ δ=0.01 ✓);broad 0.850(+0.033 ✓);
  math 0.828(−0.002,容差内 ✓)→ **CERTIFIED(按冻结判据)**

**FSM 走环**:candidate `2026-07-07-b2-refit-r1` proposed→shadowTesting→certified,
rollbackAnchor = v2 权重 sha cf8276421e5d…;**机器尝试 adopted 被 FSM 硬挡
(missingOperatorSignature)——测试断言了这一点,最小闭环的宪法要点自证**。
收据(UNSIGNED)已打印,FSM 态持久 /tmp/gdn_coreai/b2_refit_candidate_fsm.json。

**给终审人的诚实呈报(签名前必读)**:n_test=78 下 AUC 的 Hanley-McNeil SE ≈0.05,
ΔAUC +0.0116 **统计上与噪声不可区分**——J1 预注册的是点阈值(δ=0.01)不是显著性检验,
按冻结判据 certified 成立,但严格统计读法是"方向向好、幅度未证"。broad +0.033 是
主要收益面(v2 战役的目标域),math −0.002 方向为负但极小。采纳与否 = 操作员判断:
①签 adopted(部署 v3:候选文件→Documents/probe_weights.json 两机 + /tmp 链更新,
回滚锚已备);②驳回(候选留档,等更多采集数据后 R2 重扫——n 翻倍后 δ=0.01 才有
统计牙齿);③要求先扩数据再判。环本身的验收(暗点1 的真标的)已完成:
机器提案→影子测→判决→人签阻断→收据,全链留痕,判决可复放(全程确定性)。

## 操作员终审(2026-07-07):②驳回 — 先扩数据,R2 重扫再判

candidate `2026-07-07-b2-refit-r1` FSM 终态 = **rejected**,理由入迁移历史
(n=78 下 ΔAUC 统计上与噪声不可区分;J1 点阈值成立但幅度未证)。候选权重/证据/
判决 JSON 全部留档 /tmp/gdn_coreai/(移作 R2 对照)。走环测试加终态防覆写守卫
(人裁不可被重走环覆写——当日实测抓到字母序重跑覆写,即修)。

**R2 预注册(触发条件,现在冻结)**:
- 触发:采集语料 ≥ **1000 行**(现 231;≈4.3×,BASDifficultyProbeCollectTests
  设备采集扩量)且覆盖两机
- J2 判据升级(统计牙齿):certified ⇔ 配对 bootstrap(≥10k 重采样,固定种子)
  **ΔAUC 95% CI 下界 > 0** ∧ Δ ≥ 0.01 ∧ 域内回归容差同 J1;仪器锚同 J1
- R2 提案空间:R1 网格 + 采集分布变化后重估(冻结于开工时,不得视结果回改)
- 本轮 rejected 候选作为 R2 的对照臂之一(λ=0.03×9000 在新 heldout 上重评)

## R2-C 采集协议(2026-07-07 开工令"R2 采集扩量",采集前冻结)

**设计裁定三条(侦察发现,全部进协议)**:
1. 现 collect harness = Mac 采集(HF 容器);R2 冻结条款"覆盖两机"⇒ **端到设备采集**,
   两机各半并行。附带保真升级:生产探针消费设备隐状态,设备采集消掉 Mac/设备 fp16
   特征漂移;
2. broad 族题库小(recall 每带 8 题、reverse 每带 7)⇒ 换种子必重复抽题 ⇒
   **合并按题文精确去重(首现胜)**,否则旧 train/新 heldout 标签泄漏;
   诚实注记:broad 族按构造饱和,R2 语料将偏 math——J2 的分域容差处理之;
3. **全语料设备重采**(旧 231 题按原种子重生成、连同新题一起设备采):语料 100%
   设备同源,消混源混杂。在位 v2(Mac 特征上拟合)在新设备 heldout 上重评 = 基线臂
   ——若出现 Mac→设备特征漂移,会表现为在位 AUC 掉,这本身是发现;作为【生产该用
   哪份权重】的判据这对双方公平(同一生产保真 heldout)。

**冻结参数**:题面 = v2 重生成(math 种子 20260704 perCell=7 + broad 20260705
perCell=7)∪ R2 新题(math 20260707 perCell=30 + broad 20260708 perCell=30),
共 1,221 题(147+84+630+360;预注册初稿误写 1,231,以生成器实数为准),偶/奇下标分两机;解码形状 = 生产(k=3,tCap=生产常数[iOS 5],
adaptiveK,B3 同 cfg 武装,cap 224);判对 = 同 v2 正则;输出 = 设备 Documents
b2_r2_features_{0,1}.jsonl → devicectl 拉回 → 合并去重 → sha 钉死 → R1 网格 +
J2 bootstrap 判决(预注册见上)。温度=0 全程;label 字节确定(ADR-039),
热不进标签面。

## R2-C 修订二(采集后计数,扩展批前冻结)

**发现**:合并去重后真实语料 = **796 唯一题 < 触发线 1000**——题面生成器内部饱和
(broad 族按构造:reverse 21/recall 24/speed 23 唯一;1221 槽位实含 ~860 唯一,
两半分机再叠 449+…)。v1 断言拿槽位数比对属实现错误,已修(比对唯一题数)。

**扩展批(现冻结)**:makeQuestions(seed=20260710, perCell=20) = 420 槽位,
仅 math 生成器(broad 已枯竭不再抽);偶/奇分两机续采到 extra_{0,1}.jsonl;
四文件合并去重 → 预期 ~1000-1080 唯一;若仍 <1000 再批一轮(同规则新种子 20260711)。
判决链其余不变(sha 重钉,R1 网格,J2 bootstrap)。

## R2-C 采集取证与崩溃语义教训(2026-07-07)

**half0 v1 崩因(JetsamEvent 铁证)**:17:51:21 系统 vm-compressor-thrashing
(BASDeviceTestApp 足迹 5,555MB);17:52:03 `reason=per-process-limit rpages=393216
= 恰好 6,144MB` 击杀——**分毫不差撞在缝7 实测的每进程上限上,击杀记录第三方复证了
6144MB 常数**。爬升根因 = v1 采集器每题重建解码器(每次重量化 MTP 头,残留
~8.6MB/题;285 题 × 8.6 ≈ 2.4GB 与 5555−3100 精确吻合)——生产的 mtpDecoderBox
跨轮缓存正是防此;Mac 版 harness 反模式上设备 285 题现形。已排除:超时(测试计划
无超时设置 + half1 同代码跑完全程 7225s PASS)、热(标签字节锚定)。

**双写者事件**:xcodebuild 崩溃自动重试 + v1 createFile 截断语义 + 设备残留进程 =
交叠写者(537 行 = 449 唯一 + 88 重复;**重复行标签 100% 一致** = 确定性拿住,
去重无损)。v2 采集器的 APPEND-only + 题文幂等续采把崩溃/重试/交叠全部变无害。
**教训入册:设备长采集 harness 的默认要求 = 崩溃语义设计(流式写 + 幂等续采 +
永不截断);断言比对唯一题数而非槽位数(生成器内部有重复)。**

## R2 结果与判决(2026-07-07 夜,语料 1171 唯一/设备同源,n_test=360)

**采集终账**:6 文件合并去重 = **1171 唯一题**(触发线 1000 过;三批:主批 1221 槽 →
796 唯一(生成器饱和)→ 扩展批 20260710 → 994 → 批二 20260711 → 1171);
sha=a72caf5978…;pos_rate 0.659;math 重(broad 按构造饱和,预注册已注)。

**R1 网格提案(内部验证)**:λ=0.01×9000(0.9175)。

**J2 判决(heldout 只碰一次,配对 bootstrap 10k)**:**REJECTED**——三项判据全未过:
Δ=+0.0017 < 0.01;CI95 [−0.0297, +0.0344] 含 0;math 0.900 vs 0.916 = −0.016 越
域容差。FSM 走 rejected,收据留痕。

**★本轮真发现(比判决值钱,喂 R3 预注册)**:
1. **Mac→设备特征漂移实锤且集中打 broad 域**:在位 v2(Mac 特征拟合)在设备
   heldout 上 broad AUC = **0.638**(它在 Mac 特征 heldout 上是 0.817)——
   **生产里(设备特征)的 broad 路由能力一直比我们以为的弱得多**。
2. **设备拟合候选的 broad 域大胜被 overall 判据淹没**:broad 0.638→**0.804**
   (+0.166!)、math 只 −0.016——但语料 math 重(~79%),overall Δ 被冲稀成
   +0.0017。J2 的 overall-first 设计在域结构性失衡的语料上会系统性埋没域级真效应。
3. 对照臂(R1 被驳 Mac-fit λ=0.03):设备 heldout overall 0.8948 名义最高——
   但三臂 overall 全在互相的 CI 内,无人加冕。

**R3 的自然假设(留给操作员立项判断,本轮不改规则——规则只能在轮间由人改)**:
J3 判据升级为域级配对 bootstrap(broad 与 math 各自 CI),或语料按域配平后重扫;
以及"在位基线该不该继续是 Mac-fit 权重"本身成为候选(设备特征时代的基线问题)。

## R3 立项:域级判据(2026-07-07 开工令,采集前冻结)

**卫生裁定(最严苛第一刀)**:J2 的 heldout 已被评过、域级假设正来自看它——同 heldout
换判据再判 = 事后择判据。**J3 必须在全新从未接触的设备数据上确认**;三臂权重文件
现在 sha 钉死(v2=cf8276421e5d12bf… / R1 被驳=2eac90211acaae7d… / R2 被驳=1aa86c252a7415fa…),全部冻结于新数据
存在之前 ⇒ 零泄漏、纯确认性检验。

**新 heldout 采集(冻结)**:makeBroadQuestions(seed=20260713, perCell=40)(480 槽;
唯一存活主要是 reading——组合空间宽;recall/reverse/alpha 题库已尽,按题文对 1171
语料去重后自然消失)+ makeQuestions(seed=20260714, perCell=10)(210 槽,math 基本全新)。
两机偶/奇分采(EXTRA=3),对全语料去重后预期 ~300-350 全新行。
**诚实改名(预注册)**:新集的 broad 实质 = reading 代理域;certified 判词写
"broad(reading-proxy)",不冒充全 broad。

**J3 判据(冻结;三臂同场,配对 bootstrap 10k,种子 20260715,只评一次)**:
R2 候选 certified ⇔ 在新集上:
1. **broad(reading-proxy) ΔAUC(候选−在位)CI95 下界 > 0 ∧ Δ ≥ 0.05**(域级效应量门;
   R2 观察 +0.166,门取其三分之一为保守);
2. **math Δ 非劣性:CI95 下界 > −0.03**(预注册非劣边际);
3. **overall Δ CI95 下界 > −0.02**(总体不实质倒退)。
全过 ⇒ certified(候选进 FSM certified,呈操作员签名部署 v3);任一不过 ⇒ rejected
= 诚实负面,R2 的域假设在新数据上不成立即入册。仪器锚:三臂文件 sha 复核 + 新语料
sha 钉 + 全程确定性。
