# Qinao 衬底(BAS 14 层电子脑) · 100 指标体系

> 范围说明:本文是 **衬底(substrate)** 的健康/性能/确定性/主权(health · performance · determinism · sovereignty)度量体系,覆盖 L1–L14 全部 14 层电子脑、以及跨层的治理/确定性/鲁棒性切面。它衡量的是「脑」本身——租约与散热、神经组织内核、路由与预算、记忆、编排与三我庭、策略与风险、可观测性、主权裁决与审计链——而 **不是** LLM 输出质量(那是配套文档 `QINAO_LOCAL_MODEL_100_METRICS.md` 的职责)。
>
> 每条指标都要求 **可严格测量**:给出定义/怎么测、方向、门槛或 Gate、级别。方向取值:`up`=越大越好、`down`=越小越好、`equal`=须严格相等、`gate`=布尔/集合判定。级别按 `code-review.md` 严重度分级:CRITICAL(阻断发布)、HIGH(应在合并前修复)、MEDIUM(可考虑修复)。全篇指标连续编号 1–100。

---

## 一、L1 BASLeaseLife · 租约生命周期 / 散热 / 预算闸门 / 杀停恢复

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 1 | thermal_guard_mapping_purity | 纯映射 `BASThermalTwin.guardLevel(for:accumulated:)` 的确定性与全覆盖。属性测试:对(每个 `BASThermalLevel` × accumulated∈{0.0,0.29,0.3,0.69,0.7,1.0} 网格 + 1万随机 p∈[0,1])断言返回值与类型文档矩阵逐字节一致,且同输入两次调用结果相同;p 越界按 clamp 处理。 | gate | 网格+随机用例 100% 命中文档矩阵且确定;任何不符或非确定即阻断(L1 策略权威,漂移会静默误节流) | CRITICAL |
| 2 | emergency_cancels_all_breaths | 杀停路径正确性:guard 升到 `.emergency` 时 `BASBreathScheduler.reconcile(with:.emergency)` 后 `count()==0`,且每个先前 id 都恰好被 `bridge.cancel(id:)` 一次。集成测试:.nominal 下排 N 个 breath,经 Reader 驱动 twin 到 .critical,断言 `scheduledBreaths()==[]` 且取消集合==先前 id 集合;并断言 .emergency 下 `schedule(...)` 抛 `thermalEmergencyRejectsAll`。 | gate | emergency 后 breath 数==0 且取消数==先前数(无孤儿 OS 唤醒);残留任何 breath 即阻断 | CRITICAL |
| 3 | throttle_class_admission_correctness | 预算/散热闸门选择性:`.throttle` 只放行 `.light/.none`,丢弃/拒绝 `.standard/.deferred`;`.watch/.nominal` 全放行;`.emergency` 全拒。以(4 guard 等级 × 每个 `BASMaintenanceClass`)混淆矩阵覆盖 `validate(class:at:)` 抛错路径与 `reconcile` 丢弃路径,逐项对契约文档。 | gate | 零误放(被禁类幸存)、零误拒(.light/.none 被拒);误放=CRITICAL(热机仍跑维护),误拒=HIGH | CRITICAL |
| 4 | lung_pressure_decay_fidelity | 跨轮积分的数值正确性与单调性。注入时钟,断言 `p_next == clamp01(p_prev*exp(-idle/τ) + load(mode)*max(0,duration))` 绝对误差 ≤1e-12;断言 pressure∈[0,1] 恒成立;仅空闲的 `settle()` 单调非增;load 权重与文档表一致。 | gate | 对闭式解最大绝对误差 ≤1e-12 且 pressure 不越 [0,1] 且 settle() 不增压;权重错或未 clamp 即阻断 | HIGH |
| 5 | coordinator_turn_ordering_invariant | 协调器排序契约:lung 先 decay 后 twin 读压力,scheduler 在新 guard 后才 reconcile。验证 `TurnRecorded.cancelledBreathIDs` 恰为差集,且返回 Reading 的 `accumulatedPressure == lungSnap.pressure`(无陈旧读)。actor 集成测试+间谍 scheduler 抓调用序。 | gate | 每次 recordTurn/resample 返回 `accumulatedPressure==lungSnap.pressure` 且 cancelledBreathIDs 为精确差集;读到 decay 前压力即阻断 | HIGH |
| 6 | emergency_forces_cpu_route | 设备路由安全底线(规则1):`thermalGuard==.emergency` 时 `BASDeviceRouting.recommend(...)` 必返 `.scoutCPU`。穷举 2 角色×4 精度×8 能力子集@emergency 断言 `.scoutCPU`;并断言 `.throttle` 永不返回 NPU 路由。 | gate | emergency 组合 100% 返回 `.scoutCPU`;.throttle 下 0 个 NPU 路由;emergency 非 CPU 路由即阻断 | CRITICAL |
| 7 | compute_router_floor_no_overheat | `BASComputeRouter.route` 只在所有首选层均低于 floor 时才回退到最凉层,否则取 preferredOrder 中首个 ≥minHeadroom 的层;空快照→nil。≥10万随机 `BASComputeTierThermalSnapshot` 属性测试;headroom 初始化 clamp 到 [0,1]。 | gate | ≥10万随机快照 0 违例(选层守 floor-then-fallback);空→nil 恒成立;为热层跳过可用凉层即阻断 | HIGH |

---

