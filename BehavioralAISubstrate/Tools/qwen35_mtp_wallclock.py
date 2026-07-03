#!/usr/bin/env python3
"""END-TO-END wall-clock: MTP-spec(K=1) vs plain greedy, SAME verified int8 torch port (CPU; ratio is the point).
Spec loop: each iter = 1 MTP draft + ONE T=2 trunk forward (weights read once; GDN recurrence loops 2 steps
capturing the MID state → on reject, adopt mid state, no refeed). Yields 1+accept tokens per iter.
Caveat: CPU wall-clock — the MLX-GPU/device lane ratio is the production number (next step)."""
import sys, time, numpy as np, torch, torch.nn.functional as F
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import RealGDN, load_st, raw, rms, dequant, D, GV, GHD, KEYDIM
import qwen35_fixed_decode as fd
fd.MAXSEQ = 256
from qwen35_fixed_decode import FAFull, NB, AKV, AHD, BASE, RD, is_lin
from llama_to_coreai_int8 import QuantLinear
from qwen35_mtp_acceptance import MTP   # zero-centered-fixed MTP
fd.MAXSEQ = 256   # re-assert AFTER acceptance module set it to 128 at import
P="language_model.model."; AH=16; MAX=256; GK=16

def rope_batch(t, positions):        # t [T,H,256]
    inv=BASE**(-torch.arange(0,RD,2).float()/RD)
    ang=(positions.float()[:,None]*inv[None,:]).half()
    cos,sin=ang.cos()[:,None,:],ang.sin()[:,None,:]
    tr,tp=t[...,:RD],t[...,RD:]; hf=RD//2; x1,x2=tr[...,:hf],tr[...,hf:]
    return torch.cat([torch.cat([x1*cos-x2*sin,x1*sin+x2*cos],-1),tp],-1)

