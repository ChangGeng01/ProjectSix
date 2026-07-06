# 可解释性审计与章程 (2026-07-06 深夜)

操作员指令:**"可解释性相关需要重视。"** 方法:7 员工作流(5 支柱盘点 × file:line 取证 + 对抗批评者 + 架构师,82 万 token),裁决人手工仲裁。

## 核心发现(盘点五支柱的共同形状)

**这个系统已经把每个"为什么"算成了纯的、有类型的、可重放的值——然后在模块边界把它们几乎全部扔掉。**

| 支柱 | 已有(算了)| 扔掉的方式 |
|---|---|---|
| 决策面 | planner 纯函数(每个门/地板显式)、BASDecodeContext(案5)、B3 reason 枚举、B2 p_success、fail-close 原因 | ctx 用完即弃;trace-exit 结构体在模块边界只剩 print;B2 探针"跑了且同意"与"根本没武装"不可区分;kill-switch 全宇宙无处枚举 |
| 基座裁决 | L14 hash 链签名账本(可按 session/turn/rule 查询!)、verdict reasonCodes、12 硬位+7 软实数 | verdict_decisions 表**零行**;chat host 的账本 sink 默认 nil;Swift/Rust 双推导无分歧哨 |
| 模型观测 | packed 单读回=零成本每 token 通道(argmax/熵/top-k)、hiddenStatesWithTaps、B2=hidden 线性探针范式 | 熵通道被 B3 生命周期锁死;streaming 车道纯黑;profiler 表不可 dump、进程死即失忆 |
| 诚实/行为 | BASModelHonestySignal 三轴打分器(纯、确定性)、②-observe 线、ADJ_GATE | **英文词表——操作员的中文轮次三轴全零**;观测 store 默认 nil;"哪个信号抓住了它"无处可答 |
| 记忆溯源 | memory_usage_records/lifecycle/tombstone 全套 SQL schema、usage tracker | tracker 没接 databaseURL(不落盘);helped 永远 unknown;隔离→清除的闭环无一测试走通(KV spill 文件在遗忘故事之外) |

## 批评者的反打(裁决:大部分成立)

1. **本库签名失败模式=先建表面后找消费者**(decode-OS 审计自己命名的 U1 陷阱)——架构师的 10 快赢+6 项目里,~25 个新表面没有一个有署名读者。
2. **熵通道解锁 = 每轮全词表 fp32 softmax**——内核作者当初特意用一次性闩锁关掉的成本,不能以"未来杠杆会用"为由翻开(为假想干预建仪器 = 带 GPU 账单的 U1)。
3. **每 token 观察者回调进热循环** = 在整个库最脆的两条路径(Task.sleep 冻结、qmv 悬崖的案发地)加分配+调度点,而当下**没有任何一层有已声明的每 token 决策**。
4. **spill 旁车明文 transcript 直接反转缝 3 的主权设计**——盘上"不透明"一半是隐私特性;要持久收据只有一条合法通道(签名账本),第二条未签名 JSONL = 隐私回退+完整性分叉。
5. **默认开的诚实持久化 = 给操作员自己的对话打行为分并永久落盘**——ADR-014 说 opt-in;主权语境下"基座该不该留关于主人的收据"默认答案是**否**,直到主人说是。低效度(英文词表+框架敏感)分数落盘更是双重错。

## 章程(仲裁后,消费者优先原则:没有署名读者就不建)

**操作员的真实工作流 = 一个人,把设备日志和探针输出贴进 Claude 会话。** 接口就是日志流;查询引擎就是读日志的 Claude。据此:

### 立即可做(等开工指令)
1. **THE turn line**:把既有 BAS_DECODE_CTX 行升级为每轮唯一叙事行——+requestID、+planned vs EXECUTED 车道与 fail-close 原因(Executor :51/:72 手里已有)、+trace-exit reason、+B2 armed/agreed/p_success 三态、会话路径也发;仍是一行,零盘,零每 token 成本。可选:同字段作 optional struct 上 BASOrganDraft(探针可断言)。**到此为止**——JSONL sink 触发条件:操作员两次问起超出日志缓冲的历史轮次。
2. **Swift/Rust 裁决分歧哨(5 行)**:swiftFloor != rustLevel 时专用审计条目+计数——唯一能无声腐蚀核心处置逻辑的暗点,零表面积。
3. **隔离-清除探针(预期失败)**:admit→use→quarantine→断言排除+墓碑+KV/crossTurn 清除——红着的测试本身就是关于遗忘故事的诚实发现(KV spill 文件在清除范围外=已知缺口,不许用假清除糊绿)。
4. **anti_syco_sys.txt 入库为资源**(复制,征得同意;绑定≠安装)——v6→v14 弧唯一被证明的廉价诚实杠杆不该是单机散文件。

### 记录在案的真暗点(不立即建,带触发器)
- **中文词表缺口**:诚实打分器对操作员实际语言全零——是研究不是接线;触发:诚实观测有了署名消费者。
- **P1 观察者缝**:触发 = 某个每 token 干预正式立项(如 CGR think-stop)。
- **持久收据**(账本 sink/verdict 写入):触发 = 钥匙托管到 keychain 级 + 操作员明确 opt-in + 历史查询需求实证。
- **中层 taps/persona-vector 读探针**:触发 = 转向战役立项自带 ADR(读先于写,写永远单独章程)。

### 不建清单
仪表盘/常开每 token 日志/全 logits 转储/spill 明文旁车/默认开行为打分/观测框架依赖/fused 车道 LogitProcessor/离机遥测(主权绝对红线)。

## 元结论

decode-OS 审计的 8 条缝本质全是可解释性失败(五个热读者五种意见)。但修法不是"更多仪器",而是**已算出的解释走到署名读者面前,一步不多**——本库最不缺表面,最缺的是让一行日志把一轮的故事讲完。
