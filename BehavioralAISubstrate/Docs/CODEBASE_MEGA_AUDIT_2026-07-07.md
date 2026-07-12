
# 整库审计终判报告 — BehavioralAISubstrate / "Qinao" 电子脑
（~290k 行 Swift + 26 Rust crates；分支 decode-planner @ b3e920c46；合成自 21 份子审计）

> 说明：任务书称"20 份子审计",实到 **21 段**（多出的 `x-test-integrity` 为第 21 段,且其 F3 在输入中被**截断于句中**——本合成对该员只能覆盖 F1/F2/部分 F3）。合成员唯一亲自硬核验证的是 CRITICAL（见 §1）,其余按各员的 file:line 证据归并。

---

## §0 元结论（跨 20+ 员浮现的系统性主题——比任何单条更重要）

四条主线贯穿全库,每条都被≥3 名互不相关的审计员独立撞见,构成本基座真正的健康画像：

1. **注释撒谎（comment-vs-code gap）= 头号系统性耻辱。** 一个把"诚实/判决行不许说谎"写进宪法的项目,其代码注释却在多处断言代码并不维持的安全属性。已实锤：`registerWriterBatch` 注释称"NO await suspension points…serialize at mailbox"（x-concurrency,实则每条 claim 都 await）；账本 F2/F3 的"same values by construction / never partial"；hostkit F2 的 V2 "surfaces populatedSlotCount"（已不成立）；memory tracker "filter via LEFT JOIN"（全库无 LEFT JOIN）；`bas_wallclock_nanos` "INCLUDING sleep intervals"（用的是睡眠停走的钟）；`TrainingDataExporter` "Atomic rename"（实为 remove+move）；`MLXModelCatalog` "fail-close"（实则抛错）；policy MED-1 "two processes see consistent state"（DELETE-all+INSERT 互相整表覆盖）。审阅者会**信任**这些注释——文档性危害叠加真实缺陷。

2. **失效开放（fail-open）方向错误 = 头号安全模式缺陷。** 一个主权安全基座的默认方向应是 deny/quarantine,却在多个闸门 fail-open：`PolicyCore.decide` 未匹配即放行（H19）；`ForbiddenCandidateZoneGate` 空 releaseConditions 恒放行（orchestration MED-3）；`triage-full-suite.sh` 提取空→NO REGRESSION exit 0（H22）；`release_gate.py` nw_model 缺省 PASS（tools MED）；热字符串未识别→`.nominal` 凉机决策（x-arch MED-1）；KG/EvalRun/风险观察 SQLite 读损坏→空结果（M-c 群）。

3. **"上膛未击发"（loaded gun）= 主导风险形态。** 约 **11 条 HIGH 中有 7 条当前无生产调用方**（SPSCRing、ShadowTrial、usage-tracker tombstone、purpose-sessionID、masked-FA、zone-gate、大量 MLX 车道）。这是"基座先于宿主而建"的特征：文档**主动邀请**宿主接线（如 ch989"Feed projection back into next turn"、席位 sessionID"every decorator forwards it"）,接线之日即静默失效之日。在 ADR-014（opt-in→certified→default-on）宪法下,dormant 不等于安全。

4. **SQLite "损坏=空"不可区分 = 与"integrity outranks availability"宗旨的实质背离。** EventLog store 已做 P0 三件套加固（onSilentFailure+eventsOrThrow+busy_timeout）,但 KG/EvalRun/风险观察/票据生命周期/routed-event-log **一项都没抄**,损坏库与全新用户不可区分,replay/回归/审计静默空转。

---

## §1 CRITICAL（1 条,合成员亲自核验 CONFIRMED）

### C1 · 真实 HuggingFace token 已提交并**推送**到私有 GitHub 远端
- **命中员**：x-sovereignty #1
- **file:line**：`docs/Recovery/3a011899-…jsonl`（20 处,LFS）+ `docs/Recovery/FULL_CONVERSATION/04_2026-06-03_to_06-18_Mamba3-decode-distill.md`（1 处,普通 git 对象）
- **合成员核验（本轮亲跑,解决了会话起始 `?? docs/Recovery/` 快照与"已推送"声称之间的矛盾）**：
  - `git ls-files` 证实 docs/Recovery/ 现为**已跟踪**（10 文件）；起始快照是提交 `5f9202c5a` 落地**之前**拍的,已过期。
  - `git grep`（tracked working tree）在上述两文件命中 token 形状串。
  - 提交 `5f9202c5a`（"chore: track all previously-untracked files (operator order)"）**是 HEAD 的祖先** 且 **存在于 `origin/decode-planner`**,本地与 origin 同步无 ahead/behind → **token 确已推送到 `https://github.com/ChangGeng01/ProjectSix.git`**。
- **失败场景**：任何获该私有仓读权者（协作者、GitHub 侧泄露、未来转公开、克隆外流）即持操作员 HF 凭证,可其名义读/写 HF 资产。security.md 明文："暴露即轮换"。
- **修复 + 工作量**：① **立即**在 huggingface.co/settings/tokens **轮换该 token**（与仓库操作解耦,零删除风险,~10 分钟）；② 历史清洗（filter-repo/LFS purge）属删除类操作,按删除厌恶宪法**必须操作员亲自裁决**,不自动执行。合成员建议：轮换先行,历史清洗单独立项。
- **诚实边界**：私有仓 visibility=PRIVATE（缓解但不豁免）；未在线探测 token 有效性/scope（不该拿他人凭证试）。

---

## §2 HIGH（23 条,按主题归并；★=多员共命中）

> 每条附 file:line、失败场景一句话、修复方向、工作量级、生产可达性。严重度分歧处注明。

### A. MLX 解码车道 / 会话并发 / 内存（最密集,7 条；L2"嘴"的编排层是重灾区）

**★H1 [生产活跃] model-free 车道在 GDN/Qwen3.5 上抛错而非 fail-close** — mlx-adapter-core HIGH-1 **＋** mlx-decode HIGH-1（2 员）
`MLXOrganAdapter+Executor.swift:107-135`（`.promptLookup`/`.suffixLookup` 两臂无 do/catch）→ `BASPromptLookupDecoder.swift:53-55`（对 MambaCache 抛 `nonTrimmableCache`）。生产模型 Qwen3.5 + `.factual` greedy + 热 serious/critical（planner 移除 mtpSpec 转提名 model-free）→ **每一轮**符合条件请求整轮报错。与 mtpSpec 臂的 fail-close 教义不一致。**修**：两臂加 catch→`_plainDraft`（已含 GDN fallback）,或 capabilities 加 trimmableCache 位构造性拒绝。**~0.5 天**（含热重路由 fixture）。

**★H4 [生产活跃] 会话解码 2-slot 闸被"插队"击穿至 3 路 → jetsam** — mlx-adapter-core MED-5 **＋** x-concurrency HIGH-1（2 员,严重度分歧 MED/HIGH,取 HIGH）
`MLXOrganAdapter.swift:373-389`。release 先减计数再 resume 等待者,新到者在等待者 +1 前走快路径占槽 → active=3,每超 1 路 ≈+32MB（或 MTP +300MB）,8GB 设备 jetsam 余量仅 135MB。**修**：handoff——release 不减计数,直接把槽交给被唤醒 waiter；或 waiter 恢复后重走 while 检查。**~0.5 天**。

**H5 [生产活跃] `_completePendingSpill` 双写者竞态删除有效 spill → 会话 KV 静默全丢** — mlx-adapter-core HIGH-2
`MLXOrganAdapter.swift:1528-1535 + 1630-1647`。park(gen1) 写盘期间座位被 reclaim 再 re-park(gen2) 起第二任务；一个成功消费后另一个误判快照过期把有效副本 removeItem。pressure-ladder rung-1 放大。spill 是该会话 KV 唯一副本 → 下一 turn 上下文静默消失。**修**：每 key 单写者（in-flight task/writer token）。**~1 天**。

**H6 [2-slot 显式支持并发] draftMultiTurn 同 key 无 per-seat 串行化 → 并发同座位 turn 丢历史** — mlx-adapter-core HIGH-3
`MLXOrganAdapter.swift:1215-1366`。三表现同根：双 spill-restore 后写胜、fused-transcript 后写胜、warm 分支同 ChatSession 并发 respond（厂商未认证）。注释 M254"actor 隔离自然串行"在 streamBody/restore 的 await 间隙不成立。**修**：per-key in-flight 门（key→Task,后到者 await 前者）。**~1 天**。

**H7 [主权/隐私] 清除契约被在飞写者违反 → 已 clear 会话从磁盘/内存复活** — mlx-adapter-core HIGH-4
`MLXOrganAdapter.swift:1671-1680`（snapshotWarmSeats）vs `1729-1744`（clearSession）+ `1241`（fused 回写）。dream-loop 快照在飞期间 clearSession → 写完文件重现磁盘,下一 turn 复活已清除对话；正是"缝2"要防的泄露面。**修**：写后校验清除代际（座位仍在池且未 clear 才落盘/回写）。**~0.5 天**。

**H21 [dormant,文档邀请接线] purpose 入口无视 request.sessionID → 席位池静默绕过,历史丢失** — organ-eval HIGH-1
`MLXOrganAdapter+PromptLookup.swift:161-185` vs `MLXOrganAdapter.swift:1057-1058`。`draft(_:)` 有 sessionID→draftMultiTurn,`draft(_:purpose:)` 无 → 同一席位请求经两入口得 stateful vs stateless,**输出字节不同**（非延迟差是内容差）,无报错。决策表跨入口不闭合。**修**：purpose 重载也按 sessionID 路由 draftMultiTurn。**~0.5 天**。

**H_mlx（并附 MED 群 M-f/M-g）**：pressure-ladder 直穿档漏收 300MB（MED-6）、rung-2 decoder 被下一 MTP gen 撤销（MED-7）、冷启并发双建 decoder ~600MB（MED-8=mlx-decode LOW-2）、loadModel 无 in-flight 去重双下载（MED-9）、spill 不绑 model.id 换模型错恢复（MED-10）、rung-3 cacheLimit 256MB 单向棘轮（MED-11）、MTP maxSeq=2048 未强制致长上下文净负增速（mlx-decode MED-1）。这些独立看 MED,但叠加构成"2-slot 并发政策 × 未串行化的内存治理"的系统性脆弱面。

### B. GPU 内核正确性（2 条,均 dormant,parity fixture 本应抓到）

**H2 [masked 变体无生产调用者] masked FlashAttention 行首全 mask tile → NaN 中毒,整行静默输出 0** — metal #1
`BASFlashAttention.metal:254`。行首连续全 -INF tile → `alpha=exp(NaN)=NaN` → `l_new=NaN` 持续污染 → `if(l_i>0)` 对 NaN 为 false → 整行 0（正确应是对未 mask key 的注意力）。无 NaN 外泄纯静默错值。**修**：标准守卫 `alpha=(m_new==-INF)?0:exp(...)` + 加"行首 tile 全 mask"parity 样例。**~0.5 天**。

**H3 [探针/封存路径] `commit();await completed()` 挂死竞态存活于两处 GPU 路径** — metal #2
`BASPlasticityFold.swift:660-661`、`BASMambaSSMState.swift:615-616`。本库自己的修复注释（MPSGraphMatMul ch1034）已记载此形态在 iPhone Air 对微小 dispatch 确定性挂死,Mac 假绿；两处漏网。**修**：addCompletedHandler 先于 commit（照抄库内已有正确形态）。**~2 小时**。

### C. 记忆删除 / 事件溯源完整性（3 条；删除教义 vs 磁盘现实）

**H10 [长跑常态] Rust event log 100k 静默截断 → 事件溯源"复活"已删除/隔离原子** — memory-b F2
`Cargo/bas-l8-engine/src/event_log.rs:691-696`（LIMIT 100_000）→ `BASMemoryAtomReducer.swift:117-127`。固定 sessionID 累计 >100k 事件后,某原子的 removed/quarantined 事件落 seq>100k → 投影只读最旧 100k → 该原子以删除前 governed 状态**重现**。纯静默,无 partial 位。**修**：分页或对 removed/governanceChanged 全扫；加截断标志。**~1 天**（Rust+Swift+XCFramework 重建）。

**H11 [dormant,生产用内存 tracker] usage-tracker tombstone 跨重启失效 + 声称的 LEFT JOIN 不存在 → "被遗忘"记录复活** — memory-a F1
`BASMemoryUsageTracker.swift:245-249`（init 不回灌 tombstones）+ `+SQLCore.swift:227`（doc 谎称 LEFT JOIN,全库无）。SQLite 持久模式重启后 isTombstoned=false、allRecords 吐出、activeRecordCount 计入；purgeTombstoned 返回 0 却已 SQL 物删。**修**：reload 回灌 tombstones；读查询加真过滤；修 purge 计数。**~1 天**。

**H12 [第四条红腿,藏在"已实现物删"背后] purge 不清 notes 与 FTS → "物理删除"后内容仍全文可搜** — memory-a F2
`+ReplayAuditFTS.swift:660-685, 746-772`（purge 事务只 DELETE records+tombstones）。宿主常把 atom 内容摘录放 notes → `searchNotesFTS` 仍命中已清除记录、磁盘原文可读。比已知三条红腿更隐蔽。**修**：purge 事务同删 notes+FTS 行；给探针加 (d) 腿。**~0.5 天**。

### D. 主权账本 append-only 真实性（2 条；信任锚自身可断/可截）

**H13 账本 append 持久化失败后内存链与盘链分叉,无回滚** — sovereign HIGH-1
`BASSovereignAuditLedger.swift:532-557`。persist 抛错（磁盘满/BUSY）后内存 entries 已 append 不回滚 → 下次 append 的 priorHash 指向"盘上不存在的前驱",冷启 reload 检出 priorHashBroken → 单次瞬时磁盘打嗝把持久账本变砖。**修**：persist 抛错时回滚内存 append（entry/index/entryCount）。**~0.5 天**。

