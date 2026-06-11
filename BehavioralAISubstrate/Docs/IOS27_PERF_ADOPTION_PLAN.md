# iOS 27 性能更新全量采用计划 (2026-06-11)

> 操作者指令:将 iOS 27 性能相关更新「能用上的全部」纳入开发计划。
> 方法(R1 铁律):训练数据早于 iOS 27 SDK,因此**全部候选以磁盘 SDK 头文件为唯一真相源**
> (iPhoneOS27.0.sdk,逐项 path:line 可用性标注),48 项候选经 find→对抗验证(49 agent),
> 47 项确认、1 项否决;WWDC26 公开口径仅作命名/语境佐证,不作依据。
> 完整证据记录:本文件各项的 SDK 锚点;原始清点输出归档于会话工件。

## 0. 结构性决定

1. **部署底座不动**:`Package.swift` 保持 `.iOS(.v18)`。一切 iOS 26/27 API 走
   `#available` 双车道 + 默认关旗标(ADR-014 字节相等)。两台认证 iPhone Air 已跑
   iOS 27.0 — 探针与车道今天就能在真机出证据。
2. **裁决工作负载事实**(决定了下面每一条 adopt/decline):
   - MLX decode ≈ 99% turn 时间;**逐 token 生成走 qmv GEMV,带宽受限**;
     vendored MLX 的 NAX 硬件张量车道(`quantized.cpp:694` gen≥17 门)**只覆盖 prefill qmm**。
   - Apple 自家 M5 数据与此一致:prefill 3.3–4.1×,**token-gen 仅 1.19–1.27×**(带宽墙)。
   - CoreML 双头 `.cpuOnly` 亚毫秒(T1.2 实测裁决);**CoreML 在 iOS 27 零性能新 API**(负发现,已扫尽)。
   - jetsam 单进程上限实测 3376MB(预算 3000MB)。
3. **门纪律不变**:观察先行;每条车道默认关=字节相等;门发建议、人读裁决、永不自动晋升;亏的不要。

## Tranche A — 采纳(4 项,全部门控)

| # | 项 | SDK 锚点 | 形状 | 量级 |
|---|---|---|---|---|
| A1 | **MSL 4.1 编译梯级** | `MTLLibrary.h:224 MTLLanguageVersion4_1 ios(27.0)` | MLX `get_metal_version()`(vendor patch,现有补丁类)+ `BASMetalKernelLibraryLoader` 加 "iOS 27→4.1" 一行可用性梯级。纯使能件:解锁 `__HAVE_TENSOR_MULTIPLANE__`/tensor-ops 编译面,为任何未来张量车道铺地。门:现有 kernel 平价夹具全绿(数值应逐位不变)。 | S |
| A2 | **MPSGraph 未弃用 — 记录免改造** | 27.0 全头文件 grep:**零**新增 API_DEPRECATED | 写入 ADR-039:6 个内建 MPSGraph kernel + Swift/C++ 双执行缓存**本周期无需迁移** Metal-4 ML encoder;Metal-4 互操作可增量叠加。附 watch:`convertLayoutToNHWC` 自 26.4 默认 no-op(conv 路径换形为编译期行为)。 | S |
| A3 | **MetricKit 字段证据栈** | swiftinterface `:1184 MetricManager`(AsyncSequence)`:584 PeakMemoryMetric` `:608 SuspendedMemoryMetric` `:806 BackgroundTerminationMetric` 均 iOS 27 | 新 `BASFieldMetricsCollector`(BASAppleAdapters + DeviceTestApp 消费):OS 认证的内存高水位/挂起内存/前后台终止计数/MemoryExceptionDiagnostic → JSONL 证据面。**用 OS 真相验证或证伪 3000MB 预算 vs 3376MB 实测上限**。纯观察,永不入摘要前像。 | M |
| A4 | **BGTask 异步提交** | `BGTaskScheduler.h:143 submitTaskRequest:completionHandler: ios(27.0)`;旧同步 submit 已弃用(:108) | `AppleBGTaskSchedulerBridge.submitProcessingRequest` 加 `#available(iOS 27)` 分叉:去掉跨进程同步往返 + 拿到此前被吞的提交错误(喂 BASBreathScheduler 记账)。 | S |

## Tranche B — 探针(证据先于一切车道;P0 是钥匙)

