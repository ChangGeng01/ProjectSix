# cacheLimit {256,512,768,∞} A/B 战役 (2026-07-07,预注册)

操作员令:"cacheLimit A/B 战役开工 最严苛"。decode-OS 收官时立的独立测量 rider
(DECODE_OS_AUDIT:126/201)。

## 问题与证据缺口

生产 default = 512 MiB(`BASMLXMemoryModel.defaultCacheLimitBytes`,loadModel 一次性
应用)。**这是纯 E2B 搬运**:ADR-038 §11.7-11.9 的全部证据在 Gemma-3n-E2B(可变缓冲形状,
无界 3 轮 wedge;512 上 30/30、平台 ≈512);"~384-768 带"是 64-churn 与 512-works 两点
夹逼推断,**从未扫测**;Qwen3.5-4B(固定形状,当前生产主干)上**零受控测量**——
T4 认证的 3100-3180 MB 运营带是"在 512 之下"的测量,不是"512 的效应"测量。
(3 员侦察 wf_512db116-27c,file:line 全部核实。)

## 结构性事实(设计依据)

- cacheLimit = MLX 自由缓冲池回收顶棚,**output-byte-equal**(只改缓冲回收时机,
  不改数学;MLXOrganAdapter.swift:96-98 + vendored allocator.cpp:168-201)。
- 逐出懒执行(下次 alloc/dealloc 生效);mid-session `MLX.GPU.set(cacheLimit:)`
  线程安全幂等;配 `clearCache()` 立即清池。Getter 有先读变值怪癖——**只写不读**。
- headroom:运营带 ~3100-3180 MB vs 已解析 jetsam cap 6144 MB ⇒ ~2.9-3.0 GB 富余,
  768/1024 池都放得下。反向教训:cap=64+逐迭代 drain 曾提前 wedge(churn 有害,
  但该臂混杂 drain——256 无直接测量)。
- 遥测:`Memory.snapshot()`{active,cache,peak}、`GPU.resetPeakMemory()`。

## 假设(测前声明)

- **H1 形状平台**:Qwen3.5-4B 固定形状 ⇒ 池自然平台于某 P;若 P ≤ 256,四臂全等
  (选择=无关紧要,512 留作保险带)。
- **H2 churn 斜坡**:若 cap < P,重分配 churn 减速 ⇒ tok/s 随 cap 升到 P 为止。
- **H3 ∞ 平台**:∞ 臂应平台(固定形状)而非无界增长;若观察到无界增长 ⇒
  cap 对 Qwen3.5 也是**必需**(强化 512 默认的正当性)。

## 设计(同机同会话交错,镜像序消热漂)

- 臂:{256 MiB, 512 MiB(在位), 768 MiB, ∞(Int.max)}。
- 序:block1 = [256,512,768,∞],block2 = 镜像 [∞,768,512,256]。线性热漂下每臂
  跨块平均位置相等(全部 4.5)——一阶消漂。
- 每臂块协议:`set(cacheLimit)` → `clearCache()` → `resetPeakMemory()` →
  **1 次不计入热身生成**(新 cap 下池回填到稳态)→ **6 次计入生成**
  (3 固定提示词 ×2 轮转,与 sustained 探针同题)。
- 每生成记录:tokens、`Run.decodeSeconds`(纯解码计时,与 DWQ3 同源)、
  accepted/iterations(adaptiveK 行为可视)、thermal rawValue、生成后
  snapshot{active,cache,peak}。
- 卫生:生成间 1s、臂块间 5s(全臂同处理,均匀性重于幅度)。单容器单解码器
  全程一体(EMA 跨臂携带,但输出逐 token 臂不变 ⇒ 接受度臂不变 ⇒ EMA 轨迹
  臂序无关,热身再稳一道)。
- 车道:生产 fused-MTP(K=mtpProductionK、tCap 平台常数、adaptiveK:true)。
  plain 车道不在本战役(cap 作用于分配模式,生产车道优先;需要时后补)。

## 预注册判据(先于测量)

1. **仪器门(fidelity anchor)**:每提示词的输出 token 序列在全部 8 臂块间
   **逐一相等**(cap 结构性 byte-equal ⇒ 任何分歧 = harness bug,判决无效,先修)。
2. **∞ 臂安全中止**:任一生成后 cache > 2 GiB ⇒ 打印 UNBOUNDED-GROWTH、中止该臂
   ——该结果本身即判决(cap 必需);iOS 下 available < 600 MB 同样中止(诚实 DNF)。
3. **速度判决**:主指标 = 每臂 pooled tok/s(Σtok/Σs,12 生成跨两块)。
   对在位 512:|Δ| ≤ 3% = 平价;**真效应需两块内独立同号 >3%**。
4. **内存判决**:每臂池平台 = max(cache);∞ 平台 ≤ 1 GiB ⇒ H1 成立;
   单调增长或 >2 GiB ⇒ cap 必需。
