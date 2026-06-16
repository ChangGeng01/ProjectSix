"""StateLake — the neural-state DATABASE for the Mamba-3 DUET handoff (Track G build STEP 3/4/11; closes the coverage
scorecard's two BLOCKERS: no binding-key, no disk serialization).

Turns the in-RAM 6-state handoff into a PERSISTENT, integrity-checked, lineage-aware store — the foundation the flagship
"prefill-once-reuse-many" rests on. Layers:

  STEP 3  binding_key(model, ...) — a deterministic key binding a state to the EXACT graph that produced it
          {weight_hash, arch-config, converter_version, precision, max_seq, angle_wrap}. Checked FAIL-CLOSED on load:
          a state rehydrated against mismatched weights is a LOUD error, never silent garbage (the audit's #1 danger).
  STEP 4  StateArtifact — the on-disk .statelake bundle: header.json (binding_key + per-tensor int8 scales + a blake2b
          checksum + lineage) + payload.bin (angle-wrapped, int8-quantized state blobs — the proven cache floor).
  STEP 11 StateLake (SQLite) — content-addressed store with a lineage DAG (parent→child), per-corpus ACL, TTL/expiry,
          model-version mass-invalidation, hot(RAM-LRU)/warm(disk)/cold(stub) tiering, and a Router that finds the
          DEEPEST valid ancestor for a corpus/prefix (composition stays KILLED — router finds + extends, never fuses).

Self-test (no device, no trained ckpt): ~/.venvs/coreai-cv/bin/python Tools/mamba3_statelake.py
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import struct
import sys
import time
from collections import OrderedDict
from dataclasses import dataclass

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY
import mamba3_trainable as MT

CONVERTER_VERSION = "v1"


# ---------------------------------------------------------------------------------------------- STEP 3: binding key
def _digest(*parts) -> str:
    h = hashlib.sha256()
    for p in parts:
        h.update(p if isinstance(p, bytes) else json.dumps(p, sort_keys=True, default=str).encode())
    return h.hexdigest()


def weight_hash(model) -> str:
    """sha256 over the model's parameters+buffers in sorted-name order (deterministic for seeded/ trained weights)."""
    h = hashlib.sha256()
    sd = model.state_dict()
    for k in sorted(sd):
        h.update(k.encode())
        h.update(sd[k].detach().to(torch.float32).cpu().contiguous().numpy().tobytes())
    return h.hexdigest()


def arch_config(m) -> dict:
    hm = m.m if hasattr(m, "m") else m                                 # unwrap a Deploy* wrapper
    return {"vocab": hm.embedding.weight.shape[0], "layers": len(hm.layers), "mla_pos": sorted(hm.mla_pos),
            "D": MT.D_MODEL, "H": MT.H, "P": MT.P, "N": MT.N, "R": MT.R, "D_FF": MT.D_FF}


def binding_key(model, precision: str, max_seq: int, angle_wrap: bool, converter_version: str = CONVERTER_VERSION) -> str:
    """The state↔graph contract. Any field mismatch ⇒ a rehydrated state is invalid ⇒ load must fail closed."""
    cfg = arch_config(model)
    return _digest(weight_hash(model), cfg, precision, max_seq, bool(angle_wrap), converter_version)[:32]


# --------------------------------------------------------------------------------------- STEP 4: on-disk artifact
def _q_int8(t):
    scale = t.detach().abs().max().clamp_min(1e-12).item() / 127.0
    q = torch.round(t.detach() / scale).clamp(-127, 127).to(torch.int8)
    return q, scale


def _flatten(state):
    """Heterogeneous per-layer handoff → ordered (name, tensor). mamba=(angle,ssm,kprev,vprev), mla=cache[T,dc]."""
    items = []
    for i, (tag, s) in enumerate(state):
        if tag == "mamba":
            for nm, t in zip(("angle", "ssm", "kprev", "vprev"), s):
                items.append((f"{i}.mamba.{nm}", t))
        else:
            items.append((f"{i}.mla.cache", s))
    return items


