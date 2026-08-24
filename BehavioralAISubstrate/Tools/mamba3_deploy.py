"""Deploy converter: a TRAINED Mamba-3 student (D=1024 + MLP + gnorm) -> CoreAI .aimodel for the A19 ANE.

Closes the loop train->deploy: reuses the PARITY-verified mamba3_trainable.Lyr (its per-token step_ref IS the
inference step), loads the trained weights, quantizes (int8/int4), and emits the 4 separate angle-first states
(angle/ssm/kprev/vprev — the flat-state SIGSEGV fix). Because Lyr is the exact training module, the deployed
graph is identical to what trained, no re-derivation. Loads /tmp/draft_coreai/mamba3_poc_student.pt if present.

Run: uv run --with coreai-torch python Tools/mamba3_deploy.py <L> <bits>   (e.g. 8 8)
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

_TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_TOOLS_DIR))
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantEmbed, QuantLinear
from qinao_checkpoint_guard import (  # noqa: E402
    DEFAULT_MAX_BYTES,
    CheckpointVerificationError,
    load_verified_weights_checkpoint,
)

import mamba3_trainable as MT

L = int(sys.argv[1]) if len(sys.argv) > 1 else 8
BITS = int(sys.argv[2]) if len(sys.argv) > 2 else 8
VOCAB = 100352                                                    # Granite tokenizer
CKPT = os.environ.get("CKPT", "/tmp/draft_coreai/mamba3_poc_student.pt")   # cloud output → set CKPT=/workspace/ckpt/ckpt_latest.pt
_TAG = (f"_{os.environ['SPLIT']}" if os.environ.get("SPLIT") else "") + \
       ("_fp16" if os.environ.get("FP16") == "1" else "") + \
       (f"_n{MT.N}p{MT.P}" if (MT.N, MT.P) != (64, 64) else "") + \
       ("_leanmlp" if os.environ.get("LEAN_MLP") == "1" else "") + \
       (f"_{os.environ['STATE_WRITE']}" if os.environ.get("STATE_WRITE") else "") + \
       (f"_s{os.environ['SEED']}" if os.environ.get("SEED") else "")
OUT = f"/tmp/draft_coreai/Mamba3Deploy_L{L}_int{BITS}{_TAG}.aimodel"
H, P, N, R, D = MT.H, MT.P, MT.N, MT.R, MT.D_MODEL


def _checkpoint_max_bytes() -> int:
    configured = os.environ.get("CKPT_MAX_BYTES")
    if configured is None:
        return DEFAULT_MAX_BYTES
    if not configured.isascii() or not configured.isdecimal():
        raise CheckpointVerificationError("CKPT_MAX_BYTES must be a positive integer")
    value = int(configured)
    if value <= 0:
        raise CheckpointVerificationError("CKPT_MAX_BYTES must be a positive integer")
    return value


class DeployM(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, D)
        self.layers = nn.ModuleList([MT.Lyr() for _ in range(L)])          # the TRAINING module — same math
        self.fw = nn.Parameter(torch.ones(D))
        if os.environ.get("STATE_WRITE") == "separate":
            # 4*L SEPARATE per-layer state buffers — NO [L,...] stacked tensor, so NO integer-index/gather of a
            # too-big buffer (the suspected source of "ANE cannot handle intermediate tensor type" at L=16).
            for i in range(L):
                self.register_buffer(f"angle_{i}", torch.zeros(H, N // 2))
                self.register_buffer(f"ssm_{i}", torch.zeros(H, P, N))
                self.register_buffer(f"kprev_{i}", torch.zeros(H, R, N))
                self.register_buffer(f"vprev_{i}", torch.zeros(H, P, R))
        else:
            self.register_buffer("angle_all", torch.zeros(L, H, N // 2))    # state 1 (FIRST)
            self.register_buffer("ssm_all", torch.zeros(L, H, P, N))        # state 2
            self.register_buffer("kprev_all", torch.zeros(L, H, R, N))      # state 3
            self.register_buffer("vprev_all", torch.zeros(L, H, P, R))      # state 4

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
        import os
        ew = self.embedding.weight_fp16() if hasattr(self.embedding, "weight_fp16") else self.embedding.weight
        split = os.environ.get("SPLIT", "")
        if split:                                                      # multi-process 2x8: HEAD=embed+L layers->hidden;
            x = input_id.view(D) if split == "tail" else F.embedding(input_id, ew).view(D)   # TAIL=hidden->L layers+head->logits
            na, ns, nk, nv = [], [], [], []
            for i, l in enumerate(self.layers):
                x, a, sm, k, v = l.step_ref(x, self.angle_all[i], self.ssm_all[i], self.kprev_all[i], self.vprev_all[i])
                na.append(a); ns.append(sm); nk.append(k); nv.append(v)
            self.angle_all[:] = torch.stack(na, 0); self.ssm_all[:] = torch.stack(ns, 0)
            self.kprev_all[:] = torch.stack(nk, 0); self.vprev_all[:] = torch.stack(nv, 0)
            if split == "head":
                return x.view(1, D)                                    # boundary hidden out (to the tail process)
            return (MT.rms(x, self.fw) @ ew.to(x.dtype).t()).view(1, VOCAB)
        x = F.embedding(input_id, ew).view(D)
        mode = os.environ.get("STATE_WRITE", "stack")
        if mode == "separate":
            # each layer reads + writes its OWN buffer (.copy_), no [L,...] indexing at all
            for i, l in enumerate(self.layers):
                a_in = getattr(self, f"angle_{i}"); ssm_in = getattr(self, f"ssm_{i}")
                k_in = getattr(self, f"kprev_{i}"); v_in = getattr(self, f"vprev_{i}")
                x, a, sm, k, v = l.step_ref(x, a_in, ssm_in, k_in, v_in)
                a_in.copy_(a); ssm_in.copy_(sm); k_in.copy_(k); v_in.copy_(v)
            x = MT.rms(x, self.fw)
            return (x @ ew.to(x.dtype).t()).view(1, VOCAB)
        if mode == "inplace":
            # PER-LAYER in-place state write: each layer's 4 states are written back immediately, so at most ONE
            # layer's state is LIVE at a time (O(1) working set). Tests the ANE-SRAM-liveness ceiling hypothesis vs
            # the stack-then-write path below, which keeps all L layers' new states live simultaneously (O(L)).
            for i, l in enumerate(self.layers):
                x, a, sm, k, v = l.step_ref(x, self.angle_all[i], self.ssm_all[i], self.kprev_all[i], self.vprev_all[i])
                self.angle_all[i] = a; self.ssm_all[i] = sm; self.kprev_all[i] = k; self.vprev_all[i] = v
        else:
            na, ns, nk, nv = [], [], [], []
            for i, l in enumerate(self.layers):
                x, a, sm, k, v = l.step_ref(x, self.angle_all[i], self.ssm_all[i], self.kprev_all[i], self.vprev_all[i])
                na.append(a); ns.append(sm); nk.append(k); nv.append(v)
            self.angle_all[:] = torch.stack(na, 0); self.ssm_all[:] = torch.stack(ns, 0)
            self.kprev_all[:] = torch.stack(nk, 0); self.vprev_all[:] = torch.stack(nv, 0)
        x = MT.rms(x, self.fw)
        return (x @ ew.to(x.dtype).t()).view(1, VOCAB)


def main() -> None:
    import os
    torch.manual_seed(int(os.environ.get("SEED", "0")))      # SEED varies content → busts the device ANE compile cache
    m = DeployM().eval()
    if os.environ.get("FORCE_RANDOM") == "1":
        print(f"FORCE_RANDOM: L={L} random-weight compile probe (no checkpoint)")
    elif Path(CKPT).exists():
        try:
            ck = load_verified_weights_checkpoint(
                CKPT,
                os.environ.get("CKPT_SHA256"),
                max_bytes=_checkpoint_max_bytes(),
            )
        except CheckpointVerificationError as error:
            raise SystemExit(f"checkpoint refused: {error}") from None
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
        raise SystemExit(f"no checkpoint at {CKPT} — refusing a silent random-weight production asset; "
                         f"set CKPT=/path/ckpt_best.pt, or FORCE_RANDOM=1 for an op-graph/ANE-deploy probe")

    m = (m if os.environ.get("FP16") == "1" else m.quantize()).half()   # FP16: skip int8 quant — clean fp16 ceiling test
    _split = os.environ.get("SPLIT", "")
    in_name = "hidden" if _split == "tail" else "input_id"
    out_name = "hidden_out" if _split == "head" else "logits"
    ex_in = (torch.zeros(1, D, dtype=torch.float16),) if _split == "tail" else (torch.zeros(1, 1, dtype=torch.long),)
    _ = m(*ex_in)
    ep = torch.export.export(m.eval(), ex_in)
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    st = list(ep.graph_signature.buffers_to_mutate.values()); print("states:", st)
    c = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=[in_name], output_names=[out_name], state_names=st, entrypoint_name="main")
    p = c.to_coreai(); p.optimize()
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True); p.save_asset(Path(OUT))
    print(f">> SAVED {OUT}  states={st}")
    print(f">> STATES env (angle;ssm;kprev;vprev): {L},{H},{N // 2};{L},{H},{P},{N};{L},{H},{R},{N};{L},{H},{P},{R}")


if __name__ == "__main__":
    main()
