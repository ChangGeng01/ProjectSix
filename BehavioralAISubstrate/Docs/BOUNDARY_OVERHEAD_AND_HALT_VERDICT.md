# BOUNDARY OVERHEAD & HALT VERDICT — 三项证据型 DECLINE(2026-06-12)

Three operator-raised architecture concerns, adjudicated against the repo's own
hardware evidence(R1:声明只跟证据走;亏的不要:复杂度亏损不上)。 Each DECLINE
records its **re-open trigger** — these are evidence-bound verdicts, not dogma。
The TRUE kernels of concerns ② and ③ are NOT declined — they are built as
U1-U4(see plan / commit history):runtime pressure-responsive speculation
governor、maxKVSize knob、decode liveness monitor、host graceful drain。

---

## D1 — DECLINE: Swift↔Rust 零拷贝/共享内存/FlatBuffers 基建

**Concern**: 14 层认知在 Swift、记忆原子/账本在 Rust;若每 turn 或每 token 的
因果推导都过 C-bridge 重序列化 + 内存拷贝,FFI 开销可能吃掉 MLX 省下的延迟 —
需建共享内存指针或 FlatBuffers 级裸二进制无拷贝通信。

**Verdict: DECLINE — 前提被设备实测证伪。**

1. **Per-token FFI = 零。** MLX decode 是纯 Swift/Metal(vendored mlx-swift-lm);
   Rust 只在 turn/会话边界被触及(记忆检索/追加、账本)。 decode 循环内不存在
   任何 Swift↔Rust 穿越 — 按设计(ADR-038 wedge 防护 / ADR-039 边界)。
2. **整个基底级联(含全部 per-turn FFI)= turn 的 0.8%。** On-device captured
   (2026-06-09, iPhone Air):`turn-breakdown iter_ms=2577 brain_ms=21
   mlx_ms=2551 substrate_pct=0.8 mlx_pct=99.0`
   (`CONCURRENCY_MEASUREMENT_FINDINGS.md` §turn-breakdown)。 假设零拷贝基建把
   FFI 开销降到 0,理论上限收益 < 21ms / 2577ms < 0.8% — 而引入跨语言 schema
   维护、版本锁、调试面的复杂度是永久成本。 纯亏损交易。
3. **热路径早已合并 + 零拷贝早已在用(该做的已做完)。**
   - L8 检索 = **1 次 FFI/查询**(`bas_l8_vector_index_cosine_topk_for_domain`,
     Rust 内 batch fetch+score),实测 90-134× FFI-hop 缩减
     (`L8_ARC_SEAL.md:181-205` — 并诚实记录"100× 框架有误导,本质是 hop 合并")。
   - 大向量已走裸指针:`BASAutoRouteRanker+Cosine.swift:83-101`
     `withUnsafeBufferPointer` 直传 Float/Int8 缓冲,零序列化。
   - 标量桥(L1-L6)直传 C 标量,无序列化。
   - 剩余 JSON 面(k=3 检索结果、≤10 原子/turn 的 drainIntents 追加)在 turn
     边界、payload 微小 — 不在任何热路径。
4. **FFI 亏损案例已被门拒绝过。** ch717 forget-cascade 路由实测 2.2× 因 FFI
   开销变慢 → 按 5-axis 门(STRONG-FLIP ≥2× 才翻 / TIE / LOSS 不上)拒绝
   (`BASChapter717ProvenancePerfTests` 头注);存储级迁移 0.92-1.05× = 噪声 tie,
   不翻(`L8_ARC_SEAL.md:154-166`)。 纪律本身就是防 FFI 亏损的常设机制。

**Re-open trigger**(钉死):`turn-breakdown` 行显示 `substrate_pct` 实质增长
(仓库已定义此触发器为 Metal-4 量化家族同款重开条件);或某个新车道被迫引入
per-token FFI(当前架构禁止)。

---

## D2 — DECLINE: 内存钉(mlock)/ 增内存 entitlement / 换出策略 / "QinaoHost 深权限"

**Concern**: 8B 4-bit(5-6GB)+ draft(1-2GB)+ 双 KV-cache 动态常驻 + Agent
Fabric 多席上下文,在 8/16GB 基础款上需精准内存钉与换入换出策略,需给
QinaoHost 极高底层权限。

**Verdict: DECLINE(钉/权限/换出三件套)— 双机认证已给出答案;真内核(运行时
压力响应)不是 decline,是 U1/U2 开发单元。**

1. **出货配对无需任何权限即 FITS。** Llama-3.2 3B↔1B 双驻峰 **2542 MB**,远低于
   实测 jetsam per-process 上限 **3376 MB**(`SPEC_DECODE_CERT_RESULTS.md:13,37`;
   静态预算 `defaultSpeculativeFitBudgetBytes=3000MB`,
   `BASMLXMemoryBudget.swift:66`)。 `BASDeviceTestApp.entitlements` 是空
   `<dict/>` — **深思熟虑的不需要**,非疏漏。
2. **超限配对连 entitlement 都救不了。** Gemma4 E4B↔E2B ≈4.2GB 两级失败认证在案
   (`SPEC_DECODE_CERT_RESULTS.md:25-28`):默认限直接 jetsam 杀;**加了**
   `com.apple.developer.kernel.increased-memory-limit` 后 E4B 能载,但 E2B 叠上
   驱动全设备进内存压力、系统开始杀后台 — "深权限"不解决物理内存不足,只把
   失败模式从本进程死换成全设备劣化。 裁决 doNotEnable / MEMORY 站立。