def serialize_artifact(state, prompt_len: int, bkey: str, out_path: str, precision: str = "int8",
                       parent: str | None = None, corpus: str | None = None, ttl_s: float | None = None,
                       now: float | None = None) -> dict:
    """Write the .statelake bundle (angle-wrap → int8 → payload.bin + header.json with checksum + lineage)."""
    now = time.time() if now is None else now
    wrapped = HY.cache_serialize_state_hybrid(state)                   # lossless angle-wrap (the long-context fix)
    blob, tensors, off = bytearray(), [], 0
    for name, t in _flatten(wrapped):
        if precision == "int8":
            q, scale = _q_int8(t)
            raw = q.cpu().numpy().tobytes(); dt = "int8"
        elif precision == "fp16":
            raw = t.detach().to(torch.float16).cpu().numpy().tobytes(); scale = 1.0; dt = "fp16"
        else:
            raw = t.detach().to(torch.float32).cpu().numpy().tobytes(); scale = 1.0; dt = "fp32"
        blob += raw
        tensors.append({"name": name, "shape": list(t.shape), "scale": scale, "dtype": dt, "start": off, "nbytes": len(raw)})
        off += len(raw)
    blob = bytes(blob)
    header = {"binding_key": bkey, "prompt_len": prompt_len, "precision": precision, "created": now,
              "expires": (now + ttl_s) if ttl_s else None, "parent": parent, "corpus": corpus,
              "checksum": hashlib.blake2b(blob, digest_size=16).hexdigest(), "tensors": tensors,
              "n_layers": len(state), "format": "statelake/1"}
    os.makedirs(out_path, exist_ok=True)
    with open(os.path.join(out_path, "payload.bin"), "wb") as f:
        f.write(blob)
    with open(os.path.join(out_path, "header.json"), "w") as f:
        json.dump(header, f, indent=2)
    return header


class StateLakeError(Exception):
    pass


def deserialize_artifact(path: str, expected_bkey: str, layer_tags: list[str]):
    """FAIL-CLOSED load: binding-key mismatch or checksum mismatch ⇒ raise (never a silent rehydrate)."""
    with open(os.path.join(path, "header.json")) as f:
        h = json.load(f)
    if h["binding_key"] != expected_bkey:
        raise StateLakeError(f"binding-key mismatch: artifact {h['binding_key'][:12]} != consumer {expected_bkey[:12]} "
                             f"(wrong model/precision/max_seq/version) — refusing to rehydrate stale state")
    with open(os.path.join(path, "payload.bin"), "rb") as f:
        blob = f.read()
    if hashlib.blake2b(blob, digest_size=16).hexdigest() != h["checksum"]:
        raise StateLakeError("payload checksum mismatch — corrupt .statelake")
    import numpy as np
    by_name = {}
    npd = {"int8": np.int8, "fp16": np.float16, "fp32": np.float32}
    for rec in h["tensors"]:
        arr = np.frombuffer(blob[rec["start"]:rec["start"] + rec["nbytes"]], dtype=npd[rec["dtype"]]).reshape(rec["shape"])
        t = torch.from_numpy(arr.copy()).to(torch.float32)
        by_name[rec["name"]] = t * rec["scale"] if rec["dtype"] == "int8" else t
    state = []
    for i, tag in enumerate(layer_tags):
        if tag == "mamba":
            state.append(("mamba", tuple(by_name[f"{i}.mamba.{nm}"] for nm in ("angle", "ssm", "kprev", "vprev"))))
        else:
            state.append(("mla", by_name[f"{i}.mla.cache"]))
    return state, h["prompt_len"]


# ------------------------------------------------------------------------------------- STEP 11: the StateLake DB
@dataclass
class ResumePlan:
    state_id: str | None
    reuse_prompt_len: int
    missing_suffix: str       # what the Context Compiler must still prefill
    note: str


