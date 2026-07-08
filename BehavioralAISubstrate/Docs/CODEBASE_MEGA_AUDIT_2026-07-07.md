
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
13. ShadowTrial 乐观并发 + ledger 回滚（H9,1.5d）——L13 上生产前必修。
14. Rust event log 100k 截断分页（H10,含 XCFramework 重建,1d）。
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
16. **删除教义收口**：全 store secure_delete/VACUUM default-on（ADR-014 opt-in→certified→default-on）。
17. token 历史清洗（filter-repo/LFS purge）——**删除类,必须操作员亲自裁决**。
18. 测试诚实度：~300 条 assertCodable 自比较升级为真 round-trip；9 条 print-only 加断言或门控；B2 /tmp 状态依赖去除。
19. KG codec 上生产前重建 XCFramework（M-n）。
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
