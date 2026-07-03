#!/usr/bin/env python3
"""B: production-representative GPU numbers — plain vs MTP-spec on the Mac GPU (mx port of the verified trunk).
Correctness gate FIRST (golden top-5 must match), then wall-clock. No Swift/vendored code touched."""
import glob, json, os, struct, time
from pathlib import Path
import numpy as np
import mlx.core as mx

CKPT = glob.glob(str(Path.home() / ".cache/huggingface/hub/models--mlx-community--Qwen3.5-4B-4bit/snapshots/*/"))[0]
D, GV, GK, GHD, GROUP = 2560, 32, 16, 128, 64
KEYDIM = GK * GHD
AH, AKV, AHD, BASE, RD = 16, 4, 256, 1e7, 64
MAX = 192
P = "language_model.model."

def load_store():
    store = {}
    for fp in sorted(glob.glob(os.path.join(CKPT, "*.safetensors"))):
        with open(fp, "rb") as f:
            n = struct.unpack("<Q", f.read(8))[0]; hdr = json.loads(f.read(n)); base = 8 + n
        for k, m in hdr.items():
            if k != "__metadata__": store[k] = (fp, base, m)
    return store
def raw_np(store, key):
    fp, base, m = store[key]
    dt = {"BF16": np.uint16, "F32": np.float32, "U32": np.uint32, "F16": np.float16}[m["dtype"]]
    s, e = m["data_offsets"]
    with open(fp, "rb") as f:
        f.seek(base + s); buf = f.read(e - s)
    a = np.frombuffer(buf, dtype=dt).reshape(m["shape"])
    if m["dtype"] == "BF16": a = (a.astype(np.uint32) << 16).view(np.float32)
    return a
def dequant_np(store, key):
    w = raw_np(store, key + ".weight").astype(np.int64)
    sc = raw_np(store, key + ".scales").astype(np.float32); bi = raw_np(store, key + ".biases").astype(np.float32)
    out, in8 = w.shape; inn = in8 * 8
    nib = np.stack([(w >> (4 * b)) & 0xF for b in range(8)], -1).reshape(out, inn).astype(np.float32)
    sc = np.repeat(sc, GROUP, 1)[:, :inn]; bi = np.repeat(bi, GROUP, 1)[:, :inn]
    return (sc * nib + bi).astype(np.float16)

def is_lin(i): return (i + 1) % 4 != 0
def rms(x, w=None, e=1e-6):
    y = x * mx.rsqrt(mx.mean(x.astype(mx.float32) ** 2, -1, keepdims=True) + e).astype(mx.float16)
    return y * w if w is not None else y
def silu(x): return x * mx.sigmoid(x)
def softplus(x): return mx.logaddexp(x, mx.array(0.0))

print(">> loading weights → mx 4-BIT (production precision: packed U32 + quantized_matmul) ...")
st = load_store()
def Q(k):   # packed 4-bit triple, exactly as the checkpoint stores it (mlx group_size 64)
    return dict(w=mx.array(raw_np(st, P + k + ".weight")),
                s=mx.array(raw_np(st, P + k + ".scales").astype(np.float16)),
                b=mx.array(raw_np(st, P + k + ".biases").astype(np.float16)))
def mm(x, W):
    y = mx.quantized_matmul(x.reshape(-1, x.shape[-1]), W["w"], W["s"], W["b"],
                            transpose=True, group_size=64, bits=4)
    return y.reshape(*x.shape[:-1], y.shape[-1])