def gdn2(g, x2, state, convwin):     # x2 [2,D] → (h2 [2,D], stateMid, stateEnd, convwinEnd)
    h=rms(x2,g.iln)                   # [2,D]
    qkv=g.qkv(h)                      # [2,8192] one weight read
    win=torch.cat([convwin,qkv],0)    # [3+2,8192]
    conv=torch.stack([F.silu((win[t:t+4].t()*g.convw.view(8192,4)).sum(-1)) for t in range(2)])  # [2,8192]
    q=conv[:,:KEYDIM].view(2,GK,GHD); k=conv[:,KEYDIM:2*KEYDIM].view(2,GK,GHD); v=conv[:,2*KEYDIM:].view(2,GV,GHD)
    inv=GHD**-0.5
    q=((inv*inv)*rms(q)).repeat_interleave(GV//GK,1); k=(inv*rms(k)).repeat_interleave(GV//GK,1)
    decay=torch.exp(-torch.exp(g.A_log)*F.softplus(g.a(h)+g.dt_bias))  # [2,32]
    beta=torch.sigmoid(g.b(h)); z=g.z(h).view(2,GV,GHD)
    S=state; outs=[]; mid=None
    for t in range(2):
        S=S*decay[t].view(GV,1,1).half()
        kv=(S*k[t].view(GV,1,GHD)).sum(-1)
        S=S+k[t].view(GV,1,GHD)*((v[t]-kv)*beta[t].view(GV,1)).view(GV,GHD,1)
        outs.append((S*q[t].view(GV,1,GHD)).sum(-1))
        if t==0: mid=S
    y=torch.stack(outs)               # [2,GV,GHD]
    y=(rms(y,g.gn)*F.silu(z)).reshape(2,GV*GHD)
    h2=x2+g.o(y)
    h2=h2+g.down(F.silu(g.gate(rms(h2,g.pln)))*g.up(rms(h2,g.pln)))
    return h2, mid, S, win[2:5], win[1:4]   # convwinEnd (after 2), convwinMid (after 1)

def fa2(s, x2, kbuf, vbuf, pos):     # FAFull weights; x2 [2,D]; write pos & pos+1; causal 2-query attention
    h=rms(x2,s.iln)
    qpo=s.qp(h).view(2,AH,-1); q,g=qpo[...,:AHD],qpo[...,AHD:]; gate=g.reshape(2,-1)
    k=s.kp(h).view(2,AKV,AHD); v=s.vp(h).view(2,AKV,AHD)
    q=rms(q,s.qn); k=rms(k,s.kn)
    positions=torch.tensor([float(pos),float(pos+1)])
    q=rope_batch(q,positions); k=rope_batch(k,positions)
    kbuf[pos]=k[0]; kbuf[pos+1]=k[1]; vbuf[pos]=v[0]; vbuf[pos+1]=v[1]
    kk=kbuf[:pos+2].repeat_interleave(AH//AKV,1).transpose(0,1)   # [AH,pos+2,256]
    vv=vbuf[:pos+2].repeat_interleave(AH//AKV,1).transpose(0,1)
    qq=q.transpose(0,1)                                            # [AH,2,256]
    sc=(qq.float()@kk.float().transpose(-1,-2))*(AHD**-0.5)        # [AH,2,pos+2]
    sc[:,0,pos+1]=float('-inf')                                    # token0 can't see token1
    out=(F.softmax(sc,-1)@vv.float()).transpose(0,1).reshape(2,-1).half()*torch.sigmoid(gate)
    h2=x2+s.op(out)
    h2=h2+s.dw(F.silu(s.gw(rms(h2,s.pln)))*s.uw(rms(h2,s.pln)))
    return h2

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
    toks=list(np.load("/tmp/gdn_coreai/mlx_toks32.npy"))
    def fresh():
        return (dict((i,torch.zeros(GV,GHD,GHD,dtype=torch.float16)) for i in range(32) if is_lin(i)),
                dict((i,torch.zeros(3,8192,dtype=torch.float16)) for i in range(32) if is_lin(i)),
                dict((i,torch.zeros(MAX,AKV,AHD,dtype=torch.float16)) for i in range(32) if not is_lin(i)),
                dict((i,torch.zeros(MAX,AKV,AHD,dtype=torch.float16)) for i in range(32) if not is_lin(i)))
    def step1(tok,pos,gs,gc,kb,vb):
        h=embed[int(tok)]
        for i,l in enumerate(layers):
            if is_lin(i):
                h,s2,c2=l(h,gs[i],gc[i]); gs[i],gc[i]=s2,c2
            else:
                h,k2,v2=l(h,kb[i],vb[i],torch.tensor([float(pos)],dtype=torch.float16)); kb[i],vb[i]=k2,v2
        return h, int((rms(h,fnorm)@embed.t()).float().argmax())
    N=40
    with torch.no_grad():
        # ---- PLAIN ----
        gs,gc,kb,vb=fresh(); pos=0; h=None; nxt=None
        for tok in toks: h,nxt=step1(tok,pos,gs,gc,kb,vb); pos+=1
        t0=time.time(); made=0; cur=nxt
        while made<N:
            h,cur=step1(cur,pos,gs,gc,kb,vb); pos+=1; made+=1
        tplain=time.time()-t0
        print(f">> PLAIN:  {N} tok in {tplain:.1f}s = {N/tplain:.2f} tok/s")
        # ---- SPEC (MTP K=1, 2-tok steps, mid-state adopt on reject) ----
        gs,gc,kb,vb=fresh(); pos=0
        for tok in toks: h,nxt=step1(tok,pos,gs,gc,kb,vb); pos+=1
        d=int((mtp.draft(embed[nxt],h,pos-1).half()@embed.t()).float().argmax())
        t0=time.time(); made=0; acc=0; iters=0
        while made<N:
            x2=torch.stack([embed[int(nxt)],embed[int(d)]])
            mids={}; ends={}
            hh=x2
            for i,l in enumerate(layers):
                if is_lin(i):
                    hh,mid,end,cwEnd,cwMid=gdn2(l,hh,gs[i],gc[i])
                    mids[i]=(mid,cwMid); ends[i]=(end,cwEnd)
                else:
                    hh=fa2(l,hh,kb[i],vb[i],pos)
            lg=(rms(hh,fnorm)@embed.t()).float()
            true2=int(lg[0].argmax())     # verifies d
            iters+=1
            if true2==int(d):             # ACCEPT: 2 tokens emitted
                for i in ends: gs[i],gc[i]=ends[i]
                made+=2; acc+=1
                emitted_last=int(lg[1].argmax())
                h_last=hh[1]; pos+=2
                nxt=emitted_last
                d=int((mtp.draft(embed[nxt],h_last,pos-1).half()@embed.t()).float().argmax())
            else:                          # REJECT: adopt mid state, emit 1 (nxt), true2 becomes next input
                for i in mids: gs[i],gc[i]=mids[i]
                made+=1; pos+=1            # FA kv wrote pos+1 too but pos pointer rewinds → overwritten next iter
                h_last=hh[0]; nxt=true2
                d=int((mtp.draft(embed[nxt],h_last,pos-1).half()@embed.t()).float().argmax())
        tspec=time.time()-t0
        print(f">> SPEC:   {made} tok in {tspec:.1f}s = {made/tspec:.2f} tok/s  (a={acc}/{iters}={acc/iters:.2f})")
        print(f">> WALL-CLOCK RATIO: {(made/tspec)/(N/tplain):.2f}x  [CPU torch port; MLX-GPU lane = production next]")
if __name__=="__main__": main()
