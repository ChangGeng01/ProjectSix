"""Device StateLake prep — writes a .statelake bundle of the 6 DECODE-READY states (the form the device decode asset
consumes) + the host reference, so the on-device Swift reader can be proven: a state serialized to disk is rehydrated on
the A19 and decodes IDENTICALLY (cross-launch persistence), fail-closed on a wrong binding-key.

Format (the Swift BASStateLakeReader spec):
  <dir>/header.json : {binding_key, prompt_len, max_seq, precision:"int8", checksum(sha256 of payload),
                       tensors:[{name, shape, scale, start, nbytes}]}  — names: angle_all/ssm_all/kprev_all/vprev_all/mla_kv/mla_fill
  <dir>/payload.bin : concatenated int8 blobs (mla_fill stored fp16 — it is an offset, not a quantizable activation)

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_statelake_device_prep.py
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

import numpy as np
import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY
import mamba3_statelake as SL
from mamba3_hybrid_decode_deploy import HybridDecodeFixed, MAX_SEQ

VOCAB, L, PROMPT, CONT = 4096, 24, 64, 32
OUT = "/tmp/draft_coreai/decode_state.statelake"


def _q_int8(t):
    scale = t.abs().max().clamp_min(1e-12).item() / 127.0
    return torch.round(t / scale).clamp(-127, 127).to(torch.int8).cpu().numpy(), scale


def write_statelake(states: dict, prompt_len: int, bkey: str, out: str) -> dict:
    blob, recs, off = bytearray(), [], 0
    for name, t in states.items():
        if name == "mla_fill":                                       # offset, not an activation → keep fp16 exact
            raw = t.to(torch.float16).cpu().numpy().tobytes(); scale, dt = 1.0, "fp16"
        else:
            q, scale = _q_int8(t); raw = q.tobytes(); dt = "int8"
        blob += raw
        recs.append({"name": name, "shape": list(t.shape), "scale": scale, "dtype": dt, "start": off, "nbytes": len(raw)})
        off += len(raw)
    blob = bytes(blob)
    header = {"binding_key": bkey, "prompt_len": prompt_len, "max_seq": MAX_SEQ, "precision": "int8",
              "checksum": hashlib.sha256(blob).hexdigest(), "tensors": recs, "format": "statelake-device/1"}
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "payload.bin"), "wb").write(blob)
    json.dump(header, open(os.path.join(out, "header.json"), "w"), indent=2)
    return header


def read_statelake(out: str, expected_bkey: str) -> dict:
    h = json.load(open(os.path.join(out, "header.json")))
    if h["binding_key"] != expected_bkey:
        raise SL.StateLakeError("binding-key mismatch")
    blob = open(os.path.join(out, "payload.bin"), "rb").read()
    assert hashlib.sha256(blob).hexdigest() == h["checksum"], "checksum mismatch"
    npd = {"int8": np.int8, "fp16": np.float16}
    states = {}
    for r in h["tensors"]:
        a = np.frombuffer(blob[r["start"]:r["start"] + r["nbytes"]], dtype=npd[r["dtype"]]).reshape(r["shape"])
        t = torch.from_numpy(a.copy()).to(torch.float32)
        states[r["name"]] = t * r["scale"] if r["dtype"] == "int8" else t
    return states


def main() -> None:
    torch.manual_seed(0)
    m = HY.HybridM(VOCAB, L).float().eval()
    seq = torch.tensor([(i * 17 + 5) % VOCAB for i in range(PROMPT + CONT)])    # deterministic, mirrors the duet probe
    with torch.no_grad():
        _, st = m.prefill(seq[:PROMPT])
        dec = HybridDecodeFixed(VOCAB, L, MAX_SEQ).float().eval()
        dec.m.load_state_dict(m.state_dict())                        # SAME seed-0 weights as the device asset
        dec.load_prefill(st, PROMPT)                                 # build the 6 decode-ready buffers (stack mamba + scatter mla)
        states = {"angle_all": dec.angle_all, "ssm_all": dec.ssm_all, "kprev_all": dec.kprev_all,
                  "vprev_all": dec.vprev_all, "mla_kv": dec.mla_kv, "mla_fill": dec.mla_fill}
    bkey = SL.binding_key(m, "int8", MAX_SEQ, True)
    write_statelake(states, PROMPT, bkey, OUT)
    sz = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"wrote {OUT} ({sz / 1e6:.2f} MB)  binding_key={bkey}")

    # HOST reference: read the .statelake back (int8 dequant) → decode cont via the SAME fixed-buffer logic the device runs
    got = read_statelake(OUT, bkey)
    d2 = HybridDecodeFixed(VOCAB, L, MAX_SEQ).float().eval()
    d2.m.load_state_dict(m.state_dict())
    for k, v in got.items():
        getattr(d2, k).copy_(v)
    with torch.no_grad():
        arg = torch.stack([d2(seq[PROMPT + t].view(1, 1))[0] for t in range(CONT)]).argmax(-1).tolist()
    print(f"HOSTREF_STATELAKE_ARGMAX={','.join(map(str, arg))}")
    print("READ: the device BAS_COREAI_STATELAKE_PROBE must read this .statelake (fail-closed on bkey), init the decode "
          "session, and reproduce this argmax — proving cross-launch persistence on the A19.")


if __name__ == "__main__":
    main()