def R(k): return mx.array(raw_np(st, P + k).astype(np.float16))
embedQ = Q("embed_tokens")
embed = mx.dequantize(embedQ["w"], embedQ["s"], embedQ["b"], group_size=64, bits=4)  # fp16 rows for LOOKUP only
fnorm = R("norm.weight")
layers = []
for i in range(32):
    p = f"layers.{i}."
    if is_lin(i):
        layers.append(("g", dict(qkv=Q(p+"linear_attn.in_proj_qkv"), a=Q(p+"linear_attn.in_proj_a"),
            b=Q(p+"linear_attn.in_proj_b"), z=Q(p+"linear_attn.in_proj_z"), o=Q(p+"linear_attn.out_proj"),
            A=mx.array(raw_np(st, P+p+"linear_attn.A_log").astype(np.float32)),
            dtb=mx.array(raw_np(st, P+p+"linear_attn.dt_bias").astype(np.float32)),
            cw=R(p+"linear_attn.conv1d.weight").reshape(8192, 4), gn=R(p+"linear_attn.norm.weight"),
            iln=R(p+"input_layernorm.weight"), pln=R(p+"post_attention_layernorm.weight"),
            g1=Q(p+"mlp.gate_proj"), g2=Q(p+"mlp.up_proj"), g3=Q(p+"mlp.down_proj"))))
    else:
        layers.append(("f", dict(qp=Q(p+"self_attn.q_proj"), kp=Q(p+"self_attn.k_proj"),
            vp=Q(p+"self_attn.v_proj"), op=Q(p+"self_attn.o_proj"),
            qn=R(p+"self_attn.q_norm.weight"), kn=R(p+"self_attn.k_norm.weight"),
            iln=R(p+"input_layernorm.weight"), pln=R(p+"post_attention_layernorm.weight"),
            g1=Q(p+"mlp.gate_proj"), g2=Q(p+"mlp.up_proj"), g3=Q(p+"mlp.down_proj"))))
MT = np.load("/tmp/gdn_coreai/qwen35_mtp.npz")
def W16(k): return mx.array(MT[k].astype(np.float16))
mtpw = {k.split("mtp.")[-1]: W16(k) for k in MT.files}
def rmsz(x, w): return rms(x) * (1 + w)

inv_freq = mx.array((BASE ** (-np.arange(0, RD, 2) / RD)).astype(np.float32))
def rope(t, positions):                       # t [T,H,256]
    ang = positions.astype(mx.float32)[:, None] * inv_freq[None, :]
    cos = mx.cos(ang).astype(mx.float16)[:, None, :]; sin = mx.sin(ang).astype(mx.float16)[:, None, :]
    tr, tp = t[..., :RD], t[..., RD:]; hf = RD // 2
    x1, x2 = tr[..., :hf], tr[..., hf:]
    return mx.concatenate([mx.concatenate([x1*cos - x2*sin, x1*sin + x2*cos], -1), tp], -1)

class S:
    def __init__(s):
        s.gs = [mx.zeros((GV, GHD, GHD), dtype=mx.float16) for _ in range(32)]
        s.cw = [mx.zeros((3, 8192), dtype=mx.float16) for _ in range(32)]
        s.kb = [mx.zeros((MAX, AKV, AHD), dtype=mx.float16) for _ in range(32)]
        s.vb = [mx.zeros((MAX, AKV, AHD), dtype=mx.float16) for _ in range(32)]
        s.pos = 0