| # | 探针 | 决定什么 | 量级 |
|---|---|---|---|
| **P0** | **turn 相位切分计量**:endurance runner 给 MLX 调用加 prefill-ms / decode-ms 计数,逐 turn 记录占比 | **整个被否决的 Metal-4 量化家族的重开钥匙**:prefill 占比若实质(参考阈 ≥15–20%),NAX/MPP/MTLTensor 车道全部重审;占比小则否决以证据封存 | S |
| P1 | **MPSGraph→MTL4 队列 A/B**:`MPSGraphExecutable.h:195/211 run(on: MTL4CommandQueue) ios(27.0)`,对 6 个内建 kernel 测 per-evaluate 提交开销(微秒级 kernel,CPU encode/commit 占大头) | 是否给执行缓存加 MTL4 派发车道(旗标默认关;派发路线在决策脊柱里 — 必须 ADR-014 门控) | M |
| P2 | **ANE 再基线**:重跑 BAS_ANE_PROBE(零代码)— CoreML planner 在 OS 侧,iOS 27 运行时可能静默改放置 | T1.2 裁决(零 ANE 放置 / .all 14× 慢)在 27 运行时下是否仍立 | S |
| P3 | **BGContinuedProcessingTask**(`BGTask.h:127 ios(26.0)`,SubmissionStrategy Fail/Queue):T3.1 巩固的"保证开窗"车道 — 重会话结束→受保证的后台窗,替代 OS 可能永不授予的机会窗 | 是否给 BASSleepConsolidationDriver 加第三驱动路径(注意:要求可见进度 UI;Info.plist 通配标识符) | M |
| P4 | **+ GPU 资源**(`BGTaskRequest.h:129-130 Resources.gpu ios(26.0)` + `supportedResources`):受权后台 GPU 窗 | MLX 依赖型维护(嵌入刷新、prompt-cache 预热)能否离前台跑(ADR-039 隔离照旧:后台 GPU 产物仅 reasoning-side) | M |
| P5 | **FoundationModels 系统模型**(swiftinterface `:1178 LanguageModel` 协议 + Executor + `prewarm(model:transcript:)` iOS 27):ANE 驻留系统模型跑 T3.1 巩固摘要/打标 | 功耗/热维度:批量文本工作从 GPU/MLX 移到 ANE 是否净赢(输出非确定 → 默认关可选车道,仅 reasoning-side;Apple Intelligence 设备门) | M |
| P6 | **vm_statistics64 rev4-6**(`mach/vm_statistics.h:218 swap_count` `:254 donated_count`):bas_memory_pressure.c 增挖 App Swap 信号 | 压力阈值(>80% 天真比率)能否升级为换页真相。**坑**:27 SDK 重编译使 HOST_VM_INFO64_COUNT 长到 REV6 — 必须显式传 count 保旧内核兼容 | S |
| P7 | **StateReporting 相位标注**(`StateReporting swiftinterface:62 StateReporter` iOS 27):decode/rerank/consolidation 相位 transition 上报,MetricKit `byStateReportingDomain` 归因 | A3 的字段证据能否按相位归因(热/内存成本归到哪个相位)— 锐化 L1 租约决策 | S |
| P8 | **OutputSpan 数组构造**(stdlib `:1223 Array.init(capacity:initializingWith:)` — **iOS 12.2 可用,无底座问题**):L8 corpus flatten(N×D Float 逐 turn 重建)微基准门 | 检索车道分配开销;明确**不碰** canonical-bytes 脊柱 | S |

## Tranche C — 观察哨(零开发,挂触发器)

- **W1 CoreAI.framework**:27.0 新增、当前为空壳(9 行 swiftinterface,`@_exported import CoreAIDelegates`,v3600.67.4)。每个 27.x seed 重扫 — 这是 post-CoreML ANE 委托故事最可能落点。
- **W2 MLX 上游 Metal-4 后端**:Apple 研究文宣称 MLX 走 TensorOps/MPP 达 Neural Accelerators;上游 issue #2693 未见合并。vendor refresh 时核查 — **上游若出 tensor-ops GEMV(decode 路径),大否决项立即重开**。
- **W3 Xcode 27 工具链**:Instruments Top Functions / Processor Trace / metalperftrace / Metric Goals — 开发流程采用,无仓库代码变更。
- **W4 iOS 27 CPU 调度器重做**(二手来源,未见 Apple 原文):endurance 时序基线若漂移,先查此因。

## 否决记录(亏的不要;每项挂重开触发器)

1. **Metal-4 量化家族**(多平面 MTLTensor + 块缩放 MPP matmul2d + fp8/fp4 MPS dtype + MTL4 ML encoder + MLX 全管线 Metal-4 迁移;效应量 M–L):
   decode 是带宽受限 GEMV,多平面张量搬运的字节数不变;NAX prefill 车道 vendored MLX 已有。
   **重开**:P0 显示 prefill 占比实质 / W2 上游 GEMV 张量路径落地 / Apple 出 MTLTensor-GEMV 胜 qmv_fast 的路径。
2. **Swift 6.4 借用家族**(`Borrow<T>`/`Inout<T>`(anyAppleOS 27 + `$BorrowInout` 实验门)、BorrowingSequence、UTF8Span(26)、InlineArray、Span-FFI、typed-throws、CryptoKit RawSpan):
   底座 18 + 实验特性不进确定性脊柱;FFI 缝已零拷贝(withUnsafeBufferPointer→Rust SIMD);摘要路径冷(turn 被 decode 支配)。
   **重开**:底座升至 26/27,或实测热点出现在值拷贝上。
3. **杂项**:LAPACK `?larf1f_` 家族(27.0 全 Accelerate 唯一新增 — 本库无因式分解负载);**BNNS/vDSP 零新增**(负发现,已封);MetalFX(无光栅负载);EnergyKit(无可赢维度);`thread_suspend2`(协作式调度,不挂起线程);`withContinuousObservation`(脊柱观察须确定性);MPSNDArray MTL4 encode(P1 的跟随项);ExtendedLaunchMetric(启动冷路径);watchOS BGTask(无 watch 宿主)。

## 执行顺序与门

```
第一批(并行): A1 + A2 + A4(S 级)→ 各自全绿即提交
              P0(钥匙探针,endurance 一次设备运行出数)
第二批:       A3 + P6 + P7(证据栈三件套,互为放大)
              P2(零代码,设备重跑)
第三批:       P1(MTL4 队列 A/B)→ 5-axis 风格裁决
              P3/P4(BGContinued 家族)→ T3.1 第三驱动路径裁决
              P5(FoundationModels)→ 功耗/热配对证据
第四批:       P8 微门;按 P0 结果决定量化家族重审与否
```

每项独立提交、全套件 EXIT=0 实证、设备证据归档 `Docs/cert-logs/`、n=2 同型号边界照例披露。
否决与负发现同为产出 — 本计划的价值一半在 47 项里**不做哪 30 项、以什么证据不做、何时重看**。