## 二、L2 BASOrgan / BASMLXAdapter / BASMetalSubstrate / BASAppleAdapters · 神经组织内核 · 适配器路由 · Metal 衬底 · Apple/CoreAI 适配

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 8 | metal_vs_cpu_ssm_scan_parity_mae | 算子权威 CPU 路径(`BASSSMScanCPUReference.scan`)与 GPU 孪生(`BASMetalSSMScanDispatcher` / `ssm_scan_float32` MSL kernel)在同输入下输出 y 的逐通道 MAE(`BASMambaGPUShadowParity.perChannelParityMAE`);SSMScan/FlashAttention/topK 同构。 | down | 每 kernel MAE ≤ 1e-5;设备认证锚:ssm/attn parity_mae=0.000000、topk max_score_err=0.000000;设备 MAE>1e-5 不得上线 | CRITICAL |
| 9 | rmsnorm_layernorm_epsilon_fidelity | 各 norm kernel 使用钉死的 epsilon(RMSNorm 1e-6 = Gemma3/Llama3/Qwen2/Mamba;LayerNorm 1e-5)取自 `BASNormEpsilon`,且 GPU 输出对 fp32 CPU 参考在容差内。kernel parity fixture 随机输入验证。 | equal | epsilon 严格==`BASNormEpsilon.rmsNorm`/`.layerNorm`;GPU-vs-CPU MAE ≤1e-5;任何 kernel 硬编码偏规 epsilon 即阻断 | HIGH |
| 10 | mpsgraph_kernel_proof_coverage | 可发布 MPSGraph kernel(matMul/attention/RMSNorm/layerNorm/conv2D/rotary)中 `hasNumericalCorrectnessProof==true` 且 testCaseCount 达标的比例,由 `BASMPSGraphKernelCoverageBundle` 聚合;检测「是否有 kernel 跌出 4/4 已证状态」。 | equal | 100% 注册 kernel 有数值正确性证明;回归检查须空;仅构造断言(无数值证明)的 kernel 禁入实时路由 | HIGH |
| 11 | mlx_cache_pool_ceiling | loadModel 时 MLX 空闲缓冲池受 `cacheLimitBytes`(默认 512MB,经 `BASMLXMemoryModel`)约束,池趋平台而非无界增长。测持续解码完成数与稳态池平台(MB)。 | up | 池在 ~cacheLimitBytes 平台且持续跑完成(锚:Gemma-3n-E2B 30/30,池~512MB vs 无界~3 轮 wedge);该帽输出逐字节等价 | HIGH |
| 12 | mlx_preload_memory_admission | `enforceMemoryAdmission` 开启时,loadModel 拒绝估算峰值占用+安全余量越过设备 ActiveHard jetsam 帽的加载(`BASMLXMemoryBudget`)。测越帽项 mid-load SIGKILL 数与可生存项的误拒数。 | gate | 越帽项 0 次 mid-load jetsam(E4B 4314MB>帽被拒),可生存项 0 误拒(E2B 3114/Llama-3B 2969MB 放行);nil 估算→放行 | HIGH |
| 13 | mlx_runtime_config_conflict_safety | 对进程级全局 `MLX.Memory.cacheLimit/.memoryLimit` 的所有写经唯一 `MLXRuntimeConfig.shared`:冲突 `.adapterDefault` 被拒(首默认胜)并记录,`.explicitOverride` 胜并记录。测静默全局变更(无 ApplyResult 且无日志)数。 | gate | 静默写==0:每次写帽返回 typed ApplyResult 且冲突/覆盖发诊断;第二适配器异默认必得 rejectedConflict | HIGH |
| 14 | decode_stall_wedge_detection | `BASDecodeLivenessMonitor` 以 `now - lastProgress` 对 `stallThresholdSec` 比较,每个停顿期发一条 `BASDecodeStallVerdict`,并在检测时注入 GPU sibling 探针(gpuProbeHealthy==true + decode 停=mlx-process-local-wedge 签名)。测检测延迟与「零取消尝试」。 | gate | 监视器永不尝试取消/杀(硬规则);须在 ~stallThresholdSec 内对外部看门狗发可解析 verdictLine;进程内恢复被禁(ADR-038) | HIGH |
| 15 | prompt_lookup_spec_token_identity | 贪婪(temp 0)解码下,`BASPromptLookupDecoder.generate`(n-gram 起草、verify-and-trim)每个产出 token 等于主模型自身 argmax,流与单模型贪婪逐 token 一致。设备 SSD 探针 N/N 对比。 | equal | temp 0 下 byte_identical==N/N(100%);滑窗模型须走 `BASWindowMaskedCache.verifyCache`,否则 fail-close 抛 `nonTrimmableCache` | CRITICAL |
| 16 | spec_teacher_forced_alpha_gate | 同词表 target/draft 的逐位 teacher-forced 接受率 α(`MLXOrganAdapter.teacherForcedAgreement`+`BASAcceptanceBlockReducer`),端到端胜=kill-switch toggle 实测 tok/s 比。 | up | 仅当端到端 tok/s 比 ≥1.0 才启用 draft 道(成本感知 never-worse);free-form α~2.28 但端到端 0.88× 是净亏 → 按 speedup 而非接受率开闸 | HIGH |
| 17 | mlx_evallock_concurrent_correctness | 并发轮在唯一 GPU evalLock 串行(MLX 解码占轮时 ~97-99%)。测 N 并发 vs N 串行的 wall_speedup 与每轮输出不变性。 | equal | 并发输出==串行输出(无跨轮污染);wall_speedup≈1.0 是预期(GPU 串行瓶颈);宣称并发加速被禁;衬底级联占轮 ≤2% | HIGH |
| 18 | accelerated_draft_default_off_byte_equality | 每个 `BASOrganAdapter` 的 `draft(_:electAccelerated:)`/`draft(_:purpose:)` 默认实现忽略加速标志、调 `draft(_:)`,使无加速道适配器(确定性/Apple/远程)与非加速路径逐字节同。测加速调用 vs 普通调用 body/输出字节。 | equal | 无加速道适配器:`electAccelerated:true).body == draft(...).body`;有道适配器(MLX,temp 0)token 同、仅更快(ADR-014 opt-in) | HIGH |
| 19 | coreai_ane_conversion_fidelity | 转换后的有状态 `.aimodel`(`llama_to_coreai.py`)对其 host PyTorch 参考:逐 token logits `max|pt-coreai|` 在容差内、逐位 argmax label 一致;融合 one-hot KV 写须用 `torch.where(mask,v.expand,kv)` guard(否则 KV-heads 被零化、保真崩)。 | equal | `max|pt-coreai|<0.01` 且 argmax label 24/24;必出 int8/int4(fp16 1B 全后端不可编译);KV-write guard 在每个转换器强制 | CRITICAL |
| 20 | coreml_to_coreai_migration_gate | `BASCoreAIMigrationVerdict.decide` 仅在候选在 parity+延迟+内存全胜且样本充足(≥2 设备)时返 migrate;否则 doNotMigrate / insufficientEvidence;NaN-safe MAE。 | gate | 默认拒:label 一致 ≥1.0、logits MAE ≤1e-3、≥50 样本、≥2 设备、延迟与内存各 ≤现任×0.95;平局不算胜 | HIGH |
| 21 | provider_routing_determinism | 两个路由面纯且可重放稳定:`BASNeuralProviderMatrix.select`(score DESC→providerID ASC,无 Date/UUID/随机/调用序)与 `BASLLMModelRouter.defaultPolicy`(按 rawValue 排,无 Set.first 非确定)。测跨运行/注册序的同一决策。 | equal | select/decide 跨运行/插入序逐字节稳;reason code 为固定大写常量;路由仅 hint 且禁入 spine | MEDIUM |
| 22 | bastensor_descriptor_phantom_agreement | 每次 `BASTensor` 构造在 kernel 见到前用 precondition 强制 descriptor 的 dataType/rankTag/backingKind/shape.count/(cpu)byteCount 一致。测构造期违例数(通过构建须 0)+descriptor Codable 往返稳定。 | gate | 违例==0:无 dtype/rank/backing/字节数不符到达 kernel;descriptor 往返逐字节稳;BASMetalSubstrate 保持不导入 MLX/CoreML | MEDIUM |

---

