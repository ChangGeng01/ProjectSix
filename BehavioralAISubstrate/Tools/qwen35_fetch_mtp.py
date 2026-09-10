#!/usr/bin/env python3
"""Ranged-fetch ONLY the mtp.* tensors from Qwen/Qwen3.5-4B (no 8GB download) -> /tmp/gdn_coreai/qwen35_mtp.npz"""
import json, struct, urllib.request, numpy as np
BASE="https://huggingface.co/Qwen/Qwen3.5-4B/resolve/main/"
def fetch(url, start=None, end=None):
    req=urllib.request.Request(url, headers={"User-Agent":"bas"})
    if start is not None: req.add_header("Range", f"bytes={start}-{end-1}")
    return urllib.request.urlopen(req, timeout=120).read()
idx=json.loads(fetch(BASE+"model.safetensors.index.json"))
wm=idx["weight_map"]; mtp={k:v for k,v in wm.items() if k.startswith("mtp.")}
print(f"mtp keys: {len(mtp)}")
by_shard={}
for k,v in mtp.items(): by_shard.setdefault(v,[]).append(k)
out={}
DT={"BF16":np.uint16,"F32":np.float32,"F16":np.float16}
for shard,keys in by_shard.items():
    url=BASE+shard
    n=struct.unpack("<Q", fetch(url,0,8))[0]
    hdr=json.loads(fetch(url,8,8+n)); base=8+n
    for k in keys:
        m=hdr[k]; s,e=m["data_offsets"]
        raw=fetch(url, base+s, base+e)
        a=np.frombuffer(raw, dtype=DT[m["dtype"]]).reshape(m["shape"])
        if m["dtype"]=="BF16": a=(a.astype(np.uint32)<<16).view(np.float32).astype(np.float16)
        out[k]=a
        print(f"  {k:48} {m['dtype']} {m['shape']} ({(e-s)/1e6:.1f} MB)")
np.savez("/tmp/gdn_coreai/qwen35_mtp.npz", **out)
print("saved -> /tmp/gdn_coreai/qwen35_mtp.npz")