3. **iOS 无用户态 mlock/钉页权限。** 第三方进程无 `mlock` 生效保证、无 wired
   memory 申请面;"内存钉"在 iOS 上不是可建机制。 8B 级模型在 8GB 设备的正确
   答案是**不上 8B**(选 3B↔1B 这类 FITS 配对)+ KV 内存削减杠杆
   (`kvBits` 已落地 b37e94606;`maxKVSize` = U2)。
4. **换出策略**:iOS 27 App Swap 是 OS 持有的机制,进程能做的是观察
   (`bas_vm_swap_stats`,P6 已建)与减少自身足迹 — 不存在进程侧"换出策略"可写。
   观察面 → 驱动的缺口由 **U1 调速器**(跨 turn 压力响应、建议型、greedy
   token-identical 故零字节风险)填补。

**Re-open trigger**:Apple 开放用户态页钉/常驻 API;或出货模型组合变更使双驻
不再 FITS(则先按 cert 流程重测,再谈机制)。

---

## D3 — DECLINE: 抢占式调度器 / per-turn 超时 / 逐层(L1-L14)超时熔断

**Concern**: 认知层越多流水线越长;若 L3 卡住或 L7 主权审计认知冲突,系统如何
优雅 Halt 且 UI Silent Stub 不卡死 — 需极硬核异步抢占式调度器。

**Verdict: DECLINE(调度器/超时);检测与优雅面 = U3/U4 开发单元。**

1. **CPU 级联物理上不可悬挂。** `runTurn` 是同步确定性 CPU 代码
   (`EBrainRuntimeCoordinator+RunTurn.swift:59-61`,无 I/O、无网络、无 GPU
   await),全程 21ms。 L3 "卡住"无机制可发生;L7/L14 主权冲突是**确定性裁决
   输出**而非悬挂 —— `.deadStop/.toolCut/.quarantine/...` 映射到
   `userStubMode`(`EBrainRuntimeCoordinator+SovereignVerdict.swift:64-71`),
   UI 收到 `QinaoSilentStubModel`(`QinaoSilentStub.swift`)呈现拒绝回执。
   冲突路径**已经**优雅 Halt — 这正是 fail-closed 治理内核的设计。
2. **唯一真悬挂源不可取消 — per-turn timeout 试过并以设备证据移除。**
   ch1066(`BASEnduranceAppRunner.swift:825-831`):MLX decode 是同步不可取消
   Metal eval — (a) structured task-group timeout 在 teardown 等楔死子任务时
   自死锁;(b) GPU 楔死本就让 app 数十秒内被杀,timeout 赢不了这场赛跑。
   依据 `ADR_038 §9-§10.2`:取消检查仅存在于 token 之间
   (Evaluate.swift:1691/1723),首 eval 零 token 楔死不可达;`eval.cpp:92`
   `waitUntilCompleted()` 无 timeout API;`evalLock` 进程全局,一处楔死冻结
   全进程 eval;GPU sibling 探针在楔死时 6/6 完成 — 楔死是 MLX 进程局部,
   杀+重启全恢复,非固件。 **iOS 进程内抢占此悬挂类 = 不可能**,任何"抢占式
   调度器"都将是不能兑现承诺的代码。
3. **UI 本不卡死。** decode 在主线程外(adapter async 边界),Silent Stub 在
   turn 结束随 verdict 呈现;已落地战略 = 预防(feed-forward 默认 OFF + 输入
   定界 512 chars)+ 外部看门狗重启(Mac 侧心跳检测)。 缺的不是调度器,是
   **宿主侧可观测性与状态保全** — 即:
   - **U3 BASDecodeLivenessMonitor**:token 进度心跳 + GPU 探针佐证,stall
     verdict 回调宿主(呈现 stub、存状态、提示重启)— 检测,绝不尝试杀。
   - **U4 BASHostGracefulDrain**:账本排空 + 验链 + 账段关闭的编排 seam,
     供 verdict 后或退场时调用。
4. **逐层超时**:对 0.8% 的确定性代码加 14 层 timeout 包装 = 为不存在的悬挂
   付出真实的复杂度 + async 化开销。 亏的不要。

**Re-open trigger**:上游 MLX 暴露可取消/带 timeout 的 eval API(则 ch1066
裁决重审);或某层引入真实阻塞调用(则该层单独加针对性 deadline,而非全员
调度器)。

---

## 总账

| 操作者解法 | 命运 | 真内核去向 |
|---|---|---|
| 共享内存/FlatBuffers 零拷贝 | DECLINE(0.8% 上限,纯亏) | —(该做的 hop 合并/裸指针已做完) |
| 内存钉 + 换出 + 深权限 | DECLINE(认证反驳三件套) | U1 跨 turn 压力调速器 + U2 maxKVSize + 已落地 kvBits |
| 抢占式调度器 + 超时熔断 | DECLINE(设备证明不可能/不需要) | U3 活性看门狗(检测)+ U4 优雅排空 seam |

负结果也是产出;门从不自动晋升;重开条件全部钉死在案。
