#!/usr/bin/env python3
"""MTP acceptance measure (the go/no-go for the near-zero-cost drafter).
Main model = the VERIFIED shipped form (int8 + full-causal). MTP = the official 15-tensor head (int8), DeepSeek-style:
draft(t+2) = head( mtp.norm( block( fc( [preN_e(embed(n_{t+1})) ; preN_h(hidden_t)] ) ) ) ), shared embed/head.
Greedy rollout from the golden prompt; acceptance = P(draft_t == main's argmax at t+1). f (draft cost) ≈ MTP block
(~0.11B) + head reuse → the spec speedup ≈ (1+a)/(1+f·1)."""
import sys, numpy as np, torch, torch.nn.functional as F
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import RealGDN, load_st, raw, rms, dequant, D, GV, GHD
import qwen35_fixed_decode as fd
fd.MAXSEQ = 128   # extend the FA KV window for prompt32+steps64
from qwen35_fixed_decode import FAFull, NB, AKV, AHD, BASE, RD, is_lin
from llama_to_coreai_int8 import QuantLinear
P="language_model.model."; MAXSEQ=128; AH=16
M=np.load("/tmp/gdn_coreai/qwen35_mtp.npz")
def q8(w): return QuantLinear(torch.from_numpy(w.copy()).float(), NB)
def t16(k): return torch.from_numpy(M[k].copy()).half()
def rmsz(x, w):   # HF Qwen3Next zero-centered RMSNorm: y = rms(x) * (1 + w)
    return rms(x) * (1 + w)

