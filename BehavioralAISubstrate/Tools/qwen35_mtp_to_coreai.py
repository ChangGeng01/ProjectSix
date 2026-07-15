#!/usr/bin/env python3
"""C: the 5th CoreAI asset — Qwen3.5's MTP head as a tiny ANE-safe drafter (int8, single fused state).
Contract: inputs x_embed [1,2560] (next-token embed) + x_hidden [1,2560] (trunk hidden) → out [1,2560] draft
hidden (feed the existing head_only asset for draft logits). Zero-centered HF norms PRE-FOLDED to (1+w) so the
graph uses plain rmsnorm. State_all [2, 131072]: row0 = kv cache (kb‖vb, MAXSEQ=64), row1[0] = pos.
Fidelity gate: torch reference (MTP class) vs this module on 6 steps BEFORE converting."""
import sys, shutil
from pathlib import Path
import numpy as np, torch, torch.nn as nn, torch.nn.functional as F
sys.path.insert(0, "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/c3ffc755-9222-4370-81cc-7a004da44172/scratchpad")
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import rms, D
from qwen35_mtp_acceptance import MTP        # zero-centered reference (fp16-int8 mixed)
from llama_to_coreai_int8 import QuantLinear
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors

AH, AKV, AHD, BASE, RD, MAXSEQ = 16, 4, 256, 1e7, 64, 64
KV = MAXSEQ * AKV * AHD                      # 65536
ROW = 2 * KV                                 # 131072
M = np.load("/tmp/gdn_coreai/qwen35_mtp.npz")
def q8(k): return QuantLinear(torch.from_numpy(M[k].copy()).float(), 8)
def foldn(k): return nn.Parameter((1 + torch.from_numpy(M[k].copy()).half()))   # pre-fold zero-centered → plain

class MTPAsset(nn.Module):
    def __init__(s):
        super().__init__()
        s.fc = q8("mtp.fc.weight")
        s.qp = q8("mtp.layers.0.self_attn.q_proj.weight"); s.kp = q8("mtp.layers.0.self_attn.k_proj.weight")
        s.vp = q8("mtp.layers.0.self_attn.v_proj.weight"); s.op = q8("mtp.layers.0.self_attn.o_proj.weight")
        s.gw = q8("mtp.layers.0.mlp.gate_proj.weight"); s.uw = q8("mtp.layers.0.mlp.up_proj.weight")
        s.dw = q8("mtp.layers.0.mlp.down_proj.weight")
        s.nE = foldn("mtp.pre_fc_norm_embedding.weight"); s.nH = foldn("mtp.pre_fc_norm_hidden.weight")
        s.iln = foldn("mtp.layers.0.input_layernorm.weight"); s.pln = foldn("mtp.layers.0.post_attention_layernorm.weight")
        s.qn = foldn("mtp.layers.0.self_attn.q_norm.weight"); s.kn = foldn("mtp.layers.0.self_attn.k_norm.weight")
        s.fn = foldn("mtp.norm.weight")
        s.register_buffer("state_all", torch.zeros(2, ROW, dtype=torch.float16))

    def forward(s, x_embed, x_hidden):                    # [1,2560] each
        pos = s.state_all[1, 0] + 0.0                      # fp16 scalar (integer-exact ≤ 2048)
        u = s.fc(torch.cat([rms(x_embed.view(D), s.nE), rms(x_hidden.view(D), s.nH)]).half())
        h = rms(u, s.iln)
        qpo = s.qp(h).view(AH, 2 * AHD); q, g = qpo[:, :AHD], qpo[:, AHD:]; gate = g.reshape(-1)
        k = s.kp(h).view(AKV, AHD); v = s.vp(h).view(AKV, AHD)
        q = rms(q, s.qn); k = rms(k, s.kn)
        inv = BASE ** (-torch.arange(0, RD, 2).float() / RD)
        ang = (pos * inv).half(); cos, sin = ang.cos(), ang.sin(); hf = RD // 2
        def rope(t):
            tr, tp = t[:, :RD], t[:, RD:]; a, b = tr[:, :hf], tr[:, hf:]
            return torch.cat([torch.cat([a * cos - b * sin, a * sin + b * cos], -1), tp], -1)
        q = rope(q); k = rope(k)
        kb = s.state_all[0, :KV].view(MAXSEQ, AKV, AHD); vb = s.state_all[0, KV:].view(MAXSEQ, AKV, AHD)
        idx = torch.arange(MAXSEQ, dtype=torch.float16)
        oh = (idx == pos).to(torch.float16).view(MAXSEQ, 1, 1)
        kb = kb * (1 - oh) + oh * k.view(1, AKV, AHD); vb = vb * (1 - oh) + oh * v.view(1, AKV, AHD)
        kk = kb.repeat_interleave(AH // AKV, 1).transpose(0, 1); vv = vb.repeat_interleave(AH // AKV, 1).transpose(0, 1)
        sc = (q.unsqueeze(1).float() @ kk.float().transpose(-1, -2)).squeeze(1) * (AHD ** -0.5)
        sc = torch.where((idx <= pos).view(1, MAXSEQ), sc, torch.tensor(float("-inf")))
        out = (F.softmax(sc, -1).unsqueeze(1) @ vv.float()).squeeze(1).reshape(-1).half() * torch.sigmoid(gate)
        y = u + s.op(out)
        z = rms(y, s.pln)
        y = y + s.dw(F.silu(s.gw(z)) * s.uw(z))
        y = rms(y, s.fn)
        s.state_all[:] = torch.cat([torch.cat([kb.reshape(-1), vb.reshape(-1)]).view(1, ROW),
                                    F.pad((pos + 1).view(1), (0, ROW - 1)).view(1, ROW)], 0)
        return y.view(1, D)

def main():
    m = MTPAsset().eval()
    ref = MTP()
    # fidelity gate: 6 sequential steps, random-ish embeds/hiddens, compare outputs
    torch.manual_seed(7)
    cos_all = []
    with torch.no_grad():
        for t in range(6):
            e = torch.randn(D).half() * 0.02; hdd = torch.randn(D).half() * 0.5
            a = m(e.view(1, D), hdd.view(1, D)).view(-1).float()
            b = ref.draft(e, hdd, t).view(-1).float()
            cos_all.append(float(F.cosine_similarity(a, b, dim=0)))
    print(f">> MTPAsset vs reference: per-step cos = {[f'{c:.4f}' for c in cos_all]}")
    assert min(cos_all) > 0.99, "asset diverges from reference"
    print(">> ✅ fidelity gate passed — converting")
    ep = torch.export.export(m, (torch.zeros(1, D, dtype=torch.float16), torch.zeros(1, D, dtype=torch.float16)))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table()); ep = inject_subbyte_tensors(ep)
    states = list(ep.graph_signature.buffers_to_mutate.values()); assert states == ["state_all"], states
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["x_embed", "x_hidden"], output_names=["out"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    OUT = "/tmp/gdn_coreai/Qwen35fused_mtp_drafter_int8.aimodel"
    if Path(OUT).exists(): shutil.rmtree(OUT)
    prog.save_asset(Path(OUT))
    print(f">> ✅ Qwen35fused_mtp_drafter_int8: {(Path(OUT)/'main.mlirb').stat().st_size/1e6:.1f} MB (states={states})")

if __name__ == "__main__":
    main()
