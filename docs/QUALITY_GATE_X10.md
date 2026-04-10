# X10 Quality Gate

`EXTREME QUALITY GATE` 已经证明系统能承受一轮高压。

`X10 QUALITY GATE` 再往上推一层：它把“偶尔过一次”和“长期稳定可演化”明确区分开，专门针对本地认知系统最容易慢性变坏的地方做长时间串行碾压。

这道门的目标不是更花哨，而是更残酷：

- 先 `xcodegen generate` 重生工程，再吞掉现有 [QUALITY_GATE_EXTREME.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_EXTREME.md)
- 再把 package、host、watch、UI、memory、policy、handoff、replay 这些最容易漂移的链路做多轮串行 soak
- 强制验证“抽离成 substrate 以后，宿主没有悄悄重新变胖”

## 10 倍标准

每项记 `1` 分，必须 `12 / 12` 才算通过。

1. 先重生工程，再通过 Extreme gate。
2. `BehavioralAISubstrate` package 连续 `10` 次通过。
3. bridge / current-brain / intent-envelope / package-facing host subset 连续 `10` 次通过。
4. 环境矩阵下的 bootstrap / notification policy / runtime export 必须稳定。
5. memory governance / bootstrap / embedding / retrieval subset 连续 `10` 次通过。
6. replay / evolution / notification policy / runtime export subset 连续 `10` 次通过。
7. policy / prompt / provider / telemetry / debug subset 连续 `10` 次通过。
8. launch handoff / protected state / shared public state / replay subset 连续 `10` 次通过。
9. `BeforeUISmoke` 连续 `5` 次通过。
10. `BeforeWatch` build 连续 `5` 次通过。
11. `Before` 全量再连续 `2` 次通过。
12. 最后工作区仍然干净，没有因为反复压测留下临时补丁或生成垃圾。

## 命令

在 repo 根目录执行：

```bash
./scripts/run_quality_gate_x10.sh
```

这道门的意义不是“更绿”，而是：

`让 Behavioral AI Substrate 在反复启动、反复恢复、反复召回、反复桥接、反复演化时，仍然不失真。`