**H14 盘链尾截断在 reload 时不可检出；entryCount/tailHash 有数据却未接线交叉核对** — sovereign HIGH-2
`BASSovereignAuditLedger.swift:333-379`。有盘写权攻击者删尾部 K 行,剩余前缀内部自洽 → auditChainFull 通过 → 照常接受新 append。高水位数据（Σ entryCount、tailHash）已持久化却零交叉核对。**修**：reload 断言 entries.count==Σ segment.entryCount 且开放段 tailHash 一致,否则 quarantine。**~1 天**。
（注：sovereign 员自陈 Contradiction/Unknown 两个 P2 邻近 append-only store **完全没读**,可能含同类分叉/截断——建议下一轮优先补审。）

### E. 并发不变量 / 内存安全（4 条）

**H8 Single-Writer-Per-Domain 不变量可被 await 窗口打穿 + 注释撒谎** — x-concurrency HIGH-2
`BASSharedStateGraph.swift:204-230`（registerWriter）、`262-319`（registerWriterBatch,注释虚假声称已消灭部分安装竞态）。两 agent 并发注册同 domain 都过校验、都 await upsert、last-wins → A 自认拥有实为 B 的。ch956.11 修了崩溃一致性却引入校验→提交重入窗。**修**：validate+占位内存 map 收进无挂起段,再异步持久化+失败回滚；修正假注释。**~1 天**。

**★H9 [dormant,L13 执行本体] ShadowTrialCoordinator 部分提交 + 并发 check-then-act → 晋升门 fail-open,账本/内存分叉** — memory-b F1 **＋** x-concurrency HIGH-3（2 员）
`ShadowTrialCoordinator.swift:247-307`（submit 双开试验,账本永久双记）、`431-435/474/507`（finalize trial 落终态后 seal/retraction append 失败→撤回令永久丢失）、`589-641`（advanceOpenTrial 丢观察+账实分叉）。promotionVerdict 空证据→allowsPromotion=true（F8）。头注"never partial"不成立。**修**：乐观并发（提交前重读复核）+ per-trial in-flight + ledger 失败回滚 maps。**~1.5 天**。

**★H15 [dormant,test-only 调用] BASSPSCRing 文档承诺的 POD 运行时检查不存在 → 非 POD 元素 UAF/堆损坏** — runtimecore-b #1 **＋** x-concurrency LOW-11（2 员,严重度分歧 HIGH/LOW,取 HIGH-latent）
`BASSPSCRing.swift:61-73`（init 只查 capacity/stride,`_isPOD` 从未调,`.nonPODElement` 永不抛）。`BASSPSCRing<String>` 可构造,push memcpy 不 retain,pop 悬垂 → UAF。公共泛型 API 脚枪。**修**：一行 `guard _isPOD(Element.self) else { throw .nonPODElement }`。**~0.5 小时**。

**★H17 Dictionary(uniqueKeysWithValues:) 遇重复键即 trap（整回合/整进程崩溃）** — orchestration HIGH-2 **＋** memory-b F9（2 员,7+ 站点）
`EBrainNeuralMaterializationCore.swift:140/285/558/559/612/777`、`CognitionKernelCore.swift:132`、`SemanticCompilerCore.swift:311`、`BASAgentMergeApplier.swift:77-78`（每回合 Phase C）。回放/宿主构造 frame 中同 candidateID 两条 forecast,或两 delta 同 deltaID → trap 杀常驻主权进程。**修**：`Dictionary(_:uniquingKeysWith:)` + 记 duplicate outcome。**~0.5 天**（全站点）。

### F. 失效开放闸门 / 取消传播（3 条）

**★H18 [生产活跃] 裁决/流式 decorator 无取消联动 → 取消后 LLM 解码/网络泵继续跑完** — hostkit-rest HIGH-1 **＋** policy-obs-misc MED-3（2 员,3 文件）
`BASAdjudicatingOrganAdapter.swift:111-134`、`BASSemanticAdjudicatingOrganAdapter.swift:209-247`（LLM 解码,HIGH）、`BASChatCompletionsOrganAdapter+Streaming.swift:41-67`（网络泵,MED）。AsyncThrowingStream 内非结构化 Task 无 `onTermination`。用户点"停止"→ 内层 MLX 逐 token 跑到底,白烧电池/热,与下轮争 GPU；chat loop 显式探测 BASStreamingOrganAdapter,命中率=每次流式取消。**修**：`continuation.onTermination = { task.cancel() }`。**~0.5 天**（3 站点）。

**H19 [public 宿主接线面+5 官方 preset] PolicyCore.decide 默认 fail-open → localOnly/childSafe 档形同虚设** — policy-obs-misc HIGH-1
`PolicyCore.swift:137-144`。未匹配规则时仅 cloudRequested&&riskLevel≥medium 才 confirm,否则 `.allow`。localOnly 只有 route/output 两规则 → 低风险云端 toolCall/memoryWrite 放行；childSafe 无 output 规则 → 任意敏感度输出放行。**修**：默认分支 fail-closed（无匹配且 cloudRequested 一律拦）。**~0.5 天**。

### G. 测试 / CI / 自证完整性（3 条；对"最严谨"叙事的直接反证）

**H20 [无人值守夜窗核心失效] 睡眠站超时只杀直接子进程 → 挂死的测试宿主整夜存活** — organ-eval HIGH-2
`BASSleepMeasurementStation.swift:173-186`。`swift test` spawn 的孙进程（真挂死的 xctest 二进制）不在进程组管理下继续满载；pipe 写端不关泄漏线程；站继续跑下一 suite → 违反"一次只跑一个重活"铁律（该机曾因此冻结重启）。**修**：setsid 起进程组后 `kill(-pgid,SIGKILL)`,或超时停整站。**~0.5 天**。

**H22 [RSI 机器裁决器自身漏底] triage-full-suite.sh fail-open → 真回归洗成 exit 0** — tools-scripts HIGH
`scripts/triage-full-suite.sh:50-53, 90-95`。TOTAL_FAILS>0 时套件提取正则要求纯字母模块名 `\[[A-Za-z]+\.`；含数字/下划线的 target（本库命名习惯,如 BASKit2.FooTests）失败行不匹配 → SUITES 空 → REGRESSIONS 空 → 打印"NO NEW REGRESSION"exit 0。**修**：步骤 2 后加守卫 `TOTAL_FAILS>0 && SUITES 空 → UNGROUNDED exit 1`。**~1 小时**。

**★H23 [QINAO"100 指标"自证是剧场] verdict 链缺已提交的 merge 步 + 硬编码/可注入 CRITICAL 门 + eval 指纹从不复核** — x-test-integrity F1+F2+F3（＋ tools-scripts release_gate MED）
`build_verdict.py:10-11`（只读 `/tmp/qinao_values_<tag>.json`,无 merge 器落 bench/rag/code）；`#89 audit_traceability=100`（CRITICAL,PASS）**在全 git 历史找不到任何写入者**——可徒手编 `/tmp` JSON 注入且与真算不可区分（已发生一次）；`qinao_eval.py:118-120` 硬编码 `V[83]=0/V[88]=100/V[92]=100` 走 PASS 通道,`release_gate.py:114-116` 声称 contamination 必须"genuinely COMPUTED"却读的正是那行硬编码 0 → 循环论证；F3 data_fp_match 只重验 2 训练文件,4 个 EVAL 集指纹从不复核。**修**：实现已承诺的 merge 步；删所有硬编码 PASS 字面量；复核 eval 集指纹；缺行/截断一律 fail-closed。**~2-3 天(立项)**。

---

## §3 MED 高价值群（~55 条原始 → 16 主题,只列代表 file:line 与共命中）

- **M-a 删除教义 vs 物理字节**：memory-a F4（全 9 个 SQLite store 无 secure_delete/VACUUM,"真 DELETE"内容留空闲页/-wal,取证可恢复）＋ x-sov #5（`BASSQLiteMemoryAtomStore.swift:167` 记忆原子库——最高敏感落盘点——无显式 Data Protection,与"缝2"给 KV 快照设保护形成同库双标）＋ x-sov #6（KV 保护 try? 吞错+写后补设窗）。**修方向**：open 后 `PRAGMA secure_delete=ON` 或删后 wal_checkpoint(TRUNCATE)；高敏原子升 .complete。
- **M-b 隔离逃逸**：memory-a F3（隔离 atom embedding 仍在向量索引/规范 RAG,带全文回 L2）＋ hostkit-rest MED-2（ZoneGate 承诺记审计实则丢弃 gate 决策+无条件返回 .proposed）＋ MED-3（promote 口 approveForDistillation 无 zone 检查,隔离候选进蒸馏队列——"私有经验不进权重"护栏失守）。
- **M-c SQLite 读 fail-open**：runtimecore-b #3（KG/EvalRun）、policy-obs-misc MED-2/LOW-2（风险观察 event_id ms 碰撞静默丢+损坏当空）、policy-obs-misc MED-1（票据生命周期 persistQuietly 吞错+DELETE-all/INSERT 跨进程互覆——重启后已拒/已蒸馏票据复活,擦到 L13 不变量#3；此条严重度可争议为 HIGH,因无生产调用方确认列 MED）、memory-b F12。
- **M-d 主权账本/钥匙**：sovereign MED-3（append-floor 数值 rank vs canonicalBytes 精确串分派不一致,放行 >1.2.0 非单射编码,重开碰撞面）、MED-4（routed Stage-3 证据升级无 Swift 地板交叉核对,信任 Rust derive；rust 员确认 derive CLEAN 故为纵深缺口非活漏洞）、**★MED-5=x-sov #2**（`BASSovereignKeychainBinding.swift:136-143` Ed25519 种子无 kSecAttrAccessible…ThisDeviceOnly,经加密备份迁他机——per-device 签名身份破,2 员共命中）、MED-6（revokeAllTokens 忽略 sessionID 吊销全会话）。
- **M-e 热信号**：runtimecore-a #1（wallclock 睡眠语义反,睡后陈旧 attestation 当新鲜,HIGH-dormant）、#2（memory_pressure 用 free 页比,健康设备 isUnderPressure 恒真）、#3（HazardPredictor 无占空下限,外因热跳变毒化 learnedBudget 进持久层跨运行存活）、#4（bas_thermal_probe sysctl 键 Darwin 不存在恒 -1）＋ **x-arch MED-1**（`BASThermalLevel` vs `BASThermalBucket` 双表示无转换器,`BASDeviceProfile.thermalState` 裸 String 子串匹配,未识别→.nominal 且已有生产者塞 "low_power"/environmentClass → 过热设备按凉机决策,热闸 fail-open）。热是跨员热点,mostly dormant 但方向危险。
- **M-f/M-g MLX 内存治理 + 解码仪器**：见 §2-A 附群 + mlx-decode MED-2（packed 读回错位,BAS_TR_PROBE+trace 同活时熵通道读到 token id,B3 早退失义）、MED-3（B2 难度探针把生成上限抬到宿主 maxOutputTokens 之上 ~2.4×,违契约）。
- **★M-h 睡眠固化/dream-loop 空心**：hostkit-rest MED-4 ＋ memory-b F6（隔离写耗尽窗口跳过 ledger mark → postChainHash==preChainHash,链哈希防篡改判据失义）＋ F7（makeObservation 用全新空 tracker+atomTiers={[:]},checkpoint 恒零变更,与真实语料无关；操作员若读作"无需隔离"结论结构性空洞）。2 员共命中。
- **M-i DeviceTestApp 仪器自坏**（测量装置本身产假判决,对"靠设备数据活"的项目致命）：MED-1（liveness 对慢而健康解码打 wedge 签名→外部看门狗误杀整夜健康跑）、MED-4（RdarProbe.runM4 烧机 deadline 被无条件覆盖→满电平台期跑无效 M4）、MED-5（M3/M4 对同 fused 资产用不同 state 行宽默认→默认参数下链路探针自坏）、MED-6（M1 崩溃定位 print 走全缓冲 stdout,崩溃吞掉 STEP 行）、MED-7（M1 两臂 typed 失败仍打"SURVIVED—runnable"——判决行撒谎,违诚实教义）、MED-8（GPU 心跳 ~21min 后 command buffer 配额耗尽静默冻结→判别实验读数污染）、MED-9（runSustained 每代重建 decoder 自加热放大热漂移→假阴性）、MED-2（runSamplingVerify 裸 30s Task.sleep=锁屏冻结坑）、MED-3（endurance 每迭代全表加载 durable 库,跨重启单调增长污染测量）。
- **M-k HostKit 脊柱审计保真**：hostkit-spine F1（BASTurnRuntimeEngine actor 可重入,跨 turn 审计归属串号,sessionID 与 payload 不一致）、F2（.nativeV2 默认下静默丢弃 caller 的 auditProjections/permitEscalationLedger,doc 承诺不成立）、F3（escalation 改 mode 到 .block 的 turn 上 gate 侧 vs audit 侧"逐字节相同"契约为假,红线 8 误判）、F4（进化工件 ID 秒级碰撞跨 turn 同 ID 不同工件,retraction 撤错候选）、F5（hasActiveLease 默认 .now 挂钟读在 byte-equal 重放值路径,潜伏）。审计车道但 L14 审计保真是一等契约。
- **M-l 并发/边界杂项**：x-concurrency MED-4（`BASRoutedVectorIndexStorage.swift:619` L8 全局召回 sync 读 vs 写并发,rowid 复用→错原子召回,release 无 tripwire,且与 H4 的并发回合政策直接冲突）、MED-6（`BASOrganTrainedWeightProvenance.swift:452` 生产路径临时翻转进程级 useRoutedFilter 旗标,跨线程行为串扰+数据竞争）、**★MED-8=hostkit-rest MED-6**（`BASHostStorageWireBuilder.swift:132` 事件溯源 store 初始种子 fire-and-forget,首回合先于播种完成,replay-determinism 受伤,2 员共命中）、MED-9（biomimetic GPU 器官 applyGPU/selectiveScanGPU 跨 await 丢更新）、metal #3（Codable 反序列化绕过 byteCount precondition→堆越界读；零维 shape 强解包崩溃）、metal #4（MPSGraph executable 缓存键不含烤进图的 epsilon,跨实例共享→错数值）、orchestration MED-1（precondition 对 caller 输入=可喂崩）/MED-4（recordEvent sink 抛错使成功/失败不可区分→重试产不可去重重复审计）。
- **★M-p breath 调度器**：policy-obs-misc LOW-5 ＋ x-concurrency MED-7（`BASBreathScheduler.swift:106/134` cancelAll（热应急）逐 id await 期间并发 schedule 完成 register→removeAll 抹字典但平台注册仍活→热应急后幽灵维护唤醒。2 员共命中,取 MED）。
- **M-j Tools/eval 估计器**：fit_difficulty_probe.py AUC 无并列校正（两条预注册基线 fam_auc/len_auc 偏移 ±0.05-0.1,而"probe 打赢控制线"正是立项判据；同目录 eval_probe_ood.py 已有正确实现,统一即修）、release_gate.py nw_model 缺省 PASS/parse_substrate 截断误判、qinao_bench_zh.py 按学科静默丢数据致 base/tuned 题集不可比、B2 候选权重 JSON 裸 NaN（Swift JSONDecoder 集成时爆炸）、R2/R3 冻结语料+sha 只在 /tmp（重启即摧毁 R4 冻结条款,建议入 Docs/evidence/）。
- **M-n Rust 二进制漂移**：`BASRustMemoryTracker.xcframework`（06-11 重建）不含 06-14 canonicalize_weight() -0.0 修复,KG codec 上生产前必须重建 XCFramework（当前生产可达性零）。
- **M-o 架构**：x-arch MED-2（`AdminCore.swift:866` SwiftUI View 在 substrate-core 模块 BASAdmin,门禁看不见,headless 宿主被迫链 SwiftUI）、MED-3（`BASSovereignLedgerHostSink.swift:42` 裸 `import Crypto` 靠 vendored 传递,Package.swift 未声明,vendor 刷新即断编译）。
- **M-p vendor/主权门**：x-sov #3（`check_vendor_remote_leak.sh` 当前 **FAIL**,4 处未冻结 vendor 二级依赖=唯一未冻结供应链输入面）、#4（`check_sovereign_redaction.sh` 在 Xcode-beta 编译失败,主权 redaction 门**不产判定**）。