def trunk(tokens, st, capture_mid=False):
    T = len(tokens)
    h = embed[mx.array(tokens)]
    positions = mx.array([st.pos + t for t in range(T)])
    mid = {} if (capture_mid and T == 2) else None
    for i, (kind, w) in enumerate(layers):
        hin = rms(h, w["iln"])
        if kind == "g":
            qkv = mm(hin, w["qkv"])
            win = mx.concatenate([st.cw[i], qkv], 0)
            conv = mx.stack([mx.sum(win[t:t+4].T * w["cw"], -1) for t in range(T)])
            conv = silu(conv)
            q = conv[:, :KEYDIM].reshape(T, GK, GHD); k = conv[:, KEYDIM:2*KEYDIM].reshape(T, GK, GHD)
            v = conv[:, 2*KEYDIM:].reshape(T, GV, GHD)
            iv = GHD ** -0.5
            q = mx.repeat((iv*iv) * rms(q), GV // GK, 1); k = mx.repeat(iv * rms(k), GV // GK, 1)
            decay = mx.exp(-mx.exp(w["A"]) * softplus(mm(hin, w["a"]).astype(mx.float32) + w["dtb"]))
            beta = mx.sigmoid(mm(hin, w["b"])); z = mm(hin, w["z"]).reshape(T, GV, GHD)
            Sg = st.gs[i]; outs = []
            for t in range(T):
                Sg = Sg * decay[t].reshape(GV, 1, 1).astype(mx.float16)
                kv = mx.sum(Sg * k[t][:, None, :], -1)
                Sg = Sg + k[t][:, None, :] * ((v[t] - kv) * beta[t][:, None])[:, :, None]
                outs.append(mx.sum(Sg * q[t][:, None, :], -1))
                if mid is not None and t == 0:
                    mid[i] = (Sg, win[1:4])
            st.gs[i] = Sg; st.cw[i] = win[T:T+3]
            y = mx.stack(outs)
            y = (rms(y, w["gn"]) * silu(z)).reshape(T, GV * GHD)
            h = h + mm(y, w["o"])
        else:
            qpo = mm(hin, w["qp"]).reshape(T, AH, 2 * AHD)
            q, gate = qpo[..., :AHD], qpo[..., AHD:].reshape(T, AH * AHD)
            k = mm(hin, w["kp"]).reshape(T, AKV, AHD); v = mm(hin, w["vp"]).reshape(T, AKV, AHD)
            q = rms(q, w["qn"]); k = rms(k, w["kn"])
            q = rope(q, positions); k = rope(k, positions)
            st.kb[i][st.pos:st.pos+T] = k; st.vb[i][st.pos:st.pos+T] = v
            kk = mx.repeat(st.kb[i][:st.pos+T], AH // AKV, 1).transpose(1, 0, 2)
            vv = mx.repeat(st.vb[i][:st.pos+T], AH // AKV, 1).transpose(1, 0, 2)
            qq = q.transpose(1, 0, 2)
            sc = (qq.astype(mx.float32) @ kk.astype(mx.float32).transpose(0, 2, 1)) * (AHD ** -0.5)  # [AH,T,pos+T]
            kpos = mx.arange(st.pos + T)[None, None, :]
            qpos = (st.pos + mx.arange(T))[None, :, None]
            sc = mx.where(kpos <= qpos, sc, mx.array(-1e30))
            out = (mx.softmax(sc, -1) @ vv.astype(mx.float32)).transpose(1, 0, 2).reshape(T, -1).astype(mx.float16)
            h = h + mm(out * mx.sigmoid(gate), w["op"])
        hin2 = rms(h, w["pln"])
        h = h + mm(silu(mm(hin2, w["g1"])) * mm(hin2, w["g2"]), w["g3"])
    st.pos += T
    return h, mid

class MTPmx:
    def __init__(s):
        s.kb = mx.zeros((MAX, AKV, AHD), dtype=mx.float16); s.vb = mx.zeros((MAX, AKV, AHD), dtype=mx.float16)
    def draft(s, emb, hid, pos):
        u = mx.concatenate([rmsz(emb, mtpw["pre_fc_norm_embedding.weight"]), rmsz(hid, mtpw["pre_fc_norm_hidden.weight"])])
        u = u @ mtpw["fc.weight"].T
        h = rmsz(u, mtpw["layers.0.input_layernorm.weight"])
        qpo = (h @ mtpw["layers.0.self_attn.q_proj.weight"].T).reshape(AH, 2 * AHD)
        q, gate = qpo[:, :AHD], qpo[:, AHD:].reshape(-1)
        k = (h @ mtpw["layers.0.self_attn.k_proj.weight"].T).reshape(AKV, AHD)
        v = (h @ mtpw["layers.0.self_attn.v_proj.weight"].T).reshape(AKV, AHD)
        q = rmsz(q, mtpw["layers.0.self_attn.q_norm.weight"]); k = rmsz(k, mtpw["layers.0.self_attn.k_norm.weight"])
        pp = mx.array([pos])
        q = rope(q[None], pp)[0]; k = rope(k[None], pp)[0]
        s.kb[pos] = k; s.vb[pos] = v
        kk = mx.repeat(s.kb[:pos+1], AH // AKV, 1).transpose(1, 0, 2)
        vv = mx.repeat(s.vb[:pos+1], AH // AKV, 1).transpose(1, 0, 2)
        sc = (q[:, None, :].astype(mx.float32) @ kk.astype(mx.float32).transpose(0, 2, 1)) * (AHD ** -0.5)
        out = (mx.softmax(sc, -1) @ vv.astype(mx.float32)).reshape(-1).astype(mx.float16) * mx.sigmoid(gate)
        y = u + out @ mtpw["layers.0.self_attn.o_proj.weight"].T
        z = rmsz(y, mtpw["layers.0.post_attention_layernorm.weight"])
        y = y + (silu(z @ mtpw["layers.0.mlp.gate_proj.weight"].T) * (z @ mtpw["layers.0.mlp.up_proj.weight"].T)) @ mtpw["layers.0.mlp.down_proj.weight"].T
        return rmsz(y, mtpw["norm.weight"])

def headlg(h):   # quantized tied head (production form); h [...,D] → logits
    return mm(rms(h, fnorm), embedQ)
def head(h):
    return int(mx.argmax(headlg(h)))

def main():
    toks = [int(x) for x in np.load("/tmp/gdn_coreai/mlx_toks32.npy")]
    # ---- correctness gate ----
    st = S()
    h, _ = trunk(toks, st)
    logits = headlg(h[-1]).astype(mx.float32)
    mx.eval(logits)
    top5 = [int(x) for x in mx.argsort(logits)[-5:][::-1]]
    gold = set(np.load("/tmp/gdn_coreai/mlx_logits32.npy").argsort()[-5:])
    ov = len(set(top5) & gold)
    print(f">> mx port correctness gate: top5={top5} overlap={ov}/5 " + ("✅" if ov >= 4 else "❌ ABORT"))
    if ov < 4: return
    N = 64
    # ---- PLAIN ----
    st = S(); h, _ = trunk(toks, st); nxt = head(h[-1]); mx.eval(mx.array(nxt))
    t0 = time.time(); made = 0; stream_p = []
    while made < N:
        h, _ = trunk([nxt], st); nxt = head(h[-1]); mx.eval(mx.array(nxt))
        stream_p.append(nxt); made += 1
    tp = time.time() - t0
    print(f">> GPU PLAIN: {N} tok in {tp:.1f}s = {N/tp:.2f} tok/s")
    # ---- SPEC ----
    st = S(); mtp = MTPmx()
    h, _ = trunk(toks, st); nxt = head(h[-1])
    d = int(mx.argmax(mm(mtp.draft(embed[nxt], h[-1], st.pos - 1), embedQ)))
    mx.eval(mx.array(d))
    t0 = time.time(); made = 0; acc = 0; iters = 0; stream_s = []
    while made < N:
        pos0 = st.pos
        h2, mid = trunk([nxt, d], st, capture_mid=True)
        lg2 = headlg(h2)                                   # ONE batched quantized head for both rows
        true2 = int(mx.argmax(lg2[0])); iters += 1
        if true2 == d:
            acc += 1; made += 2
            em = int(mx.argmax(lg2[1])); stream_s += [true2, em]
            nxt = em; hl = h2[1]
        else:
            for i in mid: st.gs[i], st.cw[i] = mid[i]
            st.pos = pos0 + 1
            made += 1; stream_s.append(true2)
            nxt = true2; hl = h2[0]
        d = int(mx.argmax(mm(mtp.draft(embed[nxt], hl, st.pos - 1), embedQ)))
        mx.eval(mx.array(d))
    ts = time.time() - t0
    print(f">> GPU SPEC:  {made} tok in {ts:.1f}s = {made/ts:.2f} tok/s  (a={acc}/{iters}={acc/iters:.2f})")
    print(f">> GPU WALL-CLOCK RATIO: {(made/ts)/(N/tp):.2f}x")
    Lm = min(len(stream_p), len(stream_s))
    same = sum(1 for i in range(Lm) if stream_p[i] == stream_s[i])
    print(f">> GREEDY-IDENTITY (GPU): {same}/{Lm} " + ("✅" if same == Lm else "⚠️ diverges"))

if __name__ == "__main__":
    main()