## 三、L3–L7 BASRuntimeCore · 路由/分解热路径 · 校准存储 · provider 规划 · 自适应预算

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 23 | auto_route_choice_vs_crossover | 每个被路由的原语(cosine/sha256/layerNorm/geluTanh/batchedCosine/attention/matmul)×每个输入尺寸,比对 `BASAutoRouteRanker` 发出的 `BASAutoRouteChoice` 与 `BASAutoRouteCalibrator` 同机实测更快者。测(workload×size)格中路由==实测胜者比例。 | up | ≥0.95 格正确;临界一步内平局可接受;远离临界仍选严格更慢路径=HIGH 回归 | HIGH |
| 24 | calibration_cache_invalidation | 演练 `BASAutoRouteCalibrationStore.validate` 四个独立失效检查(schemaVersion≠4、substrateVersion 不符、deviceFingerprint 不符、age>maxAgeSec)。测各检查独立触发重校准,且有效缓存第二次命中 0 重校准。 | gate | 4/4 失效独立触发 且有效缓存命中(0 重校准);report.init 的 schemaVersion 默认须==store.currentSchemaVersion(否则每次启动重校) | HIGH |
| 25 | calibration_threshold_field_coverage | 断言 `BASAutoRouteThresholds` 每个非可选字段或被 calibrator sweep 测量、或显式从 mSeriesDefault 转发(带理由)。测既未测量又未显式转发(会静默回退默认)的字段数。 | down | 未交代字段==0;新增 threshold 字段而未经 calibrator 决策时,结构测试须失败(chapter-877 HIGH-1 类) | HIGH |
| 26 | provider_plan_route_constraint_soundness | `BASDefaultRoutingPlanner` 永不发越 `allowedRoutes` 的路由(localOnly→仅 local;offline→无 cloud/hybrid-cloud);`BASProviderPlanner.isCompatible` 永不保留缺 responseLanguage/supportsThinking/supportsStructuredOutput 的 provider。测含禁路由或不兼容 provider 的计划数。 | down | 禁路由==0(隐私/离线硬约束);不兼容 provider 泄入 orderedProviderIDs==0(兼容过滤是硬闸,惩罚分仅软信号) | HIGH |
| 27 | provider_plan_determinism_tiebreak | 同输入重跑 `BASProviderPlanner.plan`/`BASProviderRouteResolver.resolve` N 次+输入置换,断言 orderedProviderIDs 恒同;平局回退 baseIndex,等分等 baseIndex 落稳定次键。 | up | 100% 稳定排序;比较器须全序(无两个不同 provider 无确定终裁地比较相等);否则破上游轮字节等价闸 | HIGH |
| 28 | provider_fallback_availability_resolution | 驱动 `BASRuntimeAvailabilityResolver` 跑全源矩阵(runtimeDisabled/testingOverride/templatePinned/preferred/fallback/deterministicFallback)。断言:禁用→deterministic;preferred 不可用→首个可用 fallback;全不可用→deterministicFallback(不崩、active 非空)。 | up | 矩阵 100% 正确;activeProviderID 永不空(deterministic 是保底);无 active provider 的轮=HIGH 缺陷 | HIGH |
| 29 | adaptive_budget_floor_monotonicity | 跑全 `BASAdaptiveRuntimeMatrixRequest` 网格(gear×env×device×lang×trace),断言每个预算守每类 floor(context≥160/220/260/140、output≥120、time≥300、tool≥0)且随约束严格度单调退化。测违 floor 或违单调的格数。 | down | floor 违例==0(低于可执行 floor 会饿死层);单调违例=HIGH(受限设备拿到比满配更大预算=符号 bug) | HIGH |
| 30 | adaptive_strategy_idempotence | `BASAdaptiveTaskStrategy.adapting(signals:)`:同输入确定;二次施加预算不低于 floor、actionSpace 稳定(无无界增长/重复插入);每次缩减仍守 minimumBudget。测非确定/破 floor/无界增长的(strategy,signal)对数。 | down | 非确定输出==0(喂上游字节等价闸)、破 floor==0;actionSpace 重复插入=MEDIUM | MEDIUM |
| 31 | routing_policy_lineage_completeness | 每个 `BASProviderSelectionPlan`/`BASRuntimeStatusSummary` 带 appliedRoutingPolicyVersion+RegistryVersion(或显式 `.missing` 哨兵);线程入轮的 `BASRuntimePolicyLineage` 三 ID 非空。测 lineage 字段完整(或显式缺失)比例。 | up | ≥99% 已填;非哨兵空白=MEDIUM(每个路由决策须可归因到版本化策略);生产路径用 policyIfAvailable | MEDIUM |

---

