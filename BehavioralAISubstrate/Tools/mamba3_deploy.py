"""Deploy converter: a TRAINED Mamba-3 student (D=1024 + MLP + gnorm) -> CoreAI .aimodel for the A19 ANE.

Closes the loop train->deploy: reuses the PARITY-verified mamba3_trainable.Lyr (its per-token step_ref IS the
inference step), loads the trained weights, quantizes (int8/int4), and emits the 4 separate angle-first states
(angle/ssm/kprev/vprev — the flat-state SIGSEGV fix). Because Lyr is the exact training module, the deployed
graph is identical to what trained, no re-derivation. Loads /tmp/draft_coreai/mamba3_poc_student.pt if present.

Run: uv run --with coreai-torch python Tools/mamba3_deploy.py <L> <bits>   (e.g. 8 8)
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantEmbed, QuantLinear

import mamba3_trainable as MT

L = int(sys.argv[1]) if len(sys.argv) > 1 else 8
BITS = int(sys.argv[2]) if len(sys.argv) > 2 else 8
VOCAB = 100352                                                    # Granite tokenizer
CKPT = "/tmp/draft_coreai/mamba3_poc_student.pt"
OUT = f"/tmp/draft_coreai/Mamba3Deploy_L{L}_int{BITS}.aimodel"
H, P, N, R, D = MT.H, MT.P, MT.N, MT.R, MT.D_MODEL


class DeployM(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, D)
        self.layers = nn.ModuleList([MT.Lyr() for _ in range(L)])          # the TRAINING module — same math
        self.fw = nn.Parameter(torch.ones(D))
        self.register_buffer("angle_all", torch.zeros(L, H, N // 2))       # state 1 (FIRST)
        self.register_buffer("ssm_all", torch.zeros(L, H, P, N))           # state 2
        self.register_buffer("kprev_all", torch.zeros(L, H, R, N))         # state 3
        self.register_buffer("vprev_all", torch.zeros(L, H, P, R))         # state 4

    def quantize(self) -> "DeployM":
        for l in self.layers:
            l.in_proj = QuantLinear(l.in_proj.weight, BITS)
            l.out_proj = QuantLinear(l.out_proj.weight, BITS)
            l.mlp_gate = QuantLinear(l.mlp_gate.weight, BITS)
            l.mlp_up = QuantLinear(l.mlp_up.weight, BITS)
            l.mlp_down = QuantLinear(l.mlp_down.weight, BITS)
        self.embedding = QuantEmbed(self.embedding.weight, BITS)
        return self

    def forward(self, input_id):
        ew = self.embedding.weight_fp16()
        x = F.embedding(input_id, ew).view(D)
        na, ns, nk, nv = [], [], [], []
        for i, l in enumerate(self.layers):
            x, a, sm, k, v = l.step_ref(x, self.angle_all[i], self.ssm_all[i], self.kprev_all[i], self.vprev_all[i])
            na.append(a); ns.append(sm); nk.append(k); nv.append(v)
        self.angle_all[:] = torch.stack(na, 0); self.ssm_all[:] = torch.stack(ns, 0)
        self.kprev_all[:] = torch.stack(nk, 0); self.vprev_all[:] = torch.stack(nv, 0)
        x = MT.rms(x, self.fw)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main() -> None:
    torch.manual_seed(0)
    m = DeployM().eval()
    if Path(CKPT).exists():
        ck = torch.load(CKPT, map_location="cpu")
        ck_L = int(ck.get("layers", L))
        if ck_L != L:                                                  # REFUSE silent truncation (audit must-fix)
            raise SystemExit(f"checkpoint has {ck_L} layers but deploy L={L} — would be incoherent; run: "
                             f"mamba3_deploy.py {ck_L} {BITS}")
        missing, unexpected = m.load_state_dict(ck["model"], strict=False)
        assert not unexpected, f"checkpoint has tensors DeployM lacks: {unexpected[:3]}"
        bad = [k for k in missing if not k.endswith("_all")]          # only the decode-state buffers may be missing
        assert not bad, f"DeployM missing trained params (would deploy uninitialized): {bad[:3]}"
        print(f"loaded the FULL {ck_L}-layer trained student ({len(ck['model'])} tensors); decode state zero-init")
    else:
        print(f"no checkpoint at {CKPT} — converting random-init (op-graph + ANE deploy test)")

    m = m.quantize().half()
    _ = m(torch.zeros(1, 1, dtype=torch.long))
    ep = torch.export.export(m.eval(), (torch.zeros(1, 1, dtype=torch.long),))
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    st = list(ep.graph_signature.buffers_to_mutate.values()); print("states:", st)
    c = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=st, entrypoint_name="main")
    p = c.to_coreai(); p.optimize()
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True); p.save_asset(Path(OUT))
    print(f">> SAVED {OUT}  states={st}")
    print(f">> STATES env (angle;ssm;kprev;vprev): {L},{H},{N // 2};{L},{H},{P},{N};{L},{H},{R},{N};{L},{H},{P},{R}")


if __name__ == "__main__":
    main()