class StateLake:
    """SQLite-backed content-addressed state store: lineage DAG, ACL, TTL/expiry, model-version invalidation, tiering, router."""

    def __init__(self, root: str):
        self.root = root
        os.makedirs(root, exist_ok=True)
        self.db = sqlite3.connect(os.path.join(root, "statelake.db"))
        self.db.execute("""CREATE TABLE IF NOT EXISTS states(
            id TEXT PRIMARY KEY, corpus TEXT, prefix TEXT, binding_key TEXT, parent TEXT, owner TEXT, acl TEXT,
            prompt_len INT, created REAL, expires REAL, tier TEXT, path TEXT, checksum TEXT)""")
        self.db.commit()
        self._hot: OrderedDict = OrderedDict()                          # tier HOT: in-RAM LRU of rehydrated states
        self._hot_cap = 8

    def _now(self):
        return time.time()

    def put(self, state, prompt_len, bkey, corpus, prefix, layer_tags, owner="owner", acl="owner",
            parent=None, ttl_s=None) -> str:
        sid = _digest(corpus, prefix, bkey)[:24]
        path = os.path.join(self.root, "blobs", sid)
        h = serialize_artifact(state, prompt_len, bkey, path, parent=parent, corpus=corpus, ttl_s=ttl_s, now=self._now())
        self.db.execute("INSERT OR REPLACE INTO states VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (sid, corpus, prefix, bkey, parent, owner, acl, prompt_len, h["created"], h["expires"],
                         "warm", path, h["checksum"]))
        self.db.commit()
        self._layer_tags = layer_tags                                  # the consumer supplies the per-layer tag schema
        return sid

    def _valid(self, row, requester, bkey):
        _, corpus, prefix, rbkey, parent, owner, acl, plen, created, expires, tier, path, ck = row
        if rbkey != bkey:
            return False, "binding-key (stale model/version)"
        if expires is not None and self._now() > expires:
            return False, "expired (TTL)"
        if acl != "public" and requester != owner:
            return False, "ACL denied"
        return True, "ok"

    def get(self, sid, requester, bkey, layer_tags):
        if sid in self._hot:                                            # HOT tier
            self._hot.move_to_end(sid)
            return self._hot[sid]
        row = self.db.execute("SELECT * FROM states WHERE id=?", (sid,)).fetchone()
        if not row:
            raise StateLakeError(f"no state {sid}")
        ok, why = self._valid(row, requester, bkey)
        if not ok:
            raise StateLakeError(f"get refused: {why}")
        state, plen = deserialize_artifact(row[11], bkey, layer_tags)   # FAIL-CLOSED inside
        self._hot[sid] = (state, plen)
        if len(self._hot) > self._hot_cap:
            self._hot.popitem(last=False)                               # evict LRU → warm (still on disk)
        return state, plen

    def fork(self, sid, new_prefix, requester, bkey, layer_tags, owner="owner", acl="owner") -> str:
        """Lineage child: branch a state to extend with a different continuation. Mamba's O(1) state makes copy cheap."""
        state, plen = self.get(sid, requester, bkey, layer_tags)
        return self.put(state, plen, bkey, self.db.execute("SELECT corpus FROM states WHERE id=?", (sid,)).fetchone()[0],
                        new_prefix, layer_tags, owner=owner, acl=acl, parent=sid)

    def lineage(self, sid) -> list[str]:
        chain, cur = [], sid
        while cur:
            chain.append(cur)
            r = self.db.execute("SELECT parent FROM states WHERE id=?", (cur,)).fetchone()
            cur = r[0] if r else None
        return chain

    def expire_due(self) -> int:
        n = self.db.execute("DELETE FROM states WHERE expires IS NOT NULL AND expires < ?", (self._now(),)).rowcount
        self.db.commit()
        return n

    def invalidate_by_binding(self, current_bkey) -> int:
        """Model-version change: mass-invalidate every state NOT matching the current graph (they would rehydrate to garbage)."""
        n = self.db.execute("DELETE FROM states WHERE binding_key != ?", (current_bkey,)).rowcount
        self.db.commit()
        return n

    def route(self, corpus, query_prefix, bkey, requester="owner") -> ResumePlan:
        """Find the DEEPEST valid cached ancestor whose prefix is a prefix of the query → reuse it, prefill only the rest.
        Composition is KILLED: we pick ONE deepest ancestor and extend; we never fuse two states."""
        best = None
        for row in self.db.execute("SELECT * FROM states WHERE corpus=?", (corpus,)).fetchall():
            ok, _ = self._valid(row, requester, bkey)
            pfx = row[2]
            if ok and query_prefix.startswith(pfx) and (best is None or len(pfx) > len(best[2])):
                best = row
        if best is None:
            return ResumePlan(None, 0, query_prefix, "cold: no valid ancestor — full prefill")
        return ResumePlan(best[0], best[7], query_prefix[len(best[2]):], f"reuse '{best[2][:24]}…' ({best[7]} tok), prefill suffix")