## 四、L8 BASMemory · 事件/记忆/投影 · 受治理检索 · 向量索引 · KV 缓存 · SQL 持久化

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 32 | durable_cosine_topk_recall | 跨会话恢复后(`BASSQLiteVectorIndexStorage.preload`→`BASVectorIndex` 或 Rust 路由 cosineTopK),与内存 Float32 暴力 topK 的 atomID 重叠:recall@k(≥100 查询×≥1000 行×384 维)。Float32 路径须精确,持久路径加 persist→reload 往返。 | up | Float32 路径(内存路由/批/SQLite reload)recall@k==1.000(集合与序在 fp32 容差内同);Float32 路径任何偏离即阻断 | CRITICAL |
| 33 | int8_vector_cosine_drift | 可选 int8 量化路径(`topKInt8`/`useInt8VectorStorage`),测 100 查询×1000 行×384 维下 `max|cos_int8−cos_f32|` 与 int8 topK 对 Float32 的 recall@10。 | down | cosine 漂移 ≤0.01(ch727 第三刀质量闸)且 int8 recall@10 ≥0.98;超任一则 useInt8VectorStorage 生产保持 OFF | HIGH |
| 34 | vector_index_dimension_bind | 插入/查询时维度异于索引绑定维须被拒(insert/upsert 抛 dimensionMismatch;topK 返 []);持久路径 SQLite 解码须拒 blobSize≠dim×4。注混维属性测试。 | equal | 100% 维度不符操作在边界被拒;零静默误打分条目 | HIGH |
| 35 | non_finite_embedding_rejection | NaN/Inf embedding 在插入边界被拒(`validateFinite`→nonFiniteEmbedding)、查询被拒;sortKey 把非有限分映 −∞(NaN-safe 严格弱序),单条毒行不能 DoS topK。 | equal | 100% 非有限 embedding/查询在边界被拒 且 topK 可证永不在非有限分上 trap;单原子 DoS 类零容忍 | CRITICAL |
| 36 | rag_stale_atom_lockstep | 向量索引返回但 atomLookup 解不出(原子已删、索引未扫)的 atomID 必入 `BASRAGResult.staleAtomIDs` 且不入 atoms/scores。删已知子集后跑 retrieve,断言 stale 集==删-但-仍索引集(全划分且不相交)。 | equal | staleAtomIDs==(候选−可解)精确;解析+stale 全且不交;stale 非空时发 `rag:stale:<n>`;无 stale 漏入 atoms[] | HIGH |
| 37 | governed_excluded_domains_adherence | 传入 excludingDomains 时,零返回候选的 domain 匹配任一排除模式(大小写不敏感子串)。标敏感子集为排除域后跑 topK/RAG,数泄漏(排除域)原子。 | equal | 泄漏排除域原子==0(Float32 与 int8 路径);发 `rag:excluded-domains:<n>`;在检索边界守不变量#2;任何泄漏即阻断 | CRITICAL |
| 38 | memory_governance_determinism | `BASMemoryGovernance.assess/baselineAssessment` 纯确定(同 draft→同 {admit|deferred|reject})且 100% 拒 provenanceRisk(污染/工具塑形)草稿。N=1000 重放断言同裁决+每个 provenanceRisk→reject(除连续性保护 carve-out)。 | equal | N=1000 重放 100% 确定 且 provenanceRisk 100% 拒入长期路径;唯一 admit 例外为 0.58 阈与连续性保护,无未记录 admit | HIGH |
| 39 | event_projection_replay_determinism | `BASMemoryAtomReducer.project` 须序稳且缓存等价:(a)同事件多重集 N=1000 随机序重放产逐字节同投影;(b)`.warmAtInit` 缓存投影==`.lazy` 读时投影(缓存是派生视图非并行源)。 | equal | 1000 随机序投影逐字节同 且 warm-cache==lazy;任何偏离即阻断(事件日志不再是有效真相源) | CRITICAL |
| 40 | event_log_sequence_monotonicity | 路由/SQLite 事件日志:每会话 seq 在 append 序严格单调增(lastReplayedSequenceNumber 不降),重复 eventID append 幂等(wasNew=false、不分新 seq、不重复 apply)。append 风暴测试。 | equal | 100% 每会话严格单调 且 100% 重复 eventID 幂等;热路径每轮经此,任何违反即阻断 | CRITICAL |
| 41 | projection_content_empty_on_replay | 纯从事件日志(无进程内 content 缓存)重建的原子 content 必空——私有经验只随 contentDigest、不进事件,跨进程重放不能重建原文。空缓存新 store 投影断言每原子 content==""。 | equal | 跨进程重放原子 100% content 为空(无原文泄漏);任何非空重放 content 即阻断(违不变量#3) | CRITICAL |
| 42 | forget_cascade_execution_correctness | `BASMemoryForgetCascadeRunner.apply` 须删恰好 memoryID∈(rootTargets∪dependentRefs) 的记录,保留其余记录及所有兄弟集合逐字节;终态∈{completed/skipped/failed}。属性测试+Rust 路由路径对 Swift 字节等价。 | equal | 精确删除(零过删+零欠删)且兄弟集合逐字节同,Rust 路由==Swift;任何不符即阻断(右-被遗忘执行器) | CRITICAL |
| 43 | kv_cache_eviction_determinism | `BASKVCacheLRUEvictor.decide`/`TTLEvictor.decide` 纯确定(同 ticks/时间戳+容量/ttl→同逐出/保留集,带 sessionID 平局),且 enforcement 后存活会话数不越容量、无超 ttlMs 者存活。重放确定+溢出/过期压测。 | equal | 100% 确定逐出 且 store/append 后 sessionCount≤容量(LRU) 且任何访问后 0 个 age>ttlMs 存活(TTL) | HIGH |
| 44 | sql_persistence_integrity_gate | 每个 L8 SQLite store 打开时(`runIntegrityCheckOnOpen`)`PRAGMA integrity_check` 须返 'ok' 否则打开抛错(完整性>可用性);user_version 须==schemaVersion,否则抛 schemaVersionMismatch(不静默覆盖)。注腐败+版本偏移测试。 | equal | 高保证启动跑 integrity_check 且非 'ok' 阻断打开;版本偏移恒抛 schemaVersionMismatch;腐败/错版本须浮现绝不截断 | CRITICAL |
| 45 | shared_wal_durability | L8 store 以 journal_mode=WAL、synchronous=NORMAL、wal_autocheckpoint=200 打开支持跨进程读。测:(a)kill -9 写中后重开干净且末次提交持久;(b)长写会话 WAL 有界。 | equal | kill-during-write 故障注入套件 0 腐败(重开 'ok'、末次写在) 且 WAL 有界;任何 shared-WAL 腐败即阻断 | CRITICAL |
| 46 | memory_tiering_band_non_collision | `BASMemoryTemperaturePolicy.recommendTransition` 每 profile 恰一个迁移、带不重叠:quarantine(敏感/污染≥0.75)短路;evictSuggest 仅 cold+stale(0.50<0.75);promote/demote 按 compositeHeat。网格断言单值、带一致、逐出仅经 forget-cascade。 | equal | 每 profile 恰一迁移、零带冲突(evictStaleness<quarantine 严格) 且 evictSuggest 不绕 forget-cascade(红线7 仅 hint);违反即阻断 | HIGH |
| 47 | silent_failure_observability | 不抛访问器(entry(forID:)/allEntries()/totalCount/atom(forID:))出错默认 nil/[]/0 前须先把底层 SQLite 错路由到 onSilentFailure,且有抛错兄弟以区分「不存在」与「坏了」;非空但不可解 metadata 须抛 decodeFailed。测出错分支发诊断/有抛错兄弟比例。 | up | 100% 不抛读路径出错分支调 onSilentFailure 且每默认访问器有抛错兄弟;非空腐败 metadata 抛错;「缺」恒可与「坏」区分 | MEDIUM |

---

## 五、L9 BASRuntimeCore 协调器 · 梦循环 · 14 层整轮装配 · 预算/红线强制 · 观测对账

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 48 | turn_replay_determinism | 把规范-60+扩展 fixture 经 `coordinator.runTurn` 跑两遍(并跨 V1/V2 引擎),用 `BASEBrainTurnResultReplayDigest`(sorted-keys UTF-8 JSON 的 SHA256)序列化 `BASEBrainTurnResult` 比 digest。测两/N 次 digest 相同的 fixture 比例。 | equal | 100% 逐字节同;任何一处偏离即阻断(ADR-014 opt-in / 红线7:每个 opt-in seam 默认字节等价 no-op) | CRITICAL |
| 49 | opt_in_seam_dormancy | 对每个 OPT-IN 标志(deliberationLoop/ssmCautionOperator/ssm·attentionMetalReasoning/ssmNeuromodulation)与每个 nil 默认载体(evidenceLedger/resolvedEvidenceSink/...),比默认路径 digest 与加入 seam 前基线 digest。测默认路径 digest==基线比例。 | equal | 100%;off 时扰动结果的 seam 违 ADR-014 须阻断;结构测试钉死:任何 opt-in 标志不得出现在 canonical-bytes/seal/hash/render 路径 | CRITICAL |
| 50 | budget_overrun_escape_rate | normalize 后断言:thoughtFrame.stepIndex≤maxLoops、candidates≤maxCandidates、memory.atoms≤retrievalDepth、maxLoops≥1、maxCandidates≥1。测 normalize 后仍违任一上限的轮数;每个 clamp 须发 enforced=true 的 `BASRuntimeAuditFinding`。 | down | 逃逸恰 0;clamp 触发而无 enforced finding=HIGH 缺陷 | CRITICAL |
| 51 | redline_permit_downgrade_completeness | 对抗风险语料(极端风险、gsiScore≥0.75、guard runMode、recommendedMode≠answer、forceProtectedPermit kill switch),断言 normalizeRiskDecision 永不在红线下留 `mode==.answer`,且每次降级发对应 enforced finding。测正确降级且发 finding 的红线轮比例。 | up | 100%;任何极端风险轮到达 `.answer`=CRITICAL(违不变量#2 神经不掌权) | CRITICAL |
| 52 | caution_monotonicity_optin_seams | deliberationLoop/ssmCautionOperator 触发的不确定事项轮,断言 boundRiskCard.totalRisk/riskLevel 相对 loop-off 同选基线只升不降(raisedTotalRisk≥c),assertionCeiling 不从 'guarded' 退回 'standard'。测降低任一风险标量或降 ceiling 的(轮,seam)数。 | down | 0 次降低(带 ADR-020 §9 carve-out:协同 reversibility-tilt 可选更安全更低绑定候选,另行验证) | CRITICAL |
| 53 | dream_loop_pass_count_vs_budget | deliberationLoop 下断言实际 pass 数==max(1,min(thermallyFlooredMaxLoops, stepIndex)) 且不越 routedBudget.maxLoops;热 .hot/.critical 时 floored≤1;遇终止 stopReason 早停。测超 targetPasses 或热临界跑>1 的轮数。 | down | 0 次超预算 且 0 次违热 floor;与 loop.max_loops_clamped finding 配对 | HIGH |
| 54 | dream_loop_stop_reason_reconciliation | 验证 reconcileDreamLoopConvergence+derivedDreamLoopStopReason:终止 stopReason 保留;guard 路径+延迟/弱/高敏/证据债≥0.5/延迟保留→.guardTakeover;主权断点 cut/stop→.blocked;变更时重建 certificate 并三我重合。测合成帧 stopReason 命中真值表比例。 | up | 真值表 100%;guard 路径选择轮在触发信号下不升 .guardTakeover=HIGH(循环静默接受欠护路径) | HIGH |
| 55 | observation_coverage_14layer | buildEBrainTurn 后把各层 ObservationBundle 投影为 `BASObservationCoverageSummary` 建对账报告,调 isFullyObserved(expected: 本轮实跑 14 层)。测完全观测(每期望层有 summary 且有 coreSignal)比例,报告 missingLayers/layersWithoutCoreCoverage。 | up | missingLayers(本轮实跑)==[](跑了却无观测=可审静默层异常);layersWithoutCoreCoverage=HIGH 警告(被杀/降级层可合法少报) | HIGH |
| 56 | observation_coordinate_coherence | 每层观测 bundle 共享严格相等 (sessionID,turnID)=frameContext;`dedupedAndFiltered` 丢 turnID/sessionID 不符的 summary 并每层至多一 summary。测跨轮/会话不符丢弃数+同层重复保留数。 | down | 主链 0 跨轮/会话不符(全经派生键) 且任何报告 0 同层重复保留(解码路径亦须守) | MEDIUM |
| 57 | audit_finding_enforcement_coherence | 交叉核对:每个 enforced=true 的 finding 对应真实预算/记忆/思维/风险/permit 帧变更,且每次 clamp/降级恰发一 finding;走 console blocker 对账。测(enforced 无变更)+(变更无 finding)+(blocker 无支撑)数。 | down | 幻象 finding==0 且未记录强制==0;静默强制或幻象 finding 都腐蚀可审计性 | HIGH |

---

## 六、L10 BASOrchestration · 提示契约 · 道调度 · 三我庭 · 工作流检查点

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 58 | prompt_injection_filter_catch_rate | 带注入标记(19 个 suspiciousMarkers+`markupRegex`)的证据片占 `BASPromptEvidenceGuard.filter` 归入 droppedInjectedCount 的比例,对标注对抗语料(种入 evidenceSnippets);droppedInjectedCount>0 时须发 guard 行。 | up | 标记语料 recall=1.0(漏 `<tool`/``` ``` ``` 即阻断);良性语料误报率 ≤1% | CRITICAL |
| 59 | prompt_budget_suffix_floor | 每个编译信封,volatile 后缀至少得 suffixFloorCharacters(即便 targetCharacters−stablePrefix 更小)。重算 suffixTargetCharacters 并断言信封后缀长 ≥suffixFloorCharacters(kind×length sweep)。 | gate | 后缀<floor 的信封==0;任何违反=提示契约破裂(用户 volatile 区被超大 prefix 饿死) | HIGH |
| 60 | admission_lane_decision_determinism | `BASExecutionGovernance.admissionDecision(for:)` 须为 `BASAdmissionRequest` 的纯函数。每请求跑两次(并跨进程重启)字节比 `BASAdmissionDecision`;压力带边界精确(<0.55 low/<0.85 elevated/≤1.0 high/else severe)。 | gate | 100% 跨重复/跨重启同决策;压力带在 0.55/0.85/1.0 精确切点通过;任何偏离=非确定调度器 | CRITICAL |
| 61 | lane_skip_reason_soundness | 每次准入拒绝带非 nil 的 `BASAdmissionSkipReason`,且每个 skipReason 由请求字段证成(如 insufficientChoiceSpread⟺candidateCount<2)。oracle 逐拒绝请求重导谓词数不符。 | down | 不符==0:0 例 isAllowed==false 而 skipReason==nil,0 例 skipReason 与字段矛盾 | HIGH |
| 62 | workflow_checkpoint_rewind_fidelity | `BASWorkflowState.rewind(to:)` 后 (status,currentNodeID) 须恰等目标 checkpoint,且 checkpoints 截到 prefix(index+1);brainState 逐字节等于捕获时。属性测试:建 N 个、随机回退、断言相等+尾截断+未知 ID 返 false 不改状态。 | gate | rewind 对每个可达 checkpoint 重现(status,nodeID,brainState) 且 0 个目标后 checkpoint 幸存;未知 ID 返 false | HIGH |
| 63 | entry_plan_approval_coverage | `BASWorkflowState.plan(for:)` 须在 riskLevel==.high 或 entryKind==.reopen 时把 approvalRequirement 升 .manual。跨 `BASIntentEnvelope` 全积(entryKind×surface×riskLevel)断言匹配规范表。 | gate | 高风险或 reopen 计划 approvalRequirement==.none 的数==0(高风险静默自批=主权破裂) | CRITICAL |
| 64 | tribunal_full_body_coverage | 重大裁决轮中 `BASTribunalCoverageReport.isFullBody`(base/rule/aspire 各 ≥1 观测)为真的比例;committing `BASMergedChoice` 的轮 silentVoices 须空。 | up | 任何对高风险动作产非否决 MergedChoice 的轮 isFullBody 须真(silentVoices==∅);重大轮聚合 full-body 率 ≥0.99;重大轮空庭=阻断 | CRITICAL |
| 65 | tribunal_veto_monotonicity | 若任一 `BASVetoMark`(compensable==false)或 `BASCourtVetoType`∈{boundary,dignity,hostConstitution,irreversibility,sovereignPrecondition} 被举,则 `MergedChoice.vetoApplied` 须真且该候选不得为 preferredCandidateID。重放计票携不可补偿否决却被选/提交的候选。 | down | 0 个携不可补偿否决的已提交候选;否决底线只收紧(下游可加否决,绝不清不可补偿者) | CRITICAL |
| 66 | release_consistency_gate | 附 `BASStructuredTruthState` 时,`BASCognitionKernel.releaseDecision` 对含 {modeMismatch,forbiddenAction,factConflict} 的输出须返 .reject,其余不一致返 .repair(非 .allow)。标注语料数:reject 类违规却 .allow 逃逸的输出。 | down | 0 例 reject 类一致性违规以 .allow 逃逸;无 truth-state 路径默认 .allow 须单独标记(见 truth-state attach 率) | CRITICAL |

---

## 七、L11 BASPolicy · 边界/策略强制 · permit 升级 · 风险校准

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 67 | policy_decision_determinism | `BASPolicySet.decide(...)` 须为(enforcementPoint,actionClass,riskLevel,scope,sensitivity,cloudRequested)的纯确定函数,恒返 {allow,requireConfirmation,deny} 且 reason/matchedRuleIDs 充实。按每 preset 穷举双评确定性,断言 deny 优先(blocked scope/sensitivity→deny 主导)。 | gate | 100% 确定;deny 优先成立;每决策带非空 reason;0 未处理输入元组 | CRITICAL |
| 68 | cloud_egress_sovereignty | 任何 localOnly/localFirst/childSafe profile 下,被 allowCloud==false 规则治理的 actionClass 在 cloudRequested==true 时不得 .allow(须 .deny);无匹配规则时 cloudRequested&&risk≥.medium→.requireConfirmation。数泄入 cloud 的 allow。 | down | 无云规则下 cloud-allowed==0;无规则回退下 medium+ 云请求自动 allow==0(隐私/主权硬线) | CRITICAL |
| 69 | permit_escalation_never_loosen | 规范 5 阶链(abyssal→assertionCeiling→kunlun→cthulhuAssertionCeiling→cthulhuEscalation)经 `BASPermitEscalationFoldExecutor.fold`,permit 限制性须非降:ceiling 只收窄,到 .block/.escalate 的 mode 不得退回 .answer。按限制性格断言每条 ledger outputPermit≥inputPermit。 | gate | 0 阶松动(扩 ceiling/掉 require* 标志/降 mode);每次 cap 须发稳定 reason code(无静默 cap) | CRITICAL |
| 70 | permit_escalation_ledger_replay | 同 initialPermit+同步骤闭包,`BASPermitEscalationLedger` 须 Equatable 跑间同;records.count==5 恰覆盖 canonicalOrder 一次;每 record.fired 正确;finalPermit==records.last.outputPermit;aggregateReasonCodes 阶前缀。 | gate | 跨重跑逐字节同 ledger;records 恰按序覆盖 5 阶;firedStageCount 匹配实变阶数;任何缺/乱/重阶=审计链腐败 | HIGH |
| 71 | risk_calibration_replace_safety | `BASRiskCalibrationGate.replace(_:)` 须拒(typed ReplaceError、bundle 不变)畸形(缺 version/provenanceRef/sovereignWarrantRef)、bundleVersion 非单调、断 supersedes 链的提案。对抗 bundle 套件数:被接受的不安全替换;确认被拒后 currentBundleVersion 不变。 | down | 不安全替换接受==0:回放旧/等版→nonMonotonicVersion;缺 warrant→malformedBundle;supersedes≠current→supersedesMismatch(仅轮间替换) | CRITICAL |
| 72 | risk_calibration_delta_bound | 每施加的 per-stratum delta 须在 ±0.25 帽内,每个 effective<Tier>Threshold 返 base+delta clamp 到 [0,1](NaN→0)。极端/NaN delta sweep 断言输出∈[0,1] 且缺 stratum 返 base。 | gate | 所有 effective 阈∈[0,1];无单 delta 超 ±0.25;缺-stratum 查为恒等;失控 delta 腐蚀 L11 闸=阻断 | HIGH |
| 73 | risk_card_monotonic_ordering | 风险评分须单调:level 升(low<medium<high<extreme)时同 hazard 输入 totalRisk 非降,.extreme 卡须荐保护模式(非 .answer)。分级 hazard 向量 sweep 断言 level/score 单调+recommendedMode 限制性非降;校准以 Brier/ECE 报告。 | gate | 分级 sweep 0 单调倒置;每张 .extreme 卡荐非 .answer 保护模式;标注轮 ECE ≤0.10(status 不得 'fail') | HIGH |

---

## 八、L12 BASObservability · 追踪/重放 · 审计篡改证据 · 遗忘门

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 74 | replay_fingerprint_determinism | `BASObservabilityInspector.replayFingerprint(for:)` 是对 `BASReplayBundle`(trace+brainState+runtimeContext+policyDecision+disposition)的 sorted-keys SHA256。同 bundle 跨运行/进程/架构须同哈希,任何字段变须改 digest(雪崩)。跨进程 rehash + 单字段变测试。 | gate | 同 bundle 跨进程/架构 100% 同指纹;每单字段变翻 digest(变体套件无碰撞);载荷变下 digest 稳=重放保真失败 | CRITICAL |
| 75 | replay_disposition_forget_vault_gate | `replayDisposition(for:)` 须在已验证 forget 撤销 checkpoint/导出、或 vaultConsistencyState∈{revocation_pending,out_of_sync,migration_pending} 时标 isAvailable=false 并浮现 high 级异常。测仍报可用的撤销/不一致用例数。 | down | 0 例 forget-已验证+撤销或 vault 不一致仍报 isAvailable=true;须有 high 异常信号+非空 blockerSummary(右-被遗忘/五级删除完整性) | CRITICAL |
| 76 | trace_release_mismatch_coverage | 每个已发布轮产 `BASInspectionBundle`,其 `BASExecutionTrace` 录全消费面,anomalySignals 在不变量上触发(release_mismatch:.deny 却非空输出;tool_timing_gap;latency_spike≥5000ms;duplicate_memory_recall)。测有非 nil bundle 且无静默违规的已发布轮比例。 | up | inspection-bundle 覆盖=100% 已发布轮;发布时 release_mismatch==0(拒却产出=阻断);对 oracle 0 漏报 | HIGH |
| 77 | per_layer_latency_overrun | 给 runTurn 14 层各装 wall-clock,逐层用 `exceededBudget(...)` 比声明预算;测每层超预算轮比与 p95/p99(按设备类)。只读,不中止轮。 | down | 每设备类(warm)整轮 p95 ≤latencyBudgetMs;每层 p95 超预算率 ≤5%;L3-L7 路由层 p95 须低于更慢竞品基线 | HIGH |

---

## 九、L14 BASSovereign · 裁决完整性 · 审计账本 · 链封确定性 · token 权威 · 杀停恢复

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 78 | verdict_kernel_determinism_noncompensatory | 纯规则内核 `evaluateLevel(_:useRouted:)` 确定且非补偿:(a)同 VerdictContext→同 LevelDecision(跨重复与 useRouted∈{true,false});(b)§12.2 顺序中首个 band==.high 的软域钉死等级。≥1000 脚本上下文断言字节等 LevelDecision 与字典序钉死。 | gate | 100% 确定 且全 fixture 证非补偿;低优先信号抵消高优先即阻断(ADR-024 唯一主权裁决权威) | CRITICAL |
| 79 | verdict_hardrule_min_level_floor | 各 BR-001..012 观测集孤立时,evaluateLevel 须返 ≥该规则文档 minLevel 的等级,并在 reasonCodes 发 BR 码+对应撤权集;含 routed-vs-Swift 交叉核(max(hits.minLevel, routedLevel))。逐规则表测试。 | gate | 每 BR 规则产 ≥其 min 且精确撤权集;规则跌破 floor、或 routed 路径低于 Swift hits-floor 即阻断 | CRITICAL |
| 80 | rust_swift_verdict_parity | 生产 routed Rust 路径(`BASAutoRouteRanker.verdictDeriveLevel`)与参考 Swift Stage-2+3 逐字节平价。穷举/大 fixture(12-bit hardBits×量化软信号格×6 域×evidence∈{0,1})断言 rust 等级==swift,且 routedDeriveLevel 对合法输入永不 nil。 | gate | 冻结 fixture 0 排名分歧(ch742 字节等价钉死须仍成立)且 0 伪 nil;任何分歧阻断 routed 默认(13.84× 仅在字节等价时可采) | CRITICAL |
| 81 | verdict_parity_shadow_laxer_halt | `BASSovereignTurnVerifier.parity` 须把协调器比引擎更宽松的轮归 `.coordinatorLaxer`(会话停信号)。(1)穷举 parity 对全 8×9 等级/nil;(2)语料中每个 .coordinatorLaxer 轮对应真实 coordinator<engine 且触发 isAcceptable==false。 | gate | parity() 映射穷举正确 且每个 .coordinatorLaxer 轮停会话;宽松轮被当可接受溜过即阻断(ADR-022) | CRITICAL |
| 82 | ledger_fail_closed_on_append | `BASSovereignAuditLedger.append` 抛错时 `BASSovereignVerdictEngine.evaluate` 须重抛 `EngineError.auditAppendFailed` 且不返裁决。注入 append 抛错的 ledger stub(missingSigningSecret/quarantined/signatureMismatch/schemaVersionBelowFloor)断言 evaluate 抛错、无裁决逃逸。 | gate | 100% append 失败致 evaluate 抛错;0 裁决无持久账本条目发出;裁决越过 ledger 写失败即阻断(BR-012 红线) | CRITICAL |
| 83 | chain_seal_determinism_byte_equal | 哈希链封确定且单射:(a)固定 entry+priorHash+namespace 时 selfHash 与 HMAC 签名跨重复、跨 legacy vs routed-seal 路径逐字节稳;(b)1.2.0 长度前缀 canonical 单射——含带内 U+001F/U+001E 分隔符的 ref 语料无两条产同 canonical。re-seal 重复+对抗 ref 碰撞搜索。 | gate | selfHash/sig 跨路径逐字节 且 schema 1.2.0 下 0 canonical 碰撞;碰撞(两条→一签名前像)即阻断(ch1044 D2 单射) | CRITICAL |
| 84 | chain_tamper_detection_coverage | `verifyChainIntegrity()`/`auditChainFull()` 测每类内部篡改。在已封 N 条链上变异:翻中条字段、无密钥重哈希、改写 priorHash、交换两条、删中条、降 schemaVersion。各断言抛 chainIntegrityBroken 指对 lastVerifiedAuditID 且 auditChainFull 报精确原因。 | gate | 100% 内部篡改检出(无密钥重哈希仍败于密钥签名核);尾删+合法前剪记为容忍(无误报);任何未检内部篡改即阻断 | CRITICAL |
| 85 | ledger_quarantine_on_corrupt_reload | 冷启时完整性>可用性:重载持久链 verify 失败须置 integrityQuarantined=true 并拒后续 append(invalidEntry 'ledger quarantined…')。持久→篡改盘字节→重载,断言 isIntegrityQuarantined==true 且 append 抛错;干净重载不隔离。 | gate | 腐败重载→隔离 且 append 被拒(0 次接受到伪历史) 且干净重载不误隔离;把伪历史当可追加即阻断(ch1044 A2) | CRITICAL |
| 86 | append_only_no_mutation_surface | 结构不变量:账本除 append+主权批准的 LINEAGE_CUT/rotate(五级删除)外无公共变更/删除 API。(a)API 面审计:公共方法集无 delete/update/clear;(b)运行时 K 次 append 后 count() 单调非降,query 只逐字节返既有;priorHash[i]==selfHash[i-1](或 GENESIS)。 | gate | 0 个公共变更/删除方法;count() 仅经带自身审计链的 LINEAGE_CUT/rotate 才减;任何原始删/覆盖路径即阻断 | HIGH |
| 87 | commit_token_single_use_burn | `BASSovereignTokenAuthority` 从 SERVER 记录(record.redeemed)而非攻击者可改的 token.singleUse 强制单用。(1)redeem 一次成功、二次抛 alreadyUsed;(2)singleUse 翻 false 但 record.redeemed==true 仍 alreadyUsed;(3)nonce 重用抛错;(4)sig/scope/actionDigest/policyHash/TTL 各不符对应抛。 | gate | 已兑 token 永不再被接受(不论携带标志);nonce 无碰撞;每凭据字段不符抛错;成功重放或标志降级即阻断(ch1044 replay-bypass 类) | CRITICAL |
| 88 | commit_enforcer_digest_target_binding | `BASSovereignCommitEnforcer.authorize` 须拒:(a)不在 token 签名 allowedTargets 的 target(别名攻击,签名前即 targetNotAllowed);(b)调用方重算 expectedActionDigest 异于签名 actionDigest(授权-执行间篡改)。语料:别名 target→抛;变体 artifact→actionDigestMismatch;匹配→恰一成功并烧 token。 | gate | 0 次对非白名单 target 或 digest 不符授权;每个合法(token,body)恰一成功并烧;对篡改 body 或别名 target 执行即阻断(ch1044 A1) | CRITICAL |
| 89 | dual_key_two_principal | `BASSovereignDualKeyVerifier.verify` 在 primaryKeyID==secondaryKeyID 或两公钥逐字节同(退化同钥)、任一 keyID 槽不符注册、任一 Ed25519 签名败时须返 false。真值表:合法 2 钥→true;各退化/不符/伪签→false;makeCommit 重复 keyID 抛 sameKeyIDForBothSlots。 | gate | verify 仅在两 keyID+钥皆异且两签皆验时为 true;同主体或单有效签名 commit 恒 false;静默降级双钥→单主体即阻断 | HIGH |
| 90 | ed25519_cross_verifier_no_secret | Ed25519 签名的账本条目须经静态 `verify(_:publicKey:signingNamespace:)` 仅用公钥验过,并在错 namespace/错公钥/篡改签名时败。导出 AppendedEntry+publicKey 到进程外验证器,断言对则收、各篡改则拒、无私钥在场。 | gate | 跨进程仅用公钥收每条真条目并拒 100% namespace/钥/签名篡改;需私钥或收错 namespace 签名即阻断 | HIGH |
| 91 | rollback_target_known_good_anchor | `BASSovereignCleanRebootCoordinator.planReboot` 对 .rollback/.deadStop 须选最近 isKnownGood 且有绑定快照锚的祖先,且仅 .rollback 设 bootstrapNextSession=true(deadStop→haltAndAwaitHostIntervention)。版本树 fixture 覆盖各情形。 | gate | 100% fixture 选对 known-good+anchored 目标与动作序;deadStop 永不自举;回退到非 known-good 或未验锚即阻断 | CRITICAL |
| 92 | restore_payload_hash_gate | `BASSovereignSnapshotManager.verifyRestore` 须在载荷 SHA-256≠注册哈希时抛 payloadHashMismatch;注册须拒声明哈希≠计算(hashBindingMismatch);任何失败经 markBrokenIfNeeded 升 BR-004。匹配→过;单字节变→抛;错声明哈希→拒;未知锚→unknownAnchor。 | gate | 0 次接受哈希异于封存的载荷恢复;每次 verify 失败下一裁决升 BR-004;恢复未验字节即阻断 | CRITICAL |
| 93 | integrity_sentinel_unknown_is_failure | `BASSovereignIntegritySentinel.scan` 须把未知 artifact id(无注册指纹)与哈希不符都当失败,把 failedKinds 映对应 HardObservations 位(→BR-001/006/002/007)。扫描语料:未知 id→failed;匹配→clean;每 kind→正确位。 | gate | 未知/不符 artifact 恒 fail-closed 并映文档 BR 位;干净注册匹配不误败;未知 artifact 当「完整性 OK」即阻断(绕 BR-01) | HIGH |

---

## 十、CROSS-CUTTING · 治理 / 确定性边界 / 评估回归与漂移 / 构建测试健康 / 设备耐久与 wedge 鲁棒性

| # | 指标 | 定义/怎么测 | 方向 | 门槛/Gate | 级别 |
|---|------|------------|------|-----------|------|
| 94 | regression_gate_verdict | 每个发布候选评估套件跑 `BASEvaluationSuite.gate(candidate:baseline:tolerance:)`,产 status∈{pass,warn,fail}:fail 当 candidate+tolerance<baseline。记录裁决+(candidate,baseline)。 | gate | fail 阻断发布;warn 需签名 operator override;默认 tolerance=0.05,SovereignVerdict 类套件 tolerance 须=0.0(零回归) | CRITICAL |
| 95 | byte_determinism_spine_replay | 在同输入上把字节确定 spine(risk→permit→verdict→commit-token、durable write、event-log、replay)跑两遍,diff(verdict, durable-write 字节, replay digest)。 | gate | 逐字节 100% 相等;任何一 bit 偏离阻断;无 Metal/GPU 浮点原始跨入 spine(须过 snapToDeterministic 并发 BASBoundaryCrossingRecord) | CRITICAL |
| 96 | metal_spine_boundary_tripwire | 构建期 `BASMetalDeterminismBoundaryTests` grep 每个字节确定 spine 文件,引用 Metal 调度器/`BASApproxValue`/`approximateOnly`(非白名单)即失败;且 checked-count==spineFiles.count(每个白名单文件在场)。每次 snapToDeterministic 跨界发 BASBoundaryCrossingRecord 作纵深防御。 | gate | tripwire 须绿、spine 内非白名单 Metal 引用==0、白名单文件全在场;新 spine writer 须显式更新白名单(漏洞=失败闸非静默通过) | CRITICAL |
| 97 | schema_governance_parity | `check_whitepaper_schema_parity.sh` diff 每个 `public struct BAS*: BASSchemaVersioned` 对 `BASEBrainSchemaGovernanceRegistry.governedSchemas`。测「已声明但未注册」的 schema 数(M89/M94 ship-without-register 类,当前 ~190+ 治理 schema)。 | gate | 未注册 schema 数==0;退出 1(漂移)阻断;每个新 BASSchemaVersioned 须原子加治理条目+正反向迁移测试 ID | CRITICAL |
| 98 | cross_language_schema_alphabet_parity | `check_chenglu_schema_parity.py` 解析 Swift `ChengluFeatureEncoder` 与 Python `chenglu_feature_schema.py`,精确等价核对特征字母表(数量、顺序、值);漂移会使训练好的 .mlpackage 在推理时预测垃圾。 | gate | 字母表数量/顺序/值须匹配(ADR-005);任何差异 CI 失败;加特征/语气须同 commit 改两语言 | CRITICAL |
| 99 | authoritative_test_suite_pass | 跑权威 headless 闸 `swift test --disable-swift-testing`(XCTest 半为可靠闸,swift-testing 半在 headless 满载会 SIGBUS——环境非代码缺陷)。记录 passed/failed/skipped;基线 15,015 测试/101 skip/0 fail;绝不把 swift test 经 tail 管道。 | gate | XCTest failures==0;总数须 ≥基线 15,015(数量下降=静默删/skip 覆盖);单体 swift test 退出码不作闸(其 1 仅因已知 SIGBUS) | CRITICAL |
| 100 | mlx_wedge_prevention_compliance | ADR-038 证同步 MLX/Metal eval 持有线程至 GPU 返回——任务无法取消、per-turn 超时被移除(teardown 会挂)。任何 wedge-prone 同步 eval 须配预防(cacheLimit 修复、opt-in、macOS 默认 off)+外部看门狗,绝不进程内取消/超时。测依赖被禁机制的 eval 站点数。 | gate | 依赖进程内超时/取消保 wedge 安全的 MLX/Metal 站点==0(ADR-038 禁);每 wedge-prone 路径须有 CPU/Rust 回退+外部看门狗;wedge 预防绝不仅凭 macOS-green 认证,须设备验证 | CRITICAL |

---

## 发布门(CRITICAL 全过才发)

以下 CRITICAL 级 Gate 必须 **全部通过** 才允许发布;任何一条不过即 **BLOCK**。它们守护衬底的四条红线:确定性可重放、神经不掌权、私有经验不外泄、主权裁决与审计链不可伪造。

**L1 租约/散热(杀停权威)**
- #1 thermal_guard_mapping_purity — guard 映射纯且全覆盖
- #2 emergency_cancels_all_breaths — emergency 取消全部 breath、无孤儿唤醒
- #3 throttle_class_admission_correctness — 零误放被禁维护类
- #6 emergency_forces_cpu_route — emergency 强制 CPU 路由

**L2 神经组织/边界(数值保真 + 确定性边界)**
- #8 metal_vs_cpu_ssm_scan_parity — kernel MAE ≤1e-5,设备 0.000000
- #15 prompt_lookup_spec_token_identity — 贪婪解码 token 逐一致(N/N)
- #19 coreai_ane_conversion_fidelity — ANE 转换 argmax 24/24 + KV-write guard

**L8 记忆(真相源 + 隐私 + 右-被遗忘)**
- #32 durable_cosine_topk_recall — Float32 路径 recall@k==1.000
- #35 non_finite_embedding_rejection — NaN/Inf 单原子 DoS 零容忍
- #37 governed_excluded_domains_adherence — 排除域 0 泄漏(不变量#2)
- #39 event_projection_replay_determinism — 投影逐字节可重放
- #40 event_log_sequence_monotonicity — seq 严格单调 + 幂等
- #41 projection_content_empty_on_replay — 重放 content 全空(不变量#3)
- #42 forget_cascade_execution_correctness — 精确删除、零过删/欠删
- #44 sql_persistence_integrity_gate — integrity_check 阻断腐败打开
- #45 shared_wal_durability — kill-during-write 0 腐败

**L9 协调器/整轮(确定性 + 红线强制)**
- #48 turn_replay_determinism — 整轮 100% 逐字节重放
- #49 opt_in_seam_dormancy — opt-in seam off 字节等价
- #50 budget_overrun_escape_rate — 预算逃逸恰 0
- #51 redline_permit_downgrade_completeness — 极端风险绝不到 .answer
- #52 caution_monotonicity_optin_seams — 谨慎只升不降

**L10 编排(注入防御 + 三我庭 + 一致性)**
- #58 prompt_injection_filter_catch_rate — 标记 recall=1.0
- #60 admission_lane_decision_determinism — 准入决策确定
- #63 entry_plan_approval_coverage — 高风险/reopen 不自批
- #64 tribunal_full_body_coverage — 重大轮全体到庭
- #65 tribunal_veto_monotonicity — 不可补偿否决永不被选
- #66 release_consistency_gate — reject 类一致性违规不逃逸

**L11 策略/风险(主权出口 + 校准安全)**
- #67 policy_decision_determinism — 策略决策确定、deny 优先
- #68 cloud_egress_sovereignty — 无云规则下 0 cloud-allowed(隐私硬线)
- #69 permit_escalation_never_loosen — permit 限制性只升不降
- #71 risk_calibration_replace_safety — 0 不安全校准替换

**L12 可观测性(重放保真 + 遗忘门)**
- #74 replay_fingerprint_determinism — 重放指纹跨进程确定
- #75 replay_disposition_forget_vault_gate — 撤销/不一致态 0 误报可用

**L14 主权(裁决 + 审计链 + token 权威)**
- #78 verdict_kernel_determinism_noncompensatory — 唯一裁决内核确定非补偿
- #79 verdict_hardrule_min_level_floor — 每 BR 规则不跌破 minLevel
- #80 rust_swift_verdict_parity — routed Rust==参考 Swift,0 分歧
- #81 verdict_parity_shadow_laxer_halt — 协调器更宽松→停会话
- #82 ledger_fail_closed_on_append — append 失败→不发裁决(BR-012)
- #83 chain_seal_determinism_byte_equal — 链封确定且单射、0 碰撞
- #84 chain_tamper_detection_coverage — 100% 内部篡改检出
- #85 ledger_quarantine_on_corrupt_reload — 伪历史不可追加
- #87 commit_token_single_use_burn — token 单用、无重放
- #88 commit_enforcer_digest_target_binding — digest/target 绑定、无别名/篡改授权
- #91 rollback_target_known_good_anchor — 仅回退到 known-good+已验锚
- #92 restore_payload_hash_gate — 0 未验字节恢复

**Cross-cutting(确定性边界 + 治理 + 构建健康 + wedge 鲁棒性)**
- #94 regression_gate_verdict — 候选不跌破基线(主权类 tolerance=0)
- #95 byte_determinism_spine_replay — spine 逐字节可重放
- #96 metal_spine_boundary_tripwire — spine 内 0 非白名单 Metal 引用
- #97 schema_governance_parity — 0 未注册 schema
- #98 cross_language_schema_alphabet_parity — Swift↔Python 字母表匹配
- #99 authoritative_test_suite_pass — XCTest 0 失败、计数不退
- #100 mlx_wedge_prevention_compliance — 0 进程内超时/取消保 wedge