5. **热混杂规则**:任一臂两块间 thermal 层差 ≥2 ⇒ 该臂跨块合并无效,只做块内比较并注明。
6. **默认值变更规则**:仅当某臂**两块独立 >3% 更快** ∧ 池平台 ≤1 GiB ∧ headroom ≥2 GiB
   才建议改产;256 平价速度 ∧ 平台 <256 记为可选 headroom 红利。**本战役只出建议**;
   任何默认值变更走 ADR-014 自己的认证(sustained endurance 复测)。
7. **Mac 干跑门(仪器验证,非速度证据)**:fidelity anchor 全过 + 报表健全,
   过门才上设备。Mac 绝对 tok/s 不外推设备(历史铁律)。

## 执行

harness = Tests/BehavioralAISubstrateTests/BASCacheLimitABDeviceTests.swift
(BAS_CACHELIMIT_AB=1;设备 TEST_RUNNER_ 前缀;iOS=Documents staging,
macOS=HF cache + /tmp/gdn_coreai MTP 权重);pbxproj 四项手注册。
设备 = 当日无负载的那台 Air,跑批期间零并发负载。预计 ~10-15 min。

执行注记:pbxproj 四项手注册完成(CA11ECAB1000…B1/F1,plutil OK);
perform 闭包异步上下文禁 Thread.sleep → usleep 原语(阻塞语义不变)。

## v2 协议修订(Mac 仪器门点火,设备跑批前)

Mac 干跑 v1 fidelity anchor **FAIL**(prompt0 16 行 4 变体)——不是 cap 违反
byte-equal,而是 **adaptiveK 数值事实**:EMA 轨迹差 → K 序列差 → 融合验证批形状差 →
fp16 近平局 argmax 翻转(= DFlash Gate-b 流伪影,独立仪器再确认)。ADR-039 "lossless"
的精确义 = 每发射 token 等于**该次前向数值下的**主干 argmax;K 轨迹改变批数值即可改prose。
**修订:harness 固定 K=3(adaptiveK:false,确定性探针纪律)**——同题净状态 ⇒ 逐字节稳定,
anchor 恢复;顺带消掉 EMA 噪声源(对 cap 比较是更干净的控制;cap 效应=回收 churn,
与 K 策略一阶无关)。生产车道 adaptiveK:true 的偏离已注记。判据 1-7 不变。

## 结果与判决(2026-07-07,iPhone Air 9E9E,941s,全程 thermal=0)

**仪器门**:Mac v2 + 设备 FIDELITY 56/56 全过;无中止臂。

| 臂 | pooled | b0 | b1 | 池平台 | peak |
|----|--------|----|----|--------|------|
| 256 | 14.9* | 18.9* | 12.3 | 256(钉在 cap) | 2844*/2485 |
| 512(在位) | 12.3 | 12.3 | 12.3 | ~288 | 2485 |
| 768 | 12.3 | 12.3 | 12.3 | ~294 | 2485 |
| ∞ | 12.3 | 12.3 | 12.3 | ~295 | 2487 |

*位置伪影,逐行核对证实:b0/256 是整场第一臂块,整块吃冷启 burst(逐行 18-20.7 持平、
块尾衰至 14.9;b1/256 = 11.4-12.8 与全场同带)——双块判据(3)正确否决;peak 2844 同为
首块专属(b1/256 peak=2485 = 全场值 ⇒ 非 cap 效应,是进程首次融合解码的一次性材料化,
Mac 干跑同位置同现象,跨平台复现)。

**判决(按预注册判据)**:
- **速度:四臂稳态完全平价**(11.4-12.9 带,pooled 12.3 三臂逐位相等)——cacheLimit 在
  {256,512,768,∞} 上对 Qwen3.5-4B 生产解码是**测量证实的 DON'T-CARE**。H2(churn 斜坡)
  在 256 处被否证:cap 低于自然平台 39MB 的温和回收零速度代价。
- **内存:H1 证实**——池自然平台 ≈288-295MB(远低于 512);∞ 臂 14 生成零增长(≤1GiB
  判据大幅通过)⇒ H3 方向:固定形状自然平台,cap 对本模型稳态**非必需**。
- **判据 6:不改默认。512 保留**——首次拿到生产模型上的直接证据(此前纯 E2B 搬运):
  高于自然平台 ⇒ 零成本;唯一在役角色 = 可变形状模型(E2B 类)与病态负载的保险带。
  256 无 headroom 红利(池省 39MB 是真,但对 jetsam 有意义的 peak 不降)。
- 注记:harness 稳态 ~12.3 < sustained 平台 14.2 —— 固定 K=3 的确定性探针纪律代价
  (acc/it 仅 1.0-1.2,adaptive-K 生产车道会收敛 K=1;全臂同罚,不影响比较)。

**方法教训入册**:①同会话扫测的**首臂块**吸收冷启 burst + 首次材料化峰 —— 位置伪影
双杀;镜像序 + 双块独立判据 + 逐行核对 = 解药三件套(本役两道预注册防线全部实际点火)。
②臂级 max() 汇总会捡位置伪影 —— 判决前必逐行。③byte-anchor 仪器必须固定 K
(adaptiveK 的 fp16 批形状 tie-flip 破 byte 稳定 —— Gate-b 流伪影第二次独立确认)。