---

## §4 子系统健康分（A–F + 一句话诊断）

| 子系统 | 分 | 一句话诊断 |
|---|---|---|
| **Rust（26 crates）** | **A-** | FFI/所有权/panic/canonical-bytes 跨语言平价全经得起严苛审计,唯一账是未回灌的 XCFramework（零生产可达）——**全库骄傲**。 |
| **BASHostKit 脊柱** | **B+** | raise-only 裁决 + byte-equal 重放是模型级工艺,瑕疵全在审计投影可重入/归属串号（皆 MED/LOW）。 |
| **BASOrchestration** | **B** | 并发无懈可击（全 actor 隔离,零 Task/锁/重入）,唯 guardPaths 语义反转坐在仲裁正中央 + Dictionary trap。 |
| **BASMetalSubstrate** | **B** | 调度/缓存/同步中枢 CLEAN,两条 dormant HIGH（masked-FA NaN、GPU 挂死）是 parity fixture 本应抓到的漏网。 |
| **BASSovereign** | **B-** | 双钥/令牌/canonical-bytes 是皇冠明珠,但信任锚自身（审计账本）可分叉、可尾截断且不可检出——**明珠与裂缝并存**；跨设备 CRDT 完全未审。 |
| **BASRuntimeCore** | **B-** | EventLog store P0 加固扎实,但 C 热/内存压力探针"死而带病"（坏+误导文档）,SPSCRing 上膛未击发。 |
| **BASOrgan+Evaluation** | **B-** | 解码 planner 决策表全枚举 CLEAN,eval 台账诚实度有洞（AB fidelity 可旁路）+ 看门狗留僵尸。 |
| **BASHostKit 非脊柱** | **B-** | FSM 合法性 CLEAN,流式 decorator 取消缺失（生产活跃）+ zone-gate 审计承诺落空。 |
| **BASPolicy/Obs/Lease/WorldPrior/RustBridge/Chat** | **B-** | RustCoreBridge FFI 所有权 CLEAN,债在 ticket 持久化+流式取消+quiet-hours 公式+风险观察未接线。 |
| **BASMemory** | **C+** | 删除宪法有物理字节洞（无 secure_delete、notes/FTS 挺过"物删"）+ 重启复活路径——多为 dormant 但**与教义正面冲突**。 |
| **BASMLXAdapter** | **C+** | ADR-039 无损解码内核是验证过的骄傲,会话池/spill/压力梯子编排层是自设 2-slot 政策下的并发雷区。 |
| **DeviceTestApp** | **C+** | 测量装置本身有判决腐蚀级 bug（假 wedge、自加热、崩溃吞 stdout、"SURVIVED"撒谎）——对靠设备数据活的项目是软肋。 |
| **Tests/** | **B** | skip 纪律 + XCTExpectFailure 留红示众堪称教科书,~300 运行期永真"proof" + 10% iOS 源门收缩设备绿宇宙是覆盖剧场。 |
| **Tools/scripts** | **C+** | 构建/清除/runpod 脚本扎实,CI 回归裁决器有 fail-open 通路 + eval 估计器并列误估。 |
| **QINAO 指标门** | **C-** | "100 指标"自证可被徒手注入/硬编码,一个 CRITICAL 门（#89）在 git 历史无写入者——**自我认证是剧场**。 |
| **横切安全姿态** | **C** | 零遥测/零 analytics/env 注入密钥是真主权,被一枚已推送的 HF token + 死/失败的主权门拖到 C。 |

---

## §5 整库总判决：这个 29 万行基座配不配"最严谨"？

**判决：配得上"最有雄心",尚配不上"最严谨";它是一座工艺极高、但地基有几处未封的宫殿。**

**骄傲（真金,经得起本轮 20+ 员严苛互审）**：
- Rust 侧 26 crate 的 FFI/所有权/panic/canonical-bytes 跨语言平价——A 级,近乎无懈。
- ADR-039 无损解码（发射=主干 argmax）——逐发射点核实 CLEAN,含 Leviathan 拒绝采样数学。
- 主权双钥/令牌单次性/ActionDigest/canonical length-prefixed——纵深防御到位,最被反复审过的面。
- 脊柱 raise-only 裁决 + byte-equal 重放 canonicalizer——确定性工艺。
- 测试 skip 纪律带日期/复活条件、XCTExpectFailure 把架构缺口"留红示众"——诚实度高于典型大库。
- **审计文化本身**：代码携带自己的修复章节注释（ch1044/复审修）、自指诚实（M824"no tautology"pin,即便别处违反）、SPSCRing 一员判 LOW 另一员判 HIGH 的分歧被如实并列——这套自我怀疑的机制是这个库最真的资产。

**耻辱（与它自封的宪法正面冲突处）**：
- **一枚活 HF token 推到 GitHub**（C1,已核实在 origin/decode-planner）——单条最严重,直接违反"暴露即轮换"。
- **删除写进宪法,磁盘却留字节**：无 secure_delete/VACUUM,"物理删除"后 notes/FTS 全文可搜（H12）,tombstone 重启复活（H11）——教义与磁盘现实的实质落差。
- **信任锚可断可截**：审计账本单次磁盘打嗝即分叉变砖（H13）、尾截断不可检出（H14）——防篡改承诺对最基本的攻击有空头支票。
- **自证是剧场**：QINAO"100 指标"门可徒手注入,CRITICAL #89 无 git 写入者,triage 裁决器 fail-open（H22/H23）——一个把"grounded 判决/判决行不许说谎"当纲的项目,其自我认证链恰恰不 grounded。
- **注释撒谎**（§0 主线 1）：多处安全属性由注释断言而代码不维持——对诚实教义的最系统性背离。
- **L2 编排层并发雷区**:MLX 会话池在自设 2-slot 并发政策下有 4+ 条 HIGH 竞态（H4-H7）。

**一句话**：Rust 半区与解码内核证明这个团队**能**做到最严谨;账本裂缝、删除物理洞、QINAO 剧场、和那枚 token 证明它**尚未把最严谨贯彻到每一条它自己写下的宪法条款**。距"最严谨"不是能力差距,是**收口差距**——大量 loaded-gun 在 default-on 之前未走完自己的失败模式。

---

## §6 修复分级

**立即（今日,阻断发布/安全,多为小时级）**
1. **轮换 HF token**（C1,~10min,与 git 手术解耦）。
2. 一行/小时级 HIGH：SPSCRing POD 守卫（H15,0.5h）、Dictionary uniquingKeysWith 全站点（H17,0.5d）、masked-FA NaN 守卫（H2,0.5d）、triage 脚本 fail-closed 守卫（H22,1h）、metal commit/await 顺序（H3,2h）。
3. `PolicyCore.decide` 默认 fail-closed（H19,0.5d）——public preset 语义承诺。
4. 修 `check_vendor_remote_leak` FAIL + 让 `check_sovereign_redaction` 产出判定（x-sov #3/#4）——恢复两道死/失败的主权门。

**本周（并发串行化 + 完整性,天级）**
5. 主权账本回滚 + 尾截断交叉核对（H13+H14,1.5d）。
6. MLX 并发四修：slot handoff（H4）、spill 单写者（H5）、draftMultiTurn per-seat 门（H6）、clear 代际校验（H7）——~3 天,建议同一 PR 引入统一的 per-key in-flight 门原语。
7. 流式 decorator onTermination 取消（H18,3 站点,0.5d)。
8. SharedStateGraph validate+claim 无挂起段 + 修假注释（H8,1d）。
9. 记忆删除：tombstone reload（H11）+ purge 清 notes/FTS（H12,共 1.5d）；同时 open 后 secure_delete（M-a,0.5d）。
10. 睡眠站进程组 kill（H20,0.5d）；DeviceTestApp 判决撒谎修正（MED-7,把 SURVIVED 与实际 step 数绑定,0.5d）。
11. purpose 入口 sessionID 路由（H21,0.5d）。

**立项（结构性,需专案 + 操作员裁决）**
12. **QINAO/eval 门重接地**（H23）— **DONE(2026-07-08,TDD 17 门+双轮 Opus 对抗审查)**。
    ①硬编码 PASS 删除:#88/#92/#89 是部署架构事实模型 eval 无法验证→按 registry 身份
    (ATTEST_ONLY_CRITICAL,不看值不可伪造)恒路由 ATTEST;#83 contamination 改真算
    (contamination.py 泄漏检查,数据缺→None→PENDING fail-closed)。②F1 merge/注入:_prov
    provenance 侧信道,CRITICAL 值无 kind=="computed" 出处→ATTEST。③F3 指纹:FINGERPRINT_KEYMAP
    扩到 4 eval 集(train 必需/eval present-verify)。④缺行/截断 fail-closed(_load_values
    非零退出)。**★第一轮 Opus 对抗审查抓 4 真缺陷全修**:(a)model_eval_ok 漏 verifiable-ATTEST
    (注入 fixture 曾 model_eval_ok=True crit_pass=0)→加 v_attest_blocking 阻断;(b)_prov 明文可伪造
    →诚实降 docstring(防意外/懒注入非防蓄意伪造者;release_ok_model 按门身份是不可伪造后盾);
    (c)contamination 读不了真 train(chat messages schema)=对生产 no-op→加 messages 解析+短问
    子串回退;(d)release_ok_model 恒 False 且 release_gate 只读它=永久红无解锁路→outer gate 改读
    model_eval_ok(可过)+ attestations_pending 作显式 DEFERRED 行。诚实边界:门是本地开发装置非
    生产信任边界,防"自证剧场"(硬编码/一次真发生过的 /tmp 注入)非防恶意内鬼。
13. **ShadowTrial 乐观并发 + ledger 回滚**（H9）— **DONE(2026-07-08,TDD 6 门+5 员 Opus 对抗审查零缺陷)**。
    四病:F1 submit check-then-act 跨 `await ledger.append`→并发双开+账本永久双记;F2 advanceOpenTrial
    并发 observe 读同 record 后写胜→丢观察+账实分叉;F3 finalize 落终态**在** seal/retraction append **之前**
    提交→后者失败则试验已终态但撤回令(failed/blocked 的安全机制)永久丢(头注"never partial"撒谎);
    F8 promotionVerdict 空证据→allowsPromotion=true(缺席即通过 fail-open)。**修**:①**per-candidate
    in-flight 门**(续体交接,复用梯次3 认证原语,内嵌于 coordinator actor 自身执行器=更强)——
    submit/observe/reportFail/finalize 皆 acquireCandidate(key)+锁下重读(乐观复核);②finalize 重构
    =**建全部条目→append 全部→再原子提交所有内存 map**(任一 append 失败零内存变更,试验留 pending);
    ③promotionVerdict 要 hasPassedTrial && hasApprovedSeal(fail-closed);④修两处撒谎注释。**★对抗审查
    5/5 零缺陷 high**(无死锁/无残留 check-then-act/finalize 原子/F8 零破坏调用者/主权桥 byte-equal 保);
    诚实边界:append-only ledger 不可回滚,seal-fail 后重试会双 append trial_finalized+烧 seal ID(已文档化
    权衡,胜过旧的静默丢撤回令);续体无取消处理=与认证基座原语同性质非本修引入。现有 34 ShadowTrial 测零回归。
14. **Rust event log 100k 截断分页**（H10）— **DONE(2026-07-08,Rust TDD+XCFramework 双冷重建 byte-equal+Swift 分页+Opus 审查)**。
    病:`events_for_session_json` LIMIT MAX_HOTPATH_LIMIT(100k)只读最旧 10 万事件→固定 sessionID 超 10 万后,
    某原子的 removed/quarantined 落 seq>100k 被静默丢→投影以删前 governed 态**复活**已删原子(删除教义/主权违规)。
    **修**:①Rust `events_for_session_page_json(after_seq,limit)` 游标分页(seq>after_seq ASC,limit 夹 [1,100000])
    + FFI `bas_l8_event_log_events_for_session_page`(两段式尺寸探测)+ C 头声明(force_link 靠既有
    bas_l8_engine_abi_version 锚+codegen-units=1 整体链接自动保留同 crate 符号,nm 已验)。②Swift
    `eventsArrayViaJsonFfi` 会话路改**游标循环**(afterSeq=-1 起,进到 last.sequenceNumber,页<10000 止)——读全史
    有界分配,任何 late 治理事件都不漏。③cargo TDD(游标读全尾+排他+越界空+夹紧,110 crate 测零回归);
    ④XCFramework **两次冷重建 byte-identical**(macos slice run1==run2 复现性铁律满足)→3 SHA pin(源常量+测字面各 3)更新。
    Swift 分页测(pageSize=2 强制多页,late 事件必在+升序无重)+70 event-log 回归绿。**★Opus 4 员对抗审查抓真缺陷
    (2 员汇聚,已修)**:Swift 循环终止条件 `page.count < pageSize` 是 **fail-OPEN**——`fetchSessionPage` 对任何错误
    (FFI 负码 / 一行 decode 失败)都返 `[]`,循环把"错误页"当"流末"→静默截断尾部→**经错误路径重新引入 H10 复活**。
    修:`fetchSessionPage` 返 `[BASEventLogEntry]?`(nil=读错,[]=真空页,靠 needed≥2/written≥2 区分);循环仅在**真空页**
    终止(短非空页续读一次,修 DEFECT2 空 payload 早停)、读错→整读 **fail-CLOSED 到空**(空投影不复活任何原子,partial 会)。
    审查确认核心(复活已治愈+升序+FFI/ABI 安全+复现性 pin)全稳;acc 数组随会话增长的 OOM 迁移是留册权衡(流式 fold 是更优未来项)。★权衡(诚实):旧代码"错但有界"
    (丢事件避 OOM)→新"对但随会话增长"(投影需全事件才正确;单次 Rust String 分配仍每页有界 10k,消除巨串 OOM;
    Swift acc 数组随会话规模增长是正确投影的固有代价,>100k 会话曾给错答案)。SOURCE_DATE_EPOCH=git 提交时;
    pin 取自提交前重建,提交后同源码同 SDE 重建应 byte-identical。
15. **热表示统一**（x-arch MED-1）— **DONE(2026-07-08,TDD 8 门)**。★根因比审计更深:`thermalState:
    String` 被两生产者喂**非热数据**——`AppleInspectionBridgeCore:202` 塞 `environmentClass.rawValue`
    ({simulator,lowPower,memoryConstrained,normal})、`AppleAdaptiveRuntimeAdapterCore:227` 塞
    `"low_power"/"nominal"` 电源旗标——全不含 "serious"/"critical",故消费者 `RuntimeCore:414` 的
    子串匹配对生产路径**是死码,永远 fail-open**;且 `BASThermalLevel` 的 "hot"(热义=serious)也
    从不匹配。**修**(不破 Codable schema):`BASThermalBucket.severity` 单调序 + `thermalSeverity(from:)`
    规范解析(认 Bucket+Level+Darwin 三词表)+ `BASThermalLevel_Bridge` 显式互转 + `BASThermalClassification`
    三分类(thermal/nonThermalNominal/unrecognized)。消费者改按分类路由:识别热词按真严重度(修 "hot"
    不降级)、已知非热生产串→nominal(不误降级保正常)、**真未识别→fail-CLOSED(serious)+ 大声记 rationale**。
    RuntimeCore 124 测零回归。**残留**:生产者把非热数据塞 thermalState 的范畴错误(应喂真 ProcessInfo
    热态)是更深的生产者侧修,留册待专案;本修让消费者对该错误 fail-loud 而非静默 fail-open。
16. **删除教义收口** — **secure_delete DONE(2026-07-08,TDD 取证 4 门)**。共享助手
    `BASSQLiteSecureDelete`(BASRuntimeCore,默认开+kill-switch `BAS_SECURE_DELETE=0`)在 open 时
    紧随 `journal_mode=WAL` 打 `PRAGMA secure_delete=ON`,已接线**全部 18 个磁盘 store**
    (12 单行 runExec 形 + 4 多行形 + BASRiskObservations sqlite3_exec 形 + BASUpdateTicket
    execute 形;第 19 个 BASChapterDoctrineSQLLoader 是 `:memory:` 无盘无删故豁免,已注记。
    审计原估"9 store"是低计)。**★TDD 取证验证**:
    写入独特秘串→DELETE→wal_checkpoint(TRUNCATE)→扫 db+`-wal`+`-shm` 原始字节,secure_delete=ON
    下秘串**物理消失**;pragma 读回 =1 证真开非 no-op(teeth 不靠平台默认差异);kill-switch 双态套件皆绿
    (默认 4/4,OFF 2 过 2 skip)。存储回归 275+ 零回归。**残留(留册)**:①VACUUM/auto_vacuum
    对**已部署旧库的历史空闲页**(secure_delete 前的删除留下的未清零页)是一次性迁移,非每次 open 跑
    (VACUUM 全库重写代价高)——secure_delete 只清此后的删除;②x-sov #5(atom 库 Data Protection
    class)+ #6(KV try? 吞错)是同族但独立项,未在本收口内。
17. token 历史清洗（filter-repo/LFS purge）——**删除类,必须操作员亲自裁决**。
18. **测试诚实度** — **DONE(2026-07-08,共享 helper 带 teeth + 2 轮 Workflow 扇出 + 单次验证构建)**。
    ①**assertCodable 自比较**:~76 文件各自的 `assertCodable<T:Codable>(_:T.Type){ XCTAssertEqual(String(describing:type),
    String(describing:type)) }` = x==x 恒真,只有编译期 `T:Codable` 约束做事,Codable 真坏也"过"。**修**:
    共享 `BASCodableRoundTripSupport`(encode→decode→**再 encode 字节比对**,`.sortedKeys` 确定性,不需 Equatable)
    + 反向 teeth 测试(故意坏的 asymmetric Codable 必被抓,3/3)。276 站点升级:CaseIterable 枚举走
    `assertCodableRoundTripsAllCases`(全 case),其余构真实例走 `assertCodableRoundTrips(instance)`;17 个深嵌类型
    用**诚实**的 `assertConformsToCodableAtCompileTime`(不再撒谎,显式标注为编译期-only 残债)。336 测零失败=覆盖的
    Codable 全真无坏。②**print-only 22 条**(审计估 9,实为 22):behavioral(testVeryShortManipulationStillBlocks
    →断 `.block`;ColdStart 难度盲/Novelty 赢 →断名字声称的行为)+ **跨实现一致性 oracle**(Rust vs Swift、int8 vs
    f32 逐元素等价=真正确性锚,非仅 perf)+ 非退化界;5 条纯人读 scorecard 用 BAS_PERF_PRINT=1 门控。③**B2 /tmp**:
    3 个 testWalkR*FromJudgement 读+改 ambient /tmp/gdn_coreai 状态(非 hermetic)→ BAS_B2_LOOP=1 门控,默认套件不碰 /tmp。
    ★方法:先造带 teeth 的共享 helper(防"用新恒真替旧恒真")+ 单文件模板验证 → 才扇出;扇出只改不构(构建是串行资源)→
    单次验证构建 + 迭代修(仅 1 处漏 import)。★发现:agreement-oracle(同量两算比对)是 perf 测的最强真锚。
19. **KG codec 上生产前重建 XCFramework**（M-n）— **DONE(2026-07-08,重建由 #14 承载 + 端到端验证 + 回归 pin)**。
    M-n = 纯二进制漂移:06-14 `canonicalize_weight()` 把 -0.0→+0.0 的修在 Rust 源里,但发船的
    `BASRustMemoryTracker.xcframework` 是 06-11 build(先于修)→该修**生产可达性零**(canonical-bytes 重放
    等价被破:-0.0 符号位存活令同权重编码不一致)。★**关键**:#14 的 XCFramework 双冷重建(07-08,commit
    d92aeeffc)编译的是**当前全源**,已把 06-14 修(及自 06-11 起的一切源漂移)带入发船二进制——M-n 的重建
    已由 #14 顺带完成,无需再建(再建 byte-identical,复现性已验)。#19 做**端到端验证 + 回归 pin**:新增
    2 个 Swift FFI 测(BASChapter744)——经 FFI 打进现committed 二进制,断 **-0.0 与 +0.0 编码字节相同**
    (旧二进制会因 -0.0 符号位存活而不同 → 测会红)+ 任意 NaN payload 归一到一个 quiet NaN,双双通过=修在发船
    二进制里 live。cargo codec 测 44 绿 + AutoRouteRanker 套 132 绿。★教训:二进制漂移类审计项(源已修但发船
    二进制陈旧)的正确闭环 = 重建(可由邻近项顺带)+ **经 FFI 打进committed 二进制的端到端 pin**(源级测抓不到
    漂移;唯有走真二进制的测能钉),否则"生产可达性零"会静默复发。
20. **补审下一轮**（本轮结构性盲区,见 §7）：跨设备 CRDT/gossip 主权真实性、Contradiction/Unknown 两个 P2 账本 store、Rust↔Swift 状态机迁移等价性、L3-L14 投影/协议业务逻辑层、test↔production 对应完整性。

---

## §7 覆盖率自白汇总（诚实保留：审计了多少,没覆盖多少）

**本合成的边界**：合成员只对 §1 CRITICAL 亲自跑了 git 核验（token 确在 origin/decode-planner）；其余 22 条 HIGH/所有 MED/LOW 均**未独立复验**,基于各员 file:line。第 21 员（x-test-integrity）在输入中**截断于 F3 句中**,故 QINAO 门的完整发现本合成只覆盖 F1/F2/部分 F3。

**深读密度（各员逐行全读的中枢/安全关键文件,合计约 120+ 文件)**：脊柱 EBrainRuntimeCoordinator 全簇+RunTurn 2211 行+SovereignCommit 1759 行；BASSovereignAuditLedger 1468 行 + 令牌/双钥/canonical 全套；BASSQLiteEventLogStorage 1375 行；MLXOrganAdapter 1920 行 + 解码内核 BASQwen35MTPSpecDecoder 715+FusedChain 495；BASMemoryUsageTracker 6 扩展 ~2900 行；ShadowTrialCoordinator 773；BASOrchestration 17 文件全读；Rust substrate-core/c-abi/canonical-bytes/atom-lifecycle 全读；Metal 23 dispatcher+5 shader；DeviceTestApp EnduranceRunner 3502 行；六小模块 53/53 文件 100%。

**已系统全量扫描(工具化,非逐读)**：@unchecked Sendable 生产 182 处/nonisolated(unsafe) 82 处/195 个 actor 重入启发式/锁跨 await（0 命中）；1629 测试文件 skip/断言密度/永真断言 census；2891 public 类型全 repo 零引用 census；22 模块全 import 边界；全库 fatalError/try!/as!/baseAddress! 计数；26 crate unsafe/no_mangle/from_raw nm 符号核对；全树 secrets/telemetry/网络原语模式扫。

**结构性盲区（本轮审计整体未覆盖,任何结论不担保)**：
1. **跨设备 CRDT/gossip 主权真实性**——sovereign 员明确"完全没碰"7 个 gossip 策略 + CrossDeviceClock/LedgerFrame。这是"多主机账本真实性"轴,**整轴未审**。
2. **Rust↔Swift 状态机迁移等价性**——memory-b 明确未复核 bas-shadow-trial crate 与 Swift 迁移的等价性。
3. **L3-L14 投影/协议业务逻辑层**——orchestration ~60 文件（Kunlun/Cthulhu/Abyssal/Tribunal projections、AbyssalProtocol 1182 行、L6 SituationField 967 行）、hostkit ~240 文件（CognitiveBrain 全簇、EBrainHostRuntime services、投影工厂群）仅 grep 级并发/危险模式保证,**业务逻辑（阈值/投影正确性）未审**——这是"电子脑"的裁决/记忆/编排器官本体。
4. **Rust 9 个 SQL 移植文件正文 + ~13 crate 业务逻辑**——rust 员只做 FFI 校验比例扫描 + 计数图,vector_index/version_tree/host_constitution_vault/dream-loop/tribunal-court 等**正文逻辑未读**。
5. **RuntimeCore ~150 Doctrine 字面量文件 + BASAutoRouteRanker 主体及 12 扩展**——runtimecore-b 仅 pattern 级横扫。
6. **test↔production 对应完整性**——tests-arch 明确：**哪些生产模块无测试从未计算**；QINAO 指标 NAMES vs 实现的接线（memory 记忆："1598 测试文件存在,metric names not yet wired"）未核。
7. **Contradiction/Unknown 两个 P2 账本 store**——sovereign 员点名"可能含与 HIGH-1/2 同类持久化分叉/截断",未读。
8. **Tests/ 内 539 处 @unchecked Sendable**——x-concurrency 明确未审,测试内竞态会假绿/假红。
9. **~30 个 DeviceTestApp CoreAI/ANE/LiteRT 探针 + ~45-70 个 Tools 转换脚本正文**——仅 grep 扫。
10. **MLX Tree/CoreML/CoreAI/Saguaro 解码车道 + LoRATrainer + ModelCatalog**——多为探针/已关闭 honest-negative 车道,未逐行。

**实证核验（各员非纸面）**：本机 sysctl 证实 hw.thermal_state 不存在、vm_stat 证实 free≈4.4%→pressure≈95、surprise(∞)=NaN；nm 确认 XCFramework 未含 KG -0.0 修复；4 道仓库自有主权门实跑（redaction FAIL/vendor-leak FAIL/choke-point PASS/mlx-redaction PASS）；合成员本轮 git 核验 token 在 origin/decode-planner。

**一句话覆盖率**：本审计深读了信任锚、解码内核、Rust FFI、脊柱裁决这些**安全关键中枢**,并对并发/密钥/边界做了工具化全量普查;但对**跨设备主权、L3-L14 器官业务逻辑、Rust 业务正文、test↔prod 对应**这四大面只有 grep 级或零覆盖——**"最严谨"这四个字,本轮只兑现在了骨架与皮肤,尚未深入到这颗电子脑的大部分脏器**。

---
# 附:20 员子审计原始报告索引
各员全文存 evidence（非入 git 的大文本存 ~/bas_evidence_durable/megaaudit/）。合成见正文。
覆盖率自白已并入正文 §7。全量回归腿(并行):NO NEW REGRESSION。

## 合成后即时更正(2026-07-07 夜,操作员在场核对)

- **C1(HF token)= CLOSED**:操作员已轮换该 token(失效);仓库两文件就地打码
  (dd4ecf556,内容编辑非删除),`git grep` 验证 0 残留;历史清洗(重删类)留操作员裁,
  死 token 无害不强推。★流程教训入册:追踪大不透明语料(会话转录)前必须先扫 secrets。
- **H22(triage fail-open)= 已在本周复审修复**(审计员基于旧快照):scripts/triage-full-suite.sh:23-27
  无聚合行 = UNGROUNDED exit 1,:67 mktemp 失败 fail-closed,三路退出码已自验。此条降级为
  非活。
- 全量回归腿(并行,同夜):**NO NEW REGRESSION**(今日全部改动 + 3 已知 pre-existing 正确分类)。
- 立即层其余(masked-FA NaN 守卫 H2 / metal commit-await 序 H3 / SPSCRing H15 / Dictionary
  H17 / PolicyCore fail-closed H19 / 两道主权门 x-sov#3#4):**待操作员调度**——多数需设备
  parity 复验或触及并发原语,不在无验证的夜间盲改窗口内(纪律:改状态前证据须支持该具体动作)。

## 本周层修复进度(2026-07-07 夜,操作员"本周层修复开工 最严苛")

**梯次1 信任锚 — DONE(commit,TDD 5/5)**:H13 主权账本 persist 失败原子回滚(内存==盘,
消除幽灵尾致冷启永久 quarantine)、H14 reload 用 Σsegment.entryCount 对账 entries.count
抓尾截断(数据本已持久仅未接线)、MED-5 签名种子 ThisDeviceOnly(阻断备份迁机)。
双存储测试替身(flaky-once / tail-truncating)证回滚与对账。

**梯次2 删除教义 — DONE(commit,TDD 4/4)**:H11 tombstone 跨重启回灌 + 读查询真过滤
(消除"被遗忘记录复活";假称的 LEFT JOIN 从未存在)、H12 purge 事务同删 notes+FTS
(第四红腿:"物删"后内容仍全文可搜)+ 时间 GC 同修。清除探针加 (d) 腿标记 CLOSED。
memory tracker byte-eq 套件零回归。

**梯次3 MLX 并发 — 接线+双设备认证 DONE,门默认开(2026-07-08)**:
H4-H7 根因同一 = 会话池缺 per-key 串行化。地基 = 经验证共同原语
`BASPerKeyInFlightGate`(per-key FIFO 续体交接锁:同 key 严格串行/不同 key 并发/FIFO/
抛错释放,20 并发零交错单测证)。接线三修:① H6 draftMultiTurn 临界区逐字抽取为
`_draftMultiTurnLocked` 后裹 `sessionGate.serialize(key:)`(抽取期默认关字节等价,
会话/路由/spill 回归全绿证);② H5 `spillWriterActive` 单写者集合替代 `!hadPending`
双生成竞态(park 仅在无写者时孵化 completer,三出口原子清除);③ H7
`keyClearEpoch`/`clearAllEpoch` 代际:snapshotWarmSeats 写后校验 epoch 变则丢弃、
fused writeback 同守卫、clear 双双提升(消 clear-vs-写回复活)。
**设备认证(两台两腿)**:endurance 5E5C 门开 71 轮召回 13/13、67 spill/67 restore
零丢失(380s,无 watchdog);并发同座位 9E9E 两并发 turn+双召回两码词都在历史
(H6 失败场景直接证伪,BASSessionGateConcurrencyDeviceTests)。**ADR-014 收口:
门默认开,kill-switch `BAS_SESSION_GATE=0`(默认路径回字节等价直调)**;Mac 全套
回归门开下绿(hygiene 5/5 + 门 4/4 + 会话池 55)。
**④ H4 2-slot 信号量 handoff — DONE(2026-07-08,TDD+对抗审查+设备认证)**:
RED 实测比审计更糟——旧代码错峰竞争下峰值 **14**(审计估 3;每个 release→resume
窗口都放进插队者,击穿复利)。修 = 与门原语同款交接语义:release 有 waiter 不减计数
直接交槽(FIFO 头继承),acquire 快路径加 `waiters.isEmpty` 守卫。Mac gates 3/3×5
(压力峰值≤2 / FIFO 不可越队 / 排空计数守恒)。**6 员对抗审查零缺陷**(deadlock/
cap-breach/starvation/error-paths/telemetry/composition,全 high confidence,含
逐 actor-切片不变量归纳证明:waiters≠∅⇒active==cap;交接窗口 C 高估占用=只欠不超)。
设备认证 9E9E:8 座位错峰突发 `peak=2 completed=8/8`(闸用满未击穿)。
残留注记(审查发现,非缺陷):stateless `_generateMTPSpec` 车道按文档化范围不受闸
(一次性车道保历史并发形貌)——混合负载可超 2 路重解码,是既有 scoping 决定,留册。
**梯次3 至此全部收口(H4+H5+H6+H7)。**

**立即层四件 — DONE(2026-07-08,TDD+双模型对抗审查+回归)**:
- **H2 masked-FA NaN 守卫**:TDD RED(N=40/B_C=32 行首全 mask tile → 整行静默输出 0,
  25 断言全炸)→ 内核 `alpha=(m_new==-INFINITY)?0:exp(m_i-m_new)`(行首全 mask 时
  l_i=O_i=0,0-rescale 是恒等)→ GREEN 13/13 FA parity。仅 masked 内核可达 m_new=-INF
  (unmasked 首 tile 必有实分、causal 必纳 j≤i),守卫作用域正确。
- **H3 metal commit/await 序**:PlasticityFold+MambaSSMState 两处
  `commit();await completed()` → handler-before-commit 续体(照抄 KernelLibraryLoader
  正典形态,同错误类型/reason,fault 仍阻 readback)。全仓已无残留该形态。GPU 套 44+12 绿。
- **H19 PolicyCore fail-closed**:TDD RED(3/4)→ 未匹配+云请求一律 deny、本地维持 allow
  (sovereign-local 缺省);childSafe 补 output 规则(高敏 deny/中险确认)→ GREEN。
  零生产调用者(scaffold-vs-wired 既有缺口,本修不改)。**回归抓 2 处黄金值镜像**:
  BASQINAOSubstrateGatesBatch2 的 oracle(自证镜像 decide())+ BASImprovementCandidate
  的 P2 注册表门(BAS_SESSION_GATE 毕业默认开须同 commit 入册——梯次3 遗漏,此处补登)。
- **主权门③ vendor-leak 复活**:EventSource(async-http-client)/swift-huggingface(swift-xet)
  的远程二级依赖移入 `BAS_VENDOR_ALLOW_REMOTE=1` env-gate(trait 默认关+零消费者=
  consequence-free,对抗审查证 canImport/#if 全守)。**★对抗审查抓真缺陷(Opus,
  high)**:LiteRT-LM 起初也被 env-gate 变 inert,但 DeviceTest.xcodeproj 无条件链
  `LiteRTLM` product(BASLiteRTE4BProbe 设备研究)→ env 未设时 Xcode 解析找不到 product
  →DeviceTestApp 编译失败,被纯 SPM 回归完全掩盖。**修**:LiteRT 清单还原(校验和锁定
  binaryTarget,"二级依赖被换"风险不适用),gate 加显式 allowlist(脚本自身 option (b));
  `xcodebuild -resolvePackageDependencies` 证 `LiteRTLM @ local` 解析通。**★留待操作员:
  探针 doc 自称"NOT added by default"却与 pbxproj 无条件链矛盾——按删除铁律不擅自拆线,
  上报待裁。**
- **主权门④ redaction 复活**:根因 = QinaoSample/ContentView `@ViewBuilder` 内联
  `if #available` 令 Xcode-beta 合成 `TupleContent<repeat each Content>:View`(仅 OS26 有)
  →`dump-symbol-graph` 编译失败→门不产判定。**修**:分支路由经返回 `AnyView` 的非
  ViewBuilder 函数(类型擦除绕过合成)——门可编 AND 保住 macOS14-25 legacy showcase
  (首版曾误升 floor 到 OS26 致 showcase 退化,对抗审查点出过声,已纠为窄修)。
  + 7 个 QinaoSampleHost bench 文件 public→package(消 16 处 BAS* 泄漏;executable
  内消费,零外部导入)。门 clean 跨 25 模块。**双模型对抗审查:Fable5 6 员因额度中断
  (非发现缺陷)→ Opus 6 员重跑,5/6 零缺陷 high + 1 真缺陷(LiteRT,已修)+ 1 low
  过声(ContentView,已纠)。triage 全套 NO NEW REGRESSION。**

---

## §8 修复终账(2026-07-08 "全部都要" 收口)

审计的 1 CRITICAL + 23 HIGH 里,**全部可修项已闭**(剩 #17 token 历史清洗=删除类,操作员亲裁;4 盲区补审=方向抉择)。逐条:

**CRITICAL**:C1(HF token)当晚轮换+就地打码,已闭(见 §1 / commit dd4ecf556)。

**HIGH(23)** — 13 条经"本周层 / 立即层 / 项目层"梯次先闭(H2/H3/H4/H5/H6/H7/H9/H10/H11/H12/H13/H14/H19/H23,见上文各条目 + 主权门③④复活),剩 8 条 open HIGH 于 07-08 "全部都要" 一并闭,**每条 TDD teeth + 对抗反转验证(禁用守卫→测须红)+ 独立 commit + push**:

| 编号 | 病灶 | 修 | commit |
|---|---|---|---|
| **H22** | triage-full-suite.sh fail-open(纯字母模块名正则 + 空聚合洗成 exit 0) | 正则纳数字/下划线 + `TOTAL_FAILS>0 && SUITES 空 → UNGROUNDED exit 1` | 3d08989ef |
| **H17** | Dictionary(uniqueKeysWithValues:) 遇重复键 trap 杀常驻进程 | uniquingKeysWith 全 25 站点/16 文件 | 5940afce1 |
| **H1** | prompt/suffix-lookup 车道无 do/catch,GDN/Qwen3.5 抛 nonTrimmableCache 逃逸 | 两臂 fail-close 到 _plainDraft(镜像 .mtpSpec) | 48eb7d8c4 |
| **H18** | 流式 decorator 无 onTermination,取消后 LLM 解码/网络泵跑完 | **审计采样 3 → 实为 7 站点/6 文件**;onTermination + checkCancellation;teeth=挂死 mock 经 BASCountingOrganAdapter | 8a5e5d17b |
| **H15** | BASSPSCRing 文档承诺的 `_isPOD` runtime 检查不存在→非 POD UAF | **强于审计**:`Element: BitwiseCopyable` 编译期约束(`<String>` 变不可编译) | 5b07895c3 |
| **H21** | draft(_:purpose:) 无视 request.sessionID→席位池静默绕过,历史丢失 | 补 request.sessionID→draftMultiTurn 路由(决策表跨入口闭合,字节等价现有调用方) | afbbcc93e |
| **H8** | 单写者不变量被 validate→await→commit 窗打穿 + registerWriterBatch"NO await"撒谎注释 | **审计采样 2 → 实为 3 站点**(writeObject auto-claim 补);validate→**同步预留内存**→persist+回滚;修撒谎注释;teeth=**真挂起 storage**(ch996.9 只用 nil storage 从不挂起=洗白竞态) | a45f7354a |
| **H20** | 睡眠站超时只杀直接子进程→挂死孙 xctest 存活 + 站起下一套件→pile-on 冻机 | 进程组 SIGKILL(setpgid + kill(-pgid),killTargetForTimeout 自保绝不杀本站组)+ **超时停整站** | 2e2483e05 |

★方法教训:(a)**审计采样的病灶类常更广**——H18 3→7、H8 2→3,修时必扫全 class,不止修被点名的行;(b)**竞态 teeth 必须用真挂起替身**逼出重入窗口(nil/即返替身洗白竞态,正是 ch996.9 旧测的盲点);(c)危险操作(kill/pgid)抽纯函数单测自保逻辑,不 spawn 真重活(违一次一重活铁律);(d)每修都对抗反转才算有牙。134 测跨 8 域零回归。

## §9 MED 收口(2026-07-09 "全面继续修复 audit 相关")

CRITICAL + HIGH 全闭后转 MED。**全部 mac 纯(无 Rust/设备)的 fix-now MED 已闭**,每条 TDD teeth + 对抗反转 + 独立 commit + push:

| 主题 | 病灶 | 修 | commit |
|---|---|---|---|
| **M-h F6** | 睡眠固化 ⑥ ledger-mark 在 pipeline 内,窗口耗尽 break 跳过它→store 变但 preChainHash==postChainHash(篡改证据不变量破) | ⑥ 移出窗口预算,`didMutate` 恒锚链;teeth=③变异后窗口耗尽仍 pre≠post | 3c7bba0e3 |
| **M-e #2/#3** | ①memory_pressure 用 `total-free`(inactive 可回收缓存当占用)→健康机 isUnderPressure 恒真;②HazardPredictor 无占空下限→外因热跳变毒化持久 learnedBudget | ①拆纯 `bas_memory_pressure_percent_from`=active+wired(600k-cache 机 90%→30%);②`minAttributableDutyFraction=0.25` 归因下限(8×外因尖峰不动 budget) | 5f36be54a |
| **M-o MED-3** | 87 安全关键 `import Crypto`(Ed25519/SHA)靠 ML vendored 传递,root+10 target 均未声明→vendor 刷新即断编译 | root `.package(swift-crypto)`(同路径同 identity,字节等价)+ 10 target 声明 product;swift-crypto 升为 indent-0 直接依赖 | dfb37327b |
| **M-g/M-i** | ①fused readback PACK/UNPACK 双可选块反序(trProbe∥traceActive 同开时熵/topk 互相污染)②B2 探针预算 `max(8,probe)` 无上限可越 maxTokens | ①UNPACK 镜像 PACK(trProbe 先,补 `cursor+=kNow`)+ `cursor==host.count` 断言;②纯 `clampedProbeBudget=min(maxTokens,max(8,probe))` | 2c1fdf437 |
| **M-i/M1** | RdarProbe 两 placement 全 typed-fail 仍印 "✅ SURVIVED direction runnable"(上膛报中靶) | runOnce→Bool,仅 ≥1 真完成才印绿,否则诚实 ⚠️(设备 app,查验+设备门) | dd3736ed2 |
| **M-l MED-8** | 事件溯源 atom store 用 `Task.detached` 播种→makeAtomStore 即返未播种 store,即读竞态见空 | makeAtomStore→`async`,inline await 播种;teeth=即读两 atom(反转 detached 版 5/5 红) | ca07528c3 |
| **M-j AUC/NaN** | fit_difficulty_probe/b2_refit AUC 无并列校正(基线并列分 ±0.05-0.1 偏移,正是立项判据)+ b2 候选 JSON 裸 NaN(Swift JSONDecoder 爆) | 共享 `_auc.py` 并列平均 rank;heldout_auc→null + `allow_nan=False`;teeth=全并列 0.5(旧 0.0)+50 例对 scipy.rankdata | 870052374 |
| **M-j gate** | release_gate never_worse `nw_model=True` 缺省(回归行缺→零证据放行)+ parse_substrate 取末行(截断日志误判) | `regression_gate_status` fail-closed(缺席=红)+ parse 取 max-executed 行;teeth 8 例(反转缺省 True 红 3/3) | 3485393d6 |
| **M-j zh** | qinao_bench_zh 按学科 `except:pass` 静默丢→base/tuned 题集不可比 | 记录 loaded/dropped 学科入结果 JSON(题集漂移可检) | 04a68f638 |
| **M-o MED-2** | SwiftUI BASConsoleView 在 substrate-core BASAdmin,headless 宿主(BASBrainCLI/BASJournalCLI)被迫传递链 SwiftUI | 拆 `BASAdminUI` target(view+typealias 迁入),BASAdmin/BASHostKit 净 SwiftUI;teeth=源树扫描守卫(含正控) | f7b93ccb2 |
| **M-k F1** | BASTurnRuntimeEngine 可重入 actor:runWithPlan 跨 await 写共享 lastDispatchLedger/lastAssignmentLedger,两 routed emit helper 读它建 payload 而 sessionID 取本地 result→并发 turn 覆写共享→审计事件 sessionID(A)配 payload(B) | ledger-locality:每 turn 账本抽本地,值传入两 emit helper(不再读共享);teeth=非空 param 账本驱动发射而共享仍 .empty(反转共享读→guard 跳过红)+canonical60 .nativeV2 平价+并发 liveness 绿 | e0639494e |
| **M-k F1 串行化** | (F1 休眠残留)`last*` accessor 跨 turn 陈旧——只有整轮串行化能修;引擎可重入,并发 turn 交错 | 整轮 in-flight gate(BASPerKeyInFlightGate 迁 BASMLXAdapter→**BASRuntimeCore** git mv,避 MLX 入 headless=承 M-o MED-2);两入口(runTurn/runWithPlan)同键 serialize+抽 ungated _core(nativeV2→_runWithPlanCore 免双取自锁死);kill-switch BAS_TURN_SERIAL(默认开;生产 fresh-engine/单流不竞=字节等价)入 BASConfigRegistry;**adversarial workflow 定案**(死锁/test/coverage/killswitch 4-lens);teeth=闸日志逼交错窗:ON grouped(A,A,B,B)/OFF interleaved(A,B,B,A);30 测绿 | f42d034c8 |

★4-lens 背景 workflow 定案(A serialize vs B ledger-locality):**seq 连续性不重要**(引擎 counter 仅 per-turn start<complete 提示;日志真排序键=存储 MAX+1 per session)+ **accessor 零 in-repo 读者(休眠)**⇒ 唯一活 bug=emit payload 串扰⇒选 B(正范围、字节等价、保并发、不越界入"整轮串行化"这一独立并发决策)。

| **M-l MED-4** | BASRoutedVectorIndexStorage.cosineTopKAtomIDsSync topK(→rowids)+ K 次 rowid→atom_id 分离 FFI=多调用 TOCTOU:并发写间插→SQLite rowid 复用重映到别的原子(错召回)/丢(静默漏);release 无 tripwire | Rust 新 `cosine_topk_atom_ids_for_domain`:同一 with_conn Mutex 内直读 atom_id(无 rowid 往返=无复用窗)+全序(score DESC, atom_id ASC)亦闭并列成员确定性;Swift 单原子调用;删孤儿 atomIDForRowidSync;XCFramework 3 slice 冷×2 byte-identical(rustup 1.96)+3 SHA pin+测字面更;2 cargo 测+并列成员 teeth 过真二进制 | 5c2d2a365 |

## §10 架构 3 条收口(2026-07-09,操作员"架构 3 条也修了";workflow 定案后逐条实现)

3-analyst workflow 定案:全部 `doctrine-decided`(非真取舍/非阻塞)、全 mac 纯。逐条:

| 项 | 病灶 | 修(遵教义) | commit |
|---|---|---|---|
| **M-e #4** | bas_thermal_probe 注释谎称"读 Darwin 热态 sysctl",实则 hw.thermal_state 键不存在→恒 -1;零生产调用者(真热态=ProcessInfo.thermalState via BASSystemProbe) | 删假 sysctl 舞蹈=诚实故意 unsupported stub 恒 -1;修 .c/头/BASSystemProbe 三处撒谎注释(非删除,git-mv 移除属操作员裁);teeth=probe 返 <0 且 out!=0(未来假成功映 nominal=热设备 fail-open 则红) | 259b85288 |
| **memory-b F12** | BASRoutedEventLogStorage 读路径 negative-FFI/decode-fail 一律返 []→损坏与真空不可分(reducer 投影全空=假失忆),无错误通道 | 镜像 SQLite 姊妹 BASSQLiteEventLogStorage:抽 throwing core(各塌陷点 throw readFailed;真空仍 [])+`onSilentFailure` 钩+`eventsOrThrow` 兄弟;totalCount 负数亦经钩;纯 Swift 无 Rust 重建;teeth=二连接 DROP TABLE(WAL)→events()=[]且钩触发+eventsOrThrow 抛 | ec620b4db |
| **memory-a F3** | 隔离(.quarantined,可逆)atom 的 embedding 留索引→cosineTopK 出其 id→RAG 规范 atomLookup `{id in atom(forID:)}` 无治理过滤→隔离内容回 L2(前台路径已滤 .governed,RAG facade opt-in=规范例有洞非生产漏) | `governedAtomLookup(resolve:adapt:)`:lookup 边界滤(Stage-4 出 BASMemoryAtom 无治理字段,只能在此滤);非 .governed→nil→staleAtomIDs 不入 L2;embedding 不删(可逆隔离保);换掉泄漏文档例;teeth=.governed 入/.quarantined 入 stale+释放后复召回(embedding 未删)+naive 泄漏对照 | e8ac5e4b0 |

★架构-3 教训:(a)"架构"分类≠真取舍——多是"修法涉设计决定",有教义(可逆隔离/前台 .governed 滤/comment-honesty)即有可辩护正解;(b)**in-repo 姊妹先例是金**(F12 照抄 BASSQLiteEventLogStorage 的 onSilentFailure+OrThrow 加性无协议改);(c)**治理滤须在类型仍带治理位的边界**(BASMemoryAtom 已擦治理→事后滤不能);(d)删除类(M-e #4 真移除)仍守 consult-before-deleting=非破坏诚实 stub 先行,git-mv 留操作员。

★MED 教训:(a)**fail-open 缺省是 MED 最常见形**(never_worse=True、isUnderPressure 用错分母、AUC 并列偏、SURVIVED 恒印)——修=fail-closed 缺省 + 缺席即红;(b)**纯函数抽取换 teeth**:GPU/模型/设备内联逻辑(pressure 比、probe budget、AUC)抽纯函数才可确定性单测;(c)**竞态 teeth 可靠红**:M-l detached 播种反转 5/5 红(非 flaky——detached 确定性输给即返);(d)**模块图卫生**用源树扫描守卫(SwiftUI-free)+ 正控防误抽。

**诚实账——未闭项(须真机/操作员域)**:
- ~~**device-gated 5+2**(含 x-sov #5/#6 Data Protection)~~ → **§11 收口**。⚠️修正:原注"macOS `.protectionKey` 不支持"**不准**——经验证 macOS **存储且读回** `.protectionKey`(设 `.complete` 读回 `.complete`;仅 `.none` 被地板回默认),只是 at-rest **加密**惰性(macOS 用 FileVault)。故代码路径 mac 可测,只有"锁屏前不可读"须真机。
- **b2 /tmp→Docs/evidence 冻结**——实验 I/O 布局,操作员域(改默认路径可能断上游管线)。
- **M-e #4 / device-gated 的完全删除项**(如 bas_thermal_probe 整函数 git-mv 移除、x-arch MED-1 生产者范畴错误)——删除类/真机验须操作员亲裁。

**★ 架构 3 条闭合后:mega-audit 的 1 CRITICAL + 23 HIGH + 全部 MED(fix-now/xcframework/architecture)全闭。** 剩仅 device-gated(真机)+ b2-evidence(操作员实验域)两类,皆非"不惊动操作员、不用硬件可安全自主"的项。

> ⚠️ **2026-07-09 更正(见 §12):此"全部 MED 全闭"是 THEME-级过声。** 逐项(per-item)复核发现 37 条 MED-级发现从未被任何 remediation commit / §8-§11 账本行个别追踪——被主题级聚合闭合掩盖。此行的"全闭"只在"每个主题至少动过一次"意义上成立,非"每条 MED 已闭"。真实态见 §12。

## §11 device-gated 收口(2026-07-09,操作员"device-gated 5+2 也修了")

先清点:x-sov #2(Ed25519 `…ThisDeviceOnly`)、M-h dream-loop H7 守卫、M-i/M1 SURVIVED 谎(MED-7)三项**盘查发现已闭**(分别 line 142-144 / 既有 inline / commit dd3736ed2)。余下逐条实现:

| 项 | 病灶 | 修 | teeth(诚实等级) | commit |
|---|---|---|---|---|
| **x-sov #5** | 记忆原子库(最高敏落盘点,payload_json 含 `sensitivity` 列)无 file Data Protection,与"缝2"KV 快照同库双标 | 新 `BASSQLiteFileProtection`(BASRuntimeCore):DB+`-wal`/`-shm` 钉 `completeUntilFirstUserAuthentication`,DEFAULT-ON+kill-switch `BAS_FILE_PROTECTION=0`,**返错不吞**;atom store open 后(WAL+seed 后 sidecar 已在)apply,经 `fileProtectionError` 面 | **mac 可判**(反转earned):裸"读回 X"是 FALSE-GREEN(macOS 新文件默认已 cUFUA)→改**预设 `.complete` 证 helper 翻转**;反转跳 setAttributes→2 断言红。at-rest 锁屏前不可读=真机 | 6c600c0c1 |
| **x-sov #6** | SessionPersist KV 保护 `try?` 吞 setAttributes 错 + 写后补设窗 | 路由到共享 helper(同类+kill-switch+sidecar);错经 `_sessionProtectionFailureHook` **surface**(去 `#if os(iOS)` 令 mac 可测) | 同上(helper teeth 共用) | 6c600c0c1 |
| **M-i MED-2** | `runSamplingVerify` 两裸 `Task.sleep(30s)` 臂间冷却=锁屏冻结坑(devicectl app 锁屏挂起→夜跑搁浅) | 共享 `idleGuardedSleep`(BASProbeCommon)认同 endurance 同款 `BAS_COOLDOWN_SPIN=1`:同步 ~1 e-core 转,GPU 仍凉;关则退 Task.sleep | **iOS-SDK 编译验**(BUILD SUCCEEDED);冻结行为真机 | cebea725a |
| **M-i MED-4** | runM4 100% 平台期烧机 deadline(waitUnplug 设 20min 帽)被随后**无条件**覆盖回 12min 窗→平台期>12min(iOS 持"100%"~10-20min)令 M4 半烧结束=无效空测 | 两臂 `if !burning { deadline=… }` 保烧机帽;burn-in-complete 路(读数首跌)才重启计数窗 | 同上(编译验;能量/token 测须真机) | cebea725a |
| **M-i MED-6** | M1 崩溃定位 `STEP n…` 行走 `print`/stdout=devicectl 下块缓冲→硬崩吞掉缓冲行(定位锚失) | M1 入口 `setvbuf(stderr,_IONBF)` 一次 + STEP 行 `fputs` 到无缓冲 stderr→崩前即达 console | 同上(编译验;崩溃存活须真机 rdar 触发) | cebea725a |

★device-gated 教训:(a)**"不支持"须验非假设**——`.protectionKey` mac 经验证是"存储但惰性"非"不支持",纠正 §10 line 481 原注(=项目本身叙事漂移抗性);(b)**FALSE-GREEN 反转必做**——x-sov readback 首版 macOS 默认值令测恒绿(改与 not-fixed 无别),反转揪出→改预设 `.complete` 证翻转才有牙;(c)**device-gated ≠ 完全不可验**——分层:代码路径(helper 翻转/编译)mac 可判,只 at-rest/锁屏/崩溃存活须真机;诚实标注哪层验了;(d)**统一 knob**:`BAS_COOLDOWN_SPIN` 一钮护 endurance+探针全部冷却,非各处重造。

**★ device-gated 收口后:mega-audit 全部非删除、非纯实验域项闭合。** 余:①x-sov #5/#6 at-rest 锁屏前不可读 + M-i MED-2/4/6 真机运行时行为(代码路径已 mac 验/iOS 编译验,仅硬件行为待操作员真机跑);②b2 /tmp→Docs/evidence 冻结(实验域);③完全删除项(bas_thermal_probe git-mv 等,consult-before-deleting 须操作员亲裁);④#17 token 历史清除(operator-gated)。皆须操作员/硬件,无可"安全自主"项剩。

## §12 MED 逐项(55/55)对账 + 主题级"全闭"过声更正(2026-07-09,操作员"完成剩余部分")

操作员指出闭合是 THEME-级(16 主题)非 ITEM-级,可能掩盖被折进"已闭主题"的漏项。6-agent 逐项扫全 22 个 evidence 文件(`~/bas_evidence_durable/megaaudit/`)+ 交叉 §8-§11 账本 + git log。**全表 artifact:[Docs/evidence/MED_55_ITEM_ACCOUNTING_2026-07-09.json](evidence/MED_55_ITEM_ACCOUNTING_2026-07-09.json)。**

**对账结果(94 逐项 hit = MED + F-编号发现 + 少量 LOW):49 closed + 4 folded(进 HIGH)+ 4 tracked-open + 37 UNACCOUNTED。** ⚠️**37 条"未入账"= 追不到任何 remediation commit / §8-§11 账本行 / §11 line-501 残留表——被"全部 MED 全闭"聚合掩盖的真漏项。** 主题级"44 验/40 开"与逐项不可数字对齐(94 vs ~55 vs 84-加总),但实质:**"40 开"低估真未闭群(4 tracked + 37 untracked = 41),且把 37 条真漏项当作被主题聚合吸收——它们没有。** 整簇掉落:mlx-adapter-core MED-6..11(M-f 主题无闭合行)、organ-eval 全 5 条(只在 §4 健康分特征化,从未 themed)、runtimecore-b 4 条。

**抽验校准(反 FALSE-GREEN,防 agent 反向假阳)**:抽 3 条核实——organ-eval MED-1(BASSleepMeasurementStation `outData` 数据竞态)= **真**(BASEvaluation,mac 可修);devicetestapp MED-3(每迭代载全库)= **真**;mlx-adapter-core MED-6(pressure-ladder)= **灰**(子系统被非-audit commit 统一案5 重做,但无 audit 闭合行)。⇒ 37 大体可靠,含少数"灰"(区域被非-审计提交顺带重构)。

**37 条未入账(按可修性分组;完整描述见 artifact)**:
- **Mac-可修(~20,非 device-gated)**:organ-eval MED-1(outData 竞态,**本轮已修见下**)/ MED-2/3/4/5(AB 判据/验证管道)· memory-a F5 · memory-b F4/F5/F7 · runtimecore-b MED-2(prune 重置 seq 碰撞)/MED-4(7×fatalError 打包失败)/MED-5(v2 解码 fail-open)/MED-6(BASPQIndex 无同步)· orchestration MED-2(Rust FFI OOB precondition 崩)· policy-obs-misc MED-4(quiet-hours 跨午夜)· x-concurrency MED-5(静态计数器无同步)· x-test-integrity F4(release_gate 自 06-25 永 FAIL)/F6/F7 · hostkit-spine F3 · tests-arch ④(161 文件 iOS-source-gated)
- **device/runtime-gated**:devicetestapp MED-1/3/5/8/9 · mlx-adapter-core MED-6..11 · mlx-decode MED-1 · x-concurrency MED-LOW-10
- **hostkit-rest MED-1/4/5**(FullTurnAdapter 部分效应分叉 / sleep-consolidation 空 dry-run / audit-observation Task.detached 乱序)

**本轮已修 1 条真漏项(demo + concrete)**:organ-eval MED-1 = `outData` 竞态(见下方 commit)。**其余 36 条从"静默掉落"转为"显式追踪-open"**;~20 mac-可修者构成一个新 remediation 战役(须操作员授权规模),device-gated 者须真机。

★教训:**主题级"全闭"是审计诚实的头号陷阱**——"每个主题动过一次"≠"每条发现已闭";逐项对账是唯一能揪出"折进已闭主题"漏项的手段;operator 的"非 55/55 逐项"直觉正确,揪出 37 条。此更正本身 = 项目诚实教义(注释/账本不得声称代码/闭合不维持的属性)对审计账本自身的应用。

## 2026-07-11 — the last full-suite red: sleep-consolidation false-green fixture (CLOSED)

The first whole-suite run in days (after the XCFramework rebuild) left exactly 2 failing tests
(`BASMemorySleepConsolidationPassTests` dry-run verdict + mutation-moves-chain-hash). Root cause,
traced end-to-end and empirically confirmed: **the fixture seeded usage records into the Rust
actor tracker but constructed the applier over a brand-new EMPTY `BASMemoryUsageTracker()`** —
the applier's Swift scorer therefore saw every atom as no-history. Pre-blindspot-③ the
demote-on-arrival bug then demoted everything, so the tests were **false-green over an empty
universe** (a production bug and a fixture bug canceling out); the ③ fix (no-history ⇒ stays)
exposed them. Zero mutations also meant no M-h F6 ledger mark, freezing the chain hash — one
root cause, both failures.

Fix: seed BOTH trackers (Rust actor for stage-②'s FFI count; a V1 tracker handed to the applier
— what the pass actually scores) + sharpened teeth pinning the EXACT verdict (the 4 old
single-touch atoms move, the 2 recently-touched hold — an all-or-nothing empty-tracker
regression can no longer pass). Adversarial reversal (reintroduce the empty-tracker wiring)
reds both tests. Formula cross-check: old atom geometric score ≈0.056 ≤ 0.20 demote threshold;
recent ≈0.59 hold — matches observed behavior exactly.

NOTE (unchanged, documented honest bound): production `BASSleepConsolidationDriver:116` also
builds the applier over an empty tracker — but THERE it is an explicitly documented "not yet
closed" bound with dryRun hard-coded true. Wiring real usage history into the production applier
remains an open architecture step (ADR-014 V1/V2 duality), not a test concern.

**Lesson (false-green taxonomy):** two bugs canceling out reads as green. The blindspot-③ fix
didn't break these tests — it exposed them. When a principled fix "breaks" a test, check whether
the test was ever measuring what it claimed.

## 2026-07-11 — the 11-item mac-fixable batch: CLOSED (operator-directed "一次性打掉全部 11 项 MED-8 也授权修")

The gaps-ledger reconciliation's confirmed-open list, all closed in one campaign — each with
TDD teeth + adversarial reversal (test-level red required; compile-fail reversals were redone) +
individual commit/push. 79288970f→5ed684187 (13 commits incl. 1 honest correction + 1 bonus):

1. runtimecore-b LOW-9 — RiskPlane empty-input guard. CLAIM CORRECTED by reversal: the
   force-unwrap never trapped on this toolchain (empty-singleton pointer non-nil; Rust returns -1
   for zero-len) — a LATENT documented-nullable hazard, not a live crash. Correction pushed.
2. organ-eval LOW-2 — role validation hoisted above the decode-planner kill-switch + the #if.
3. x-concurrency LOW-12 — BASEmbeddingFactBank.load() single-flighted (reentrancy doubled the
   whole embedding pass: 12 embeds for a 6-fact bank, proven RED).
4. hostkit-rest LOW-4a — advisory ledger drop-oldest ring (4096) + audited evictions; aggregates
   became running counters so the cap cannot skew honoredRatio. (LOW-4b KVCacheRegistry default
   stays: adjudicated ADR-014 staged opt-in — operator call.)
5. hostkit-spine F9 — XCTAssertTrue(true) tautology replaced with real previewTransition
   non-mutation teeth (reversal took 4 attempts; coordinator has TWO record stores — the teeth
   read trialsByCandidate, so the mutation had to hit that surface to prove bite).
6. x-sovereignty #7 — SampleHost run JSON: per-run UUID replaces persistent identifierForVendor;
   source-tripwire in the BAS bundle (SampleHost is iOS-only).
7. probe LOW-6 — BASQwen35MTPProbe deadlines monotonic (sustain window + cert gap); tripwire: no
   wall-clock deadline loops under DeviceTestApp/Sources. Short Date() duration measurements
   remain (bounded noise — noted).
8. tools-scripts LOW — HumanEval exec seatbelt (deny-default sandbox-exec): sensitive-read/
   network/out-of-tempdir-write all EPERM, benign check() scores; 5 teeth with a no-pytest
   fallback runner; extracted qinao_sandbox.py (main-guard-less CLI).
9. hostkit-spine F7 — host face threads ssmCautionObservationSink + turnHistory + priorSSMState;
   flag-on is no longer silently stateless (turn2 fed turn1's ssmStateOut diverges from fresh —
   the chapter-188 temporal path ALIVE from the face). Defaults nil/[] ⇒ byte-equal off.
10. mlx MED-8 (operator-authorized) — BASSingleFlightSlot<Value> + _resolveMTPDecoderBox:
    concurrent cold turns build EXACTLY ONE ~300MB decoder (no ~600MB jetsam-adjacent overlap,
    no chainEmaL clobber); publish-at-build behind the MED-7 dropEpoch gate also closes the
    build-done→post-decode-republish rebuild window. Control flow Mac-proven (8 callers ⇒ 1
    build; error→all waiters; retry-fresh); the memory payoff is device-observable (adjudicated).
11. x-architecture LOW-4 — BASHostKit's dep on BASRustMemoryTrackerBinary declared (conditioned,
    no watchOS); xcodebuild-verified in isolated DerivedData (generic/platform=macOS fails on a
    PRE-EXISTING x86_64 Float16 artifact — noted).
BONUS (reconciliation's NEW finding) — generateSpecK reports TRUE proposed count (accepted could
    exceed proposed, inverting emaHitRate if the diagnostic lane were ever wired).

FINAL GATE: 16,380 XCTest + 424 swift-testing — ALL GREEN (+15 new teeth vs the morning gate).
Cargo workspace 1021/0. DeviceTestApp iOS build re-verified post-LOW-6.

Lessons banked: reversal must red at TEST level (2 compile-fail reversals redone; 1 reversal
REFUTED an agent's trap claim → honest correction pushed); agent claims need execution proof
before narrative; two-store actors need reversals aimed at the surface the teeth read.

## 2026-07-11 — two-phone device certification (operator: "全面测试 你有俩手机 最详细")

Both physical iPhone Airs (A18/A19, iOS 27.0; devicectl UUIDs 9E9E3DEB / 5E5C3C5C) ran the
campaign's device-observable surface in parallel:

**Cross-language byte-equality on the rebuilt ios-arm64 slice (9E9E):** 66 tests / 1 expected
skip / 0 fail — importance-scorer (incl. the un-skipped no-history=0.5 test), event-extractor,
risk-plane numeric version compare, tribunal most-severe-high, verdict max-rank all hold
Rust≡Swift on real ARM64. `rust_verify` ABI: resolved=8/8 matched=8/8 on BOTH phones.

**Campaign behavioral fixes on real APFS/jetsam (5E5C):** 92 tests / 0 fail — sleep-consolidation
false-green fixture fix, FactBank reentrancy single-flight, MED-8 BASSingleFlightSlot, advisory
ring, organ-eval LOW-2, ch934/946/M603 fuzz.

**FULL device bundle sweep (9E9E):** 15,267 tests / 161 skip / 15,088 pass / 22 fail-methods —
ALL 22 classified non-defects: 10 model-gated (noModelFactoryAvailable) + 12 source-tree lints
whose #filePath targets the absent Mac repo. ZERO behavioral failures, ZERO from this campaign.

**MTP sustain probe (twin run, BAS_MTP_SUSTAIN_MIN=3; assets pre-staged on both phones since
06-25/07-03):** the MED-9 one-decoder mechanism verified on both:
    5E5C: 35 gens | mean 20.9 tok/s | firstQ 30.0 → lastQ 16.8 (−44%) | a=0.90 | end serious
    9E9E: 36 gens | mean 21.4 tok/s | firstQ 31.3 → lastQ 16.7 (−46%) | a=0.90 | end fair
Evidence: build cost only in gen 01 (26.9/28.0 → steady 32.8/33.0 — the per-gen ~300MB rebuild
is dead); footprint iron-flat 3069MB all gens; a=0.90 constant (EMA continuity). Remaining −44/
−46% drift = genuine fanless-SoC thermal physics (throttle onset ~gen 12); the G3 ≥20 tok/s mean
held through the thermal wall. Honest bound: no matched pre-fix A/B window (cross-thermal
baselines incomparable per the DECODE-OS lesson) — the claim is the MECHANISM, not a drift delta.

Device-run infrastructure lessons (banked in memory `device-two-phone-testing`): the committed
xcodeproj is a fixed file list (regenerate via xcodegen on new test files; RESTORE the
increased-memory-limit entitlement + BGTaskScheduler id it strips); clean DerivedData after
regen; `-only-testing` curation is the sanctioned device method (the full bundle legitimately
drags host-only lints onto the phone); killing the devicectl console SIGTERMs the app; a locked
screen means onAppear never fires.

## 2026-07-12 — the red-light report: verified line-by-line, 4 real old-audit debts fixed

The operator surfaced a 6-item red-light report ("这是真的吗 你看看"). Verified each against the
real gates/code — the report was HALF right (numbers wrong in 3 places, one item outright false),
and every real item was PRE-EXISTING debt (git-proven: none introduced this session). All real
ones fixed, each with gate/test verification + reversal where applicable:

1. print()-residuals gate (report said 23; actual 82): TWO stacked debts — the gate's CLI
   exclusion list never learned about BASJournalCLI (53 legitimate stdout prints counted as
   residue; 82→29) + 29 genuine library stdout prints (fail-close warnings, 📊 telemetry) routed
   through a new BASDiagnosticLog (os.Logger; a LIBRARY — operator-ratified decision B — must not
   spam a host's stdout; 29→0). Gate clean. 9ada1c1e8.
2. qinao import gate (report said "3 UNKNOWN imports"): the real first layer was a COMPILE error
   — the policy-obs-misc LOW-8 audit fix (87ddf1e89) added .bridgeReferencesUnknownDomain to the
   BAS VaultError but never updated QinaoRuntimeSDK's mirroring translate() switch (cross-package
   audit drift). Fixed with a first-class mirror case. The "3 UNKNOWN imports" then surfaced —
   all legitimate; the checker's ^import X$ anchor choked on explanatory trailing comments →
   checker now strips inline comments. Gate passes. ece335279.
3. whitepaper schema parity (12 unregistered — report accurate): 12 genuine BASSchemaVersioned
   domain objects registered across all FOUR parity sites (registry + registry-tests +
   blueprint expectedObjects + QINAO canonical conformer set). All three parity checks green;
   4665/0 wide regression. b4960d698.
4. SampleHost SIGBUS (report accurate): 53-field EBrainTurnResult × deep init delegation ×
   cooperative-pool small stack. Fixed with an 8MB dedicated Thread; CAUSALITY PROVEN BY
   REVERSAL (Task.detached restored ⇒ crash reproduces; fix ⇒ 1.25s pass). +2 stacked drifts
   fixed en route (BASHostConsoleView→BASAdminUI import; stale -package-path commands).
   Giant-value-type structural root tracked, not closed. 284beed0f.

FALSE in the report: check_mlx_redaction "failed" — the script runs CLEAN. Environmental, not
debt: headless swift-test MLX metallib load failure (no app bundle — known harness limit).

Lesson: a red-light report is EVIDENCE to verify, not truth to accept nor noise to dismiss —
3 of 6 numbers were wrong, 1 item false, yet 4 real pre-existing debts hid underneath.

## 2026-07-12 — headless metallib: the "environmental" verdict above is OVERTURNED (it was debt)

The previous section closed item 5 as "environmental, not debt: headless swift-test MLX metallib
load failure (no app bundle — known harness limit)". Operator ordered a real fix — and the fix
work DISPROVED that classification. "Headless" was a red herring: the failure reproduces in a
GUI session. Root cause is a TOOLCHAIN FORK inside swift-test-headless.sh itself — the script
pins the STABLE Xcode (beta xctest SEGV guard), and stable SPM's native build system does not
produce/embed mlx-swift_Cmlx.bundle (the beta swiftbuild backend embeds it inside the xctest).
MLX's first Metal touch then fails all five metallib lookups and the mlx-c DEFAULT error handler
exit(-1)s the WHOLE xctest process: one "MLX error: Failed to load the default metallib" line at
the tail, gate dead, thousands of tests unrun.

Three fail-open layers (c4e9ac16c), each certified:
1. vendor patch (category 4): MLX_METAL_PATH checked FIRST in load_default_library (stderr
   marker; bad path warns + falls through — both arms certified).
2. BASMLXMetalAvailability: withError-scoped first-touch probe converts the C++ exit(-1) into a
   Swift throw; the three ungated MLX suites probe-skip LOUDLY (wiring pinned by a lint test,
   TDD red→green). Reversal: unwiring under the stable toolchain reproduces the operator's exact
   tail-kill.
3. swift-test-headless.sh pins any built metallib via MLX_METAL_PATH (skip→run upgrade certified).

Full-script verification (operator-ordered, 3 end-to-end runs) — the gate itself then flushed
two GREEN-BY-LUCK test bugs (both 07-audit-era tests; production Sources/ zero hits):
- run 1: notes-atomicity reader bound SQL text via withCString + nil destructor (SQLITE_STATIC
  promise on a closure-lifetime pointer) — sqlite3_step compared against freed memory; beta
  passed by allocation luck, stable deterministically read no row. rc-level A/B proven; fixed
  with SQLITE_TRANSIENT. d61d5b645.
- run 2: parallel worker SIGTRAP — wallclock sleep-gap test read mach_continuous_time BEFORE
  mach_absolute_time; on a never-slept host the &- gap wraps ~2^64 whenever the pair crosses a
  24MHz tick and the /denom*numer scaling traps. Empirical A/B (2M iters): old order 234,291
  negative gaps (11.7%), new order 0 (provably non-negative). 30cbc3900.
- run 3: GREEN end-to-end — gate 16,586 executed / 0 failures (191 honest skips), all 4 @Test
  batches green, SCRIPT_EXIT=0, zero MLX error lines, metallib env-hook marker live, orphan
  check 16,586 started = 16,586 verdicts (no worker deaths).

Lessons: (a) an "environmental" classification is a CLAIM requiring the same falsification
discipline as any fix — this one died on first contact with a reproduction attempt; (b) the
green-by-luck class is real: two teeth-bearing audit tests passed only by memory-layout /
tick-alignment luck until a second harness form (stable toolchain) pinned them; full-suite
verdicts must be earned under the exact harness form the operator runs. Ed25519 seals: 885567C6
(fix, record-match:c4e9ac16), E93FD27E (verification, record-match:30cbc390).

## 2026-07-12 — the giant-value-type structural root is CLOSED (EBrainTurnResult CoW box)

The last tracked-not-closed item from the SampleHost SIGBUS fix is now closed at the library
level. Measured root: 53 inline stored fields = a 12,200-byte value, and the 9→8→7→6→5→4→
all-fields bundle-init delegation ladder re-materialized field sets per rung under -Onone —
~550KB of turn-pipeline stack vs the 512KB cooperative pool (SampleHost SIGBUS + the
swift-testing @MainActor-guard class).

Fix (b4c5b0cdc, public API byte-identical): storage moved into a private CoW box (clone-on-
write via isKnownUniquelyReferenced in every setter) — the value is ONE pointer; all 11 public
inits preserved with every convenience init delegating FLAT to the all-fields init (ladder
gone); Codable key set / decode order / encode order preserved verbatim. God-file lint honored:
the 1919-LOC file split into main(707)+BundleInits(406)+BundleInitsLegacy(502)+Codable(348),
ceiling re-pinned TIGHT 1625→750, HostKit file band deliberately 285→288.

Proof chain:
- TDD teeth: size pin ≤16B (RED measured 12,200B), CoW copy isolation, inout setter path,
  Codable identity, Equatable discrimination (BASEBrainTurnResultBoxingTests).
- Reversal-grade at the ORIGINAL crash site (9ea90219f): SampleHost's 8MB-Thread workaround
  REVERTED to the exact Task.detached form that stably SIGBUS'd —
  testBenchLoopStartsAndStopsWithoutCrash passes (1.241s, iOS sim).
- Cooperative-pool probe: BASEBrainSchemaCoreTests ran GREEN with @MainActor stripped
  (historically its dream-loop test crossed the guard page first); guards retained as
  belt-and-braces with honest updated comments (runTurn's own ~127KB frame remains).
- Regression: beta full 16,553/0 · stable headless script 16,591/0 + all @Test batches green
  + SCRIPT_EXIT=0 · QinaoRuntimeSDK 1,449/0.

Residual (explicitly NOT closed by this): runTurn's own 127KB debug frame; the @MainActor
guards stay until that is shrunk or proven unnecessary suite-by-suite.

## 2026-07-12 — runTurn frame compressed 129,792→56,304B peak; @MainActor stack guards RETIRED

Operator-ordered completion of the residual from the CoW-box section above. runTurn's single
-Onone frame (129,792B, llvm-objdump) is split into six NAMED local functions (memoryDeliberate/
riskA/riskB/renderA/renderB/assemble) — verbatim line moves, compiler-derived tuple contracts
for cross-stage values, capture semantics for the rest. Debug peak = main-residual + largest
stage = 20,672 + 35,632 = 56,304B (−57%). Craft law: an immediately-applied closure literal is
SILGen-INLINED (measured: zero win) — only a NAMED local function isolates a frame.

Guard retirement (3401083ca): all four @MainActor stack-guard sites removed; the tests-arch ③
enforcement lint INVERTED into a cargo-cult detector (@MainActor paired with a stack/SIGBUS
justification reds; genuine actor-isolation untouched — its first catch was this changeset's
own prose). Successor mechanical guard: BASRunTurnFrameBudgetTests re-measures the built object
via llvm-objdump, budget 80,000B (reversal: budget→10K reds printing the live 56,304).

Bonus discovery (8db9a655e) — the final regression flushed a NARRATIVE OVERTURN: 5 file-
protection tests went red in both toolchains at 02:3x after passing at 01:50. Not my change:
ioreg CGSSessionScreenIsLocked=Yes at 02:12, and a bare probe (write + set .complete +
read-back) EPERMs while locked. On this macOS 27 / Apple Silicon generation NSFileProtection-
Complete IS ENFORCED at console lock — the audit-era "stored but inert on macOS" note is
obsolete on this OS. Fixed with BASScreenLockSkip (loud environmental skip; locked run 6
skipped/0 failures; unlocked runs exercise the real assertions).

Certification (committed state): beta BOTH halves 16,554/0 + swift-testing 424 tests/76 suites
GREEN on the cooperative pool un-guarded (the living teeth) · stable headless script 16,592/0 +
all @Test batches green + SCRIPT_EXIT=0 · SampleHost bench (Task.detached) 1.253s pass ·
QinaoRuntimeSDK 1,449/0. Turn-pipeline stack disease fully closed: value 12,200B→8B, frame
129,792→56,304B peak, zero thread-class workarounds remain in production or tests.

### 2026-07-12 addendum — the enforce-at-lock law is closed BOTH WAYS

Operator unlocked the console and ordered the real run: all 6 file-protection tests EXECUTED
(0 skips / 0 failures — including the read-back assertions that EPERM'd while locked), and the
bare probe (write + set .complete + read-back) passed. With the locked arm (identical code,
EPERM at 02:3x) this bidirectionally pins the law: the ONLY variable is console lock state.
BASScreenLockSkip's two behavioral arms are both field-verified — locked ⇒ loud skip, unlocked
⇒ real assertions. Seal D8E27893 (grounded record-match:8db9a655).

## 2026-07-12 — second red-light report: 9 of 10 items are a STALE CHECKOUT, 1 kernel fixed

Operator surfaced a 10-item report ("这些是真的吗 仔细排查"). Every item re-measured at HEAD
(253cf0dbb) this hour:

1/2. SampleHost SIGBUS + "heavy init chain": NOT REPRODUCIBLE — the exact test passed isolated
   (1.241s); the reported crash-stack shape (convenience-init forwarding + copying
   BASHostConstitution) can only exist pre-CoW-box (b4c5b0cdc). 3. headless metallib: fixed
   c4e9ac16c, three full green runs today (0 MLX-error lines, SCRIPT_EXIT=0) — the report's own
   "file exists, lookup problem" analysis matches the already-fixed root cause. 5. print 23>10:
   gate CLEAN (9ada1c1e8). 6. qinao imports: gate PASSES (ece335279). 7. MLX redaction: CLEAN
   (QinaoMLX is allowlisted by the script's own doctrine; the QinaoMLXEndpoint claim does not
   reproduce). 8. schema parity: CLEAN 275/276 (b4960d698). 9. README: already the recommended
   cd+-scheme form since 284beed0f. 4. "gates disagree": at HEAD pre-commit-gates.sh passes all
   3 — but the KERNEL is real: two scripts share the filename check_substrate_residuals.sh with
   DIFFERENT jobs (parent = residual-marker regex scan; BAS = residuals gate). Disambiguating
   headers added to both (4ed63334f). 10. "smoke test too heavy": BY DESIGN — the SampleHost
   bench test is the host-integration teeth (the very test class that caught the SIGBUS and
   proved its fix); 1.24s and deterministic; its weight is its value.

ROOT CAUSE of the stale nine: three detached worktrees under .claude/worktrees/ pinned at
06-29 / 04-25 / 04-17 — all predating every fix (07-11 23:38 onward). Any gate or test run
inside one reproduces the entire report verbatim, including the pre-box crash stack and the
exact stale numbers (print 23, 3 UNKNOWN imports, 12 schema). Cleanup is an operator call
(`git worktree remove <path>`, or point tooling at the main checkout).

Triage law (now banked): when a report contradicts fresh green runs, FIRST `git worktree list`
+ date the checkout the report was generated from — identical stale numbers across many items
is the signature.

### 2026-07-12 addendum — stale worktrees removed (operator-ordered, WIP-verified-clean)

All three detached worktrees (admiring-swirles@06-29, serene-kalam@04-25,
wonderful-goldwasser@04-17) verified before removal: 0 dirty files each, every HEAD reachable
from decode-planner (zero orphan commits — nothing lost). Removed via `git worktree remove`;
`git worktree list` now shows only the main checkout. The stale-report source class is closed:
there is no old checkout left for tooling to wander into.

## 2026-07-12 — third report iteration: 6 design asks certified against HEAD; 3 already-built, 3 kernels landed

1. TurnResult structural slimming ("boxed/reference 化, builder/assembler"): ALREADY BUILT —
   the proposal describes the shipped fix (CoW box b4c5b0cdc + flat single-hop inits +
   stage-split runTurn); 6 teeth green live (size pin, CoW semantics, frame budget).
2. Bench test → mock/stub: DECLINED WITH REASONING, intent declared in-code (664f5a3a0) —
   the heavyweight path is deliberate integration teeth (it caught the SIGBUS and proved the
   fix); a mock start/stop variant is tautology-class; runtime is ALREADY constructor-
   injectable on SampleHostModel for hosts that want a stub.
3. MLX touch-boundary isolation: ALREADY BUILT — BASMLXMetalAvailability probe gates the
   ungated suites (wiring pinned by lint), MLX_METAL_PATH pinned in the headless gate;
   three full green runs stand.
4. Gate authority convergence: LANDED (a9d27f094) — the parent marker scan renamed to
   check_substrate_residual_markers.sh, a delegating shim keeps the old path alive,
   'check_substrate_residuals.sh' now unambiguously means the BAS gate. Four invocation
   forms verified green.
5. Qinao/MLX boundary policy: WAS ALREADY DEFINED (M222: QinaoMLX IS the bridge and may
   import BASMLXAdapter; QinaoSampleHost is the documented executable-demo exception) —
   the gate is clean, rule matches reality; the stale top header now states both allowances
   (a9d27f094).
6. logging sink: ALREADY BUILT — BASDiagnosticLog (os.Logger) took the 29 library prints
   (9ada1c1e8); remaining print() sites are the CLI product surface and DeviceTestApp probes
   (excluded with justification); gate clean.

Premises 1/3/6 and the red numbers cited were the same stale-worktree artifacts dispositioned
in the section above (worktrees since removed).