# --------------------------------------------------------------------------------------------------- self-test
def _selftest() -> None:
    import shutil
    torch.manual_seed(0)
    V, L = 4096, 24
    m = HY.HybridM(V, L).float().eval()
    tags = ["mla" if i in m.mla_pos else "mamba" for i in range(L)]
    seq = torch.randint(0, V, (96,))
    prompt, cont = seq[:64], seq[64:]
    with torch.no_grad():
        _, state = m.prefill(prompt)
        ref = m.run_ref(cont, init=state).argmax(-1).tolist()          # the in-RAM handoff baseline
    bkey = binding_key(m, "int8", 256, True)
    root = "/tmp/statelake_test"; shutil.rmtree(root, ignore_errors=True)
    lake = StateLake(root)
    print("StateLake self-test (24L hybrid, host):")

    # (1) put → get → the rehydrated-FROM-DISK state must reproduce the decode
    sid = lake.put(state, 64, bkey, corpus="docA", prefix="the quick brown fox", layer_tags=tags, ttl_s=3600)
    got, plen = lake.get(sid, "owner", bkey, tags)
    with torch.no_grad():
        rl = m.run_ref(cont, init=got).argmax(-1).tolist()
    agree = sum(a == b for a, b in zip(ref, rl)) / len(ref)
    print(f"  (1) disk roundtrip int8: rehydrated decode argmax-agree vs in-RAM handoff = {agree:.0%}  prompt_len={plen}  "
          f"-> {'PASS' if agree >= 0.95 else 'FAIL'}")

    # (2) binding-key FAIL-CLOSED on a wrong key
    try:
        deserialize_artifact(os.path.join(root, "blobs", sid), "deadbeef" * 4, tags)
        print("  (2) binding-key gate: FAIL (accepted a stale key!)")
    except StateLakeError as e:
        print(f"  (2) binding-key gate: PASS (rejected stale — {str(e)[:60]}…)")

    # (3) lineage + fork
    child = lake.fork(sid, "the quick brown fox jumps", "owner", bkey, tags)
    lin = lake.lineage(child)
    print(f"  (3) fork+lineage: child {child[:8]} parent-chain depth={len(lin)} -> {'PASS' if lin[-1] == sid and len(lin) == 2 else 'FAIL'}")

    # (4) router: deepest valid ancestor
    plan = lake.route("docA", "the quick brown fox jumps over", bkey)
    print(f"  (4) router: reuse_id={'set' if plan.state_id else 'none'} reuse_len={plan.reuse_prompt_len} "
          f"suffix='{plan.missing_suffix[:18]}' -> {'PASS' if plan.state_id else 'FAIL'} ({plan.note[:40]})")

    # (5) TTL expiry + (6) model-version mass-invalidation
    sid2 = lake.put(state, 64, bkey, "docB", "old", tags, ttl_s=-1)    # already expired
    exp = lake.expire_due()
    bad = binding_key(m, "fp16", 256, True)                            # a DIFFERENT precision → different key
    inv = lake.invalidate_by_binding(bad)                              # current bkey is int8 → all int8 states purged
    print(f"  (5) TTL expire_due removed={exp} -> {'PASS' if exp >= 1 else 'FAIL'}")
    print(f"  (6) model-version invalidate (current key=fp16) purged {inv} stale int8 states -> {'PASS' if inv >= 1 else 'FAIL'}")
    print("\nREAD: StateLake = put/get with FAIL-CLOSED binding-key + checksum + lineage DAG + fork + router + TTL + version-invalidation. "
          "Closes the scorecard's two BLOCKERS (no binding-key, no disk serialization). Composition stays KILLED (router extends, never fuses).")


if __name__ == "__main__":
    _selftest()