class MTP:
    def __init__(s):
        s.fc=q8(M["mtp.fc.weight"]); s.qp=q8(M["mtp.layers.0.self_attn.q_proj.weight"])
        s.kp=q8(M["mtp.layers.0.self_attn.k_proj.weight"]); s.vp=q8(M["mtp.layers.0.self_attn.v_proj.weight"])
        s.op=q8(M["mtp.layers.0.self_attn.o_proj.weight"])
        s.gw=q8(M["mtp.layers.0.mlp.gate_proj.weight"]); s.uw=q8(M["mtp.layers.0.mlp.up_proj.weight"]); s.dw=q8(M["mtp.layers.0.mlp.down_proj.weight"])
        s.iln=t16("mtp.layers.0.input_layernorm.weight"); s.pln=t16("mtp.layers.0.post_attention_layernorm.weight")
        s.qn=t16("mtp.layers.0.self_attn.q_norm.weight"); s.kn=t16("mtp.layers.0.self_attn.k_norm.weight")
        s.nE=t16("mtp.pre_fc_norm_embedding.weight"); s.nH=t16("mtp.pre_fc_norm_hidden.weight"); s.fn=t16("mtp.norm.weight")
        s.kb=torch.zeros(MAXSEQ,AKV,AHD,dtype=torch.float16); s.vb=torch.zeros(MAXSEQ,AKV,AHD,dtype=torch.float16)
    def draft(s, emb_next, hidden, pos):
        u=s.fc(torch.cat([rmsz(emb_next,s.nE), rmsz(hidden,s.nH)]).half())     # [2560]
        h=rmsz(u,s.iln)
        qpo=s.qp(h).view(AH,-1); q,g=qpo[:,:AHD],qpo[:,AHD:]; gate=g.reshape(-1)
        k=s.kp(h).view(AKV,AHD); v=s.vp(h).view(AKV,AHD); q=rmsz(q,s.qn); k=rmsz(k,s.kn)
        inv=BASE**(-torch.arange(0,RD,2).float()/RD); ang=(torch.tensor([float(pos)])*inv).half()
        cos,sin=ang.cos(),ang.sin(); hf=RD//2
        def rope(t):
            tr,tp=t[:,:RD],t[:,RD:]; a,b=tr[:,:hf],tr[:,hf:]
            return torch.cat([torch.cat([a*cos-b*sin,a*sin+b*cos],-1),tp],-1)
        q=rope(q); k=rope(k)
        s.kb[pos]=k; s.vb[pos]=v
        kk=s.kb[:pos+1].repeat_interleave(AH//AKV,1).transpose(0,1); vv=s.vb[:pos+1].repeat_interleave(AH//AKV,1).transpose(0,1)
        sc=(q.unsqueeze(1).float()@kk.float().transpose(-1,-2)).squeeze(1)*(AHD**-0.5)
        out=(F.softmax(sc,-1).unsqueeze(1)@vv.float()).squeeze(1).reshape(-1).half()*torch.sigmoid(gate)
        y=u+s.op(out)
        y=y+s.dw(F.silu(s.gw(rmsz(y,s.pln)))*s.uw(rmsz(y,s.pln)))
        return rmsz(y,s.fn)

def main():
    st=load_st(); embed=dequant(st,P+"embed_tokens").half(); fnorm=raw(st,P+"norm.weight").half()
    layers=[]
    for i in range(32):
        if is_lin(i):
            g=RealGDN(st,i)
            for nm in ["qkv","a","b","z","o","gate","up","down"]:
                l=getattr(g,nm); setattr(g,nm,QuantLinear(l.weight.data.float(),NB))
            g.A_log.data=g.A_log.data.half(); g.dt_bias.data=g.dt_bias.data.half()
        else: g=FAFull(st,i)
        layers.append(g.eval())
    mtp=MTP()
    toks=list(np.load("/tmp/gdn_coreai/mlx_toks32.npy")); STEPS=64
    gs={i:torch.zeros(GV,GHD,GHD,dtype=torch.float16) for i in range(32) if is_lin(i)}
    gc={i:torch.zeros(3,8192,dtype=torch.float16) for i in range(32) if is_lin(i)}
    kb={i:torch.zeros(MAXSEQ,AKV,AHD,dtype=torch.float16) for i in range(32) if not is_lin(i)}
    vb={i:torch.zeros(MAXSEQ,AKV,AHD,dtype=torch.float16) for i in range(32) if not is_lin(i)}
    def step(tok,pos):
        h=embed[int(tok)]
        for i,l in enumerate(layers):
            if is_lin(i):
                h,s2,c2=l(h,gs[i],gc[i]); gs[i],gc[i]=s2,c2
            else:
                h,k2,v2=l(h,kb[i],vb[i],torch.tensor([float(pos)],dtype=torch.float16)); kb[i],vb[i]=k2,v2
        return h, int((rms(h,fnorm)@embed.t()).float().argmax())
    with torch.no_grad():
        pending=None; acc=[]; seq=list(toks); h=None; nxt=None
        for pos in range(len(toks)+STEPS):
            tok = seq[pos]
            h, nxt = step(tok, pos)
            if pending is not None: acc.append(1 if nxt==pending else 0)
            mo = mtp.draft(embed[nxt], h, pos)                       # [2560] fp16
            pending = int((mo.half() @ embed.t()).float().argmax())  # shared head
            if pos>=len(toks)-1: seq.append(nxt)
            if (pos+1)%16==0:
                a=np.mean(acc) if acc else 0
                print(f"  pos={pos+1} accepts={sum(acc)}/{len(acc)} a={a:.3f}")
        a=np.mean(acc); f=0.18   # MTP block ~0.11B + head reuse vs 4B main (bandwidth est)
        print(f">> MTP ACCEPTANCE: a={a:.3f} over {len(acc)} steps (greedy self-trajectory, int8 shipped form)")
        print(f">> est. spec speedup (K=1): (1+a)/(1+f)={ (1+a)/(1+f):.2f}x  [f≈{f} draft-cost ratio]")
        print(">> "+("✅ MTP lever is REAL — wire it" if a>=0.55 else "❌ acceptance too low — MTP lever dead"))
if __name__=="__main__":
    main()
