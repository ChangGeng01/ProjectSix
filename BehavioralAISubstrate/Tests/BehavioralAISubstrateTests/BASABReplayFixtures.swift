// GENERATED FIXTURES — P1 历史战役回放验收(RSI 章程)。原始日志逐字节摘录:
// device = 2026-07-07 cacheLimit 设备扫测(9E9E,941s,人类判决:512/768/inf PARITY,
//          b0/256 冷启 burst 位置伪影被双块判据否决);
// macv1  = 同日 Mac v1 干跑(adaptiveK fp16 tie-flip ⇒ FIDELITY FAIL,仪器失效判决)。
// 回放规则:类型化管线必须复现这些人类判决,任一分歧 = 对象错,不是历史错。
enum BASABReplayFixtures {
    static let cacheLimitDeviceLog = """
[climit] b=0 arm=256 g=0 p=0 tok=192 tok/s=18.2 acc/it=1.01 thermal=0 active=2375MB cache=222MB peak=2844MB (warmup)
[climit] b=0 arm=256 g=1 p=1 tok=192 tok/s=20.7 acc/it=1.20 thermal=0 active=2375MB cache=252MB peak=2844MB
[climit] b=0 arm=256 g=2 p=2 tok=192 tok/s=20.5 acc/it=1.21 thermal=0 active=2375MB cache=255MB peak=2844MB
[climit] b=0 arm=256 g=3 p=0 tok=192 tok/s=18.3 acc/it=1.01 thermal=0 active=2375MB cache=255MB peak=2844MB
[climit] b=0 arm=256 g=4 p=1 tok=192 tok/s=20.4 acc/it=1.20 thermal=0 active=2375MB cache=256MB peak=2844MB
[climit] b=0 arm=256 g=5 p=2 tok=192 tok/s=19.8 acc/it=1.21 thermal=0 active=2375MB cache=256MB peak=2844MB
[climit] b=0 arm=256 g=6 p=0 tok=192 tok/s=14.9 acc/it=1.01 thermal=0 active=2375MB cache=255MB peak=2844MB
[climit] b=0 arm=512 g=0 p=0 tok=192 tok/s=12.8 acc/it=1.01 thermal=0 active=2375MB cache=257MB peak=2485MB (warmup)
[climit] b=0 arm=512 g=1 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=287MB peak=2485MB
[climit] b=0 arm=512 g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=287MB peak=2485MB
[climit] b=0 arm=512 g=3 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=287MB peak=2485MB
[climit] b=0 arm=512 g=4 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=288MB peak=2485MB
[climit] b=0 arm=512 g=5 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=288MB peak=2485MB
[climit] b=0 arm=512 g=6 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=288MB peak=2485MB
[climit] b=0 arm=768 g=0 p=0 tok=192 tok/s=12.9 acc/it=1.01 thermal=0 active=2375MB cache=256MB peak=2485MB (warmup)
[climit] b=0 arm=768 g=1 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=287MB peak=2485MB
[climit] b=0 arm=768 g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=288MB peak=2485MB
[climit] b=0 arm=768 g=3 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=290MB peak=2485MB
[climit] b=0 arm=768 g=4 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=290MB peak=2485MB
[climit] b=0 arm=768 g=5 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=290MB peak=2485MB
[climit] b=0 arm=768 g=6 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=290MB peak=2485MB
[climit] b=0 arm=inf g=0 p=0 tok=192 tok/s=12.9 acc/it=1.01 thermal=0 active=2375MB cache=265MB peak=2485MB (warmup)
[climit] b=0 arm=inf g=1 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=294MB peak=2485MB
[climit] b=0 arm=inf g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=294MB peak=2485MB
[climit] b=0 arm=inf g=3 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=294MB peak=2485MB
[climit] b=0 arm=inf g=4 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=0 arm=inf g=5 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=0 arm=inf g=6 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=inf g=0 p=0 tok=192 tok/s=12.9 acc/it=1.01 thermal=0 active=2375MB cache=260MB peak=2485MB (warmup)
[climit] b=1 arm=inf g=1 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=inf g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=inf g=3 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=inf g=4 p=1 tok=192 tok/s=12.9 acc/it=1.20 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=inf g=5 p=2 tok=192 tok/s=12.4 acc/it=1.21 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=inf g=6 p=0 tok=192 tok/s=11.4 acc/it=1.01 thermal=0 active=2375MB cache=291MB peak=2487MB
[climit] b=1 arm=768 g=0 p=0 tok=192 tok/s=12.9 acc/it=1.01 thermal=0 active=2375MB cache=261MB peak=2485MB (warmup)
[climit] b=1 arm=768 g=1 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=290MB peak=2485MB
[climit] b=1 arm=768 g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=293MB peak=2485MB
[climit] b=1 arm=768 g=3 p=0 tok=192 tok/s=11.4 acc/it=1.01 thermal=0 active=2375MB cache=293MB peak=2485MB
[climit] b=1 arm=768 g=4 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=293MB peak=2485MB
[climit] b=1 arm=768 g=5 p=2 tok=192 tok/s=12.6 acc/it=1.21 thermal=0 active=2375MB cache=293MB peak=2485MB
[climit] b=1 arm=768 g=6 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=294MB peak=2485MB
[climit] b=1 arm=512 g=0 p=0 tok=192 tok/s=12.9 acc/it=1.01 thermal=0 active=2375MB cache=262MB peak=2485MB (warmup)
[climit] b=1 arm=512 g=1 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=512 g=2 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=512 g=3 p=0 tok=192 tok/s=11.5 acc/it=1.01 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=512 g=4 p=1 tok=192 tok/s=12.7 acc/it=1.20 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=512 g=5 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=512 g=6 p=0 tok=192 tok/s=11.4 acc/it=1.01 thermal=0 active=2375MB cache=295MB peak=2485MB
[climit] b=1 arm=256 g=0 p=0 tok=192 tok/s=12.8 acc/it=1.01 thermal=0 active=2375MB cache=256MB peak=2485MB (warmup)
[climit] b=1 arm=256 g=1 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] b=1 arm=256 g=2 p=2 tok=192 tok/s=12.6 acc/it=1.21 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] b=1 arm=256 g=3 p=0 tok=192 tok/s=11.4 acc/it=1.01 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] b=1 arm=256 g=4 p=1 tok=192 tok/s=12.8 acc/it=1.20 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] b=1 arm=256 g=5 p=2 tok=192 tok/s=12.7 acc/it=1.21 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] b=1 arm=256 g=6 p=0 tok=192 tok/s=11.4 acc/it=1.01 thermal=0 active=2375MB cache=256MB peak=2485MB
[climit] FIDELITY OK across 56 rows
[climit] SUMMARY arm=256 pooled=14.9 tok/s b0=18.9(th0-0) b1=12.3(th0-0) cache_plateau=256MB peak=2844MB
[climit] SUMMARY arm=512 pooled=12.3 tok/s b0=12.3(th0-0) b1=12.3(th0-0) cache_plateau=295MB peak=2485MB
[climit] SUMMARY arm=768 pooled=12.3 tok/s b0=12.3(th0-0) b1=12.3(th0-0) cache_plateau=294MB peak=2485MB
[climit] SUMMARY arm=inf pooled=12.3 tok/s b0=12.3(th0-0) b1=12.3(th0-0) cache_plateau=295MB peak=2487MB
"""
    static let cacheLimitMacV1Log = """
[climit] b=0 arm=256 g=0 p=0 tok=192 tok/s=75.3 acc/it=0.78 thermal=0 active=2375MB cache=256MB peak=2849MB (warmup)
[climit] b=0 arm=256 g=1 p=1 tok=192 tok/s=82.1 acc/it=0.82 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=256 g=2 p=2 tok=192 tok/s=72.8 acc/it=0.75 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=256 g=3 p=0 tok=192 tok/s=71.4 acc/it=0.68 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=256 g=4 p=1 tok=192 tok/s=77.6 acc/it=0.85 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=256 g=5 p=2 tok=192 tok/s=80.8 acc/it=0.89 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=256 g=6 p=0 tok=192 tok/s=68.1 acc/it=0.68 thermal=0 active=2375MB cache=256MB peak=2849MB
[climit] b=0 arm=512 g=0 p=0 tok=192 tok/s=74.0 acc/it=0.82 thermal=0 active=2375MB cache=332MB peak=2470MB (warmup)
[climit] b=0 arm=512 g=1 p=1 tok=192 tok/s=69.2 acc/it=0.69 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=512 g=2 p=2 tok=192 tok/s=76.9 acc/it=0.92 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=512 g=3 p=0 tok=192 tok/s=65.6 acc/it=0.75 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=512 g=4 p=1 tok=192 tok/s=64.3 acc/it=0.69 thermal=0 active=2375MB cache=367MB peak=2470MB
[climit] b=0 arm=512 g=5 p=2 tok=192 tok/s=75.0 acc/it=0.92 thermal=0 active=2375MB cache=368MB peak=2470MB
[climit] b=0 arm=512 g=6 p=0 tok=192 tok/s=68.3 acc/it=0.75 thermal=0 active=2375MB cache=368MB peak=2470MB
[climit] b=0 arm=768 g=0 p=0 tok=192 tok/s=74.7 acc/it=0.75 thermal=0 active=2375MB cache=314MB peak=2470MB (warmup)
[climit] b=0 arm=768 g=1 p=1 tok=192 tok/s=68.8 acc/it=0.69 thermal=0 active=2375MB cache=349MB peak=2470MB
[climit] b=0 arm=768 g=2 p=2 tok=192 tok/s=75.4 acc/it=0.92 thermal=0 active=2375MB cache=349MB peak=2470MB
[climit] b=0 arm=768 g=3 p=0 tok=192 tok/s=68.4 acc/it=0.75 thermal=0 active=2375MB cache=352MB peak=2470MB
[climit] b=0 arm=768 g=4 p=1 tok=192 tok/s=65.1 acc/it=0.69 thermal=0 active=2375MB cache=363MB peak=2470MB
[climit] b=0 arm=768 g=5 p=2 tok=192 tok/s=71.2 acc/it=0.92 thermal=0 active=2375MB cache=364MB peak=2470MB
[climit] b=0 arm=768 g=6 p=0 tok=192 tok/s=65.9 acc/it=0.75 thermal=0 active=2375MB cache=364MB peak=2470MB
[climit] b=0 arm=inf g=0 p=0 tok=192 tok/s=76.8 acc/it=0.75 thermal=0 active=2375MB cache=330MB peak=2470MB (warmup)
[climit] b=0 arm=inf g=1 p=1 tok=192 tok/s=69.1 acc/it=0.69 thermal=0 active=2375MB cache=365MB peak=2470MB
[climit] b=0 arm=inf g=2 p=2 tok=192 tok/s=76.5 acc/it=0.92 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=inf g=3 p=0 tok=192 tok/s=67.3 acc/it=0.75 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=inf g=4 p=1 tok=192 tok/s=66.8 acc/it=0.69 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=0 arm=inf g=5 p=2 tok=192 tok/s=75.3 acc/it=0.92 thermal=0 active=2375MB cache=367MB peak=2470MB
[climit] b=0 arm=inf g=6 p=0 tok=192 tok/s=65.7 acc/it=0.75 thermal=0 active=2375MB cache=367MB peak=2470MB
[climit] b=1 arm=inf g=0 p=0 tok=192 tok/s=75.9 acc/it=0.75 thermal=0 active=2375MB cache=321MB peak=2470MB (warmup)
[climit] b=1 arm=inf g=1 p=1 tok=192 tok/s=67.9 acc/it=0.69 thermal=0 active=2375MB cache=354MB peak=2470MB
[climit] b=1 arm=inf g=2 p=2 tok=192 tok/s=75.2 acc/it=0.92 thermal=0 active=2375MB cache=365MB peak=2470MB
[climit] b=1 arm=inf g=3 p=0 tok=192 tok/s=67.3 acc/it=0.75 thermal=0 active=2375MB cache=365MB peak=2470MB
[climit] b=1 arm=inf g=4 p=1 tok=192 tok/s=68.3 acc/it=0.69 thermal=0 active=2375MB cache=365MB peak=2470MB
[climit] b=1 arm=inf g=5 p=2 tok=192 tok/s=72.3 acc/it=0.92 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=1 arm=inf g=6 p=0 tok=192 tok/s=65.8 acc/it=0.75 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=1 arm=768 g=0 p=0 tok=192 tok/s=73.6 acc/it=0.75 thermal=0 active=2375MB cache=328MB peak=2470MB (warmup)
[climit] b=1 arm=768 g=1 p=1 tok=192 tok/s=64.6 acc/it=0.69 thermal=0 active=2375MB cache=364MB peak=2470MB
[climit] b=1 arm=768 g=2 p=2 tok=192 tok/s=75.2 acc/it=0.92 thermal=0 active=2375MB cache=364MB peak=2470MB
[climit] b=1 arm=768 g=3 p=0 tok=192 tok/s=67.8 acc/it=0.75 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=1 arm=768 g=4 p=1 tok=192 tok/s=66.6 acc/it=0.69 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=1 arm=768 g=5 p=2 tok=192 tok/s=72.5 acc/it=0.92 thermal=0 active=2375MB cache=366MB peak=2470MB
[climit] b=1 arm=768 g=6 p=0 tok=192 tok/s=66.1 acc/it=0.75 thermal=0 active=2375MB cache=367MB peak=2470MB
[climit] b=1 arm=512 g=0 p=0 tok=192 tok/s=42.5 acc/it=0.75 thermal=0 active=2375MB cache=322MB peak=2460MB (warmup)
[climit] b=1 arm=512 g=1 p=1 tok=192 tok/s=52.5 acc/it=0.69 thermal=0 active=2375MB cache=357MB peak=2463MB
[climit] b=1 arm=512 g=2 p=2 tok=192 tok/s=59.1 acc/it=0.92 thermal=0 active=2375MB cache=357MB peak=2463MB
[climit] b=1 arm=512 g=3 p=0 tok=192 tok/s=58.5 acc/it=0.75 thermal=0 active=2375MB cache=360MB peak=2463MB
[climit] b=1 arm=512 g=4 p=1 tok=192 tok/s=63.6 acc/it=0.69 thermal=0 active=2375MB cache=360MB peak=2464MB
[climit] b=1 arm=512 g=5 p=2 tok=192 tok/s=62.2 acc/it=0.92 thermal=0 active=2375MB cache=361MB peak=2464MB
[climit] b=1 arm=512 g=6 p=0 tok=192 tok/s=68.7 acc/it=0.75 thermal=0 active=2375MB cache=369MB peak=2470MB
[climit] b=1 arm=256 g=0 p=0 tok=192 tok/s=74.0 acc/it=0.75 thermal=0 active=2375MB cache=256MB peak=2470MB (warmup)
[climit] b=1 arm=256 g=1 p=1 tok=192 tok/s=75.8 acc/it=0.69 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] b=1 arm=256 g=2 p=2 tok=192 tok/s=83.7 acc/it=0.92 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] b=1 arm=256 g=3 p=0 tok=192 tok/s=65.1 acc/it=0.75 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] b=1 arm=256 g=4 p=1 tok=192 tok/s=67.4 acc/it=0.69 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] b=1 arm=256 g=5 p=2 tok=192 tok/s=80.5 acc/it=0.92 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] b=1 arm=256 g=6 p=0 tok=192 tok/s=68.6 acc/it=0.75 thermal=0 active=2375MB cache=256MB peak=2470MB
[climit] FIDELITY-FAIL prompt=0 distinct=4
[climit] FIDELITY-FAIL prompt=1 distinct=2
[climit] FIDELITY-FAIL prompt=2 distinct=2
[climit] FIDELITY FAIL across 56 rows
[climit] SUMMARY arm=256 pooled=74.0 tok/s b0=75.1(th0-0) b1=72.9(th0-0) cache_plateau=256MB peak=2849MB
[climit] SUMMARY arm=512 pooled=64.6 tok/s b0=69.6(th0-0) b1=60.4(th0-0) cache_plateau=369MB peak=2470MB
[climit] SUMMARY arm=768 pooled=68.8 tok/s b0=69.0(th0-0) b1=68.6(th0-0) cache_plateau=367MB peak=2470MB
[climit] SUMMARY arm=inf pooled=69.6 tok/s b0=69.9(th0-0) b1=69.3(th0-0) cache_plateau=367MB peak=2470MB
"""
}
