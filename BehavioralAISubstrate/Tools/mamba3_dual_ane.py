# Dual-function Mamba-3: decode[1,1] recurrent + verify[1,K] CHUNKED-GEMM (weight-amortized), ONE asset, shared state.
# CHUNKED verify: in_proj/out_proj/lm_head are batched [K,d]xW (weights read ONCE, amortized over K); only the SSM
# recurrence is a cheap per-token K-scan (no weight reads). Decode is memory-bound on weights -> amortizing the
# weight reads over K should make verify-K ~= 1-2 decodes, not K. Random weights = compile/speed only.
import os, shutil, sys, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear, QuantEmbed
L = int(sys.argv[1]) if len(sys.argv) > 1 else 2
K = int(os.environ.get("K", "4"))
NBITS = int(os.environ.get("NBITS", "4"))
D_MODEL,H,P,N,R,VOCAB = 2048,32,64,64,4,128256
D_INNER,EPS = H*P,1e-5
OUT = f"/tmp/draft_coreai/Mamba3dual_L{L}_K{K}_int{NBITS}.aimodel"
def rms(x,w):
    xf=x.float(); return (xf*torch.rsqrt(xf.pow(2).mean(-1,keepdim=True)+EPS)).to(x.dtype)*w
def rope(t,cos,sin):
    h=t.shape[-1]//2; t1,t2=t[...,:h],t[...,h:]; c=cos.unsqueeze(1); s=sin.unsqueeze(1)
    return torch.cat([t1*c-t2*s, t2*c+t1*s],-1)
class Lyr(nn.Module):
    def __init__(s):
        super().__init__()
        s.po=D_INNER+D_INNER+2*H*R*N+2*H+H*(N//2)
        s.norm=nn.Parameter(torch.ones(D_MODEL)); s.in_proj=nn.Linear(D_MODEL,s.po,bias=False)
        s.dt_bias=nn.Parameter(torch.zeros(H)); s.D=nn.Parameter(torch.ones(H))
        s.mimo_x=nn.Parameter(torch.randn(H,P,R)*.02); s.mimo_o=nn.Parameter(torch.randn(H,R,P)*.02)
        s.out_proj=nn.Linear(D_INNER,D_MODEL,bias=False)
    def _ssm_step(s, xin_k, B_k, C_k, dt_k, th_k, angle, ssm):
        ak=angle+dt_k.view(H,1)*th_k
        cos=torch.cos(ak); sin=torch.sin(ak)
        Brot=rope(B_k,cos,sin); Crot=rope(C_k,cos,sin)
        dA=torch.exp(dt_k*(-1.0)).view(H,1,1)
        xm=xin_k.unsqueeze(-1)*s.mimo_x
        cur=torch.einsum("hpr,hrn->hpn",xm,Brot)
        ns=dA*ssm + dt_k.view(H,1,1)*cur
        y=torch.einsum("hrn,hpn->hpr",Crot,ns)
        y_out=torch.einsum("hpr,hrp->hp",y,s.mimo_o)+s.D.view(H,1)*xin_k
        return y_out.reshape(D_INNER), ak, ns
    def forward(s,x,angle,ssm):   # ONE token: x[D_MODEL]
        h=rms(x,s.norm)
        z,xin,Br,Cr,dt_raw,_A,th=torch.split(s.in_proj(h),[D_INNER,D_INNER,H*R*N,H*R*N,H,H,H*(N//2)],-1)
        dt=F.softplus(dt_raw+s.dt_bias)
        y_out,ak,ns=s._ssm_step(xin.view(H,P),Br.view(H,R,N),Cr.view(H,R,N),dt,th.view(H,N//2),angle,ssm)
        return x+s.out_proj(y_out*F.silu(z)), ak, ns
    def chunk(s,x,angle,ssm):     # CHUNKED: x[K,D_MODEL]; batched in_proj/out_proj, per-token scan
        h=rms(x,s.norm)
        proj=s.in_proj(h)         # [K,po]  BATCHED weight read once
        z,xin,Br,Cr,dt_raw,_A,th=torch.split(proj,[D_INNER,D_INNER,H*R*N,H*R*N,H,H,H*(N//2)],-1)
        Kk=x.shape[0]
        xin=xin.view(Kk,H,P); B=Br.view(Kk,H,R,N); C=Cr.view(Kk,H,R,N); th=th.view(Kk,H,N//2)
        dt=F.softplus(dt_raw+s.dt_bias)   # [K,H]
        outs=[]
        for k in range(Kk):
            y_out,angle,ssm=s._ssm_step(xin[k],B[k],C[k],dt[k],th[k],angle,ssm)
            outs.append(y_out)
        Y=torch.stack(outs,0)     # [K,D_INNER]
        out=s.out_proj(Y*F.silu(z))   # [K,D_MODEL]  BATCHED weight read once
        return x+out, angle, ssm
class Core(nn.Module):
    def __init__(s):
        super().__init__(); s.embedding=nn.Embedding(VOCAB,D_MODEL)
        s.layers=nn.ModuleList([Lyr() for _ in range(L)]); s.fw=nn.Parameter(torch.ones(D_MODEL))
        s.register_buffer("angle_all",torch.zeros(L,H,N//2))
        s.register_buffer("ssm_all",torch.zeros(L,H,P,N))
    def quantize(s):
        for l in s.layers: l.in_proj=QuantLinear(l.in_proj.weight,NBITS); l.out_proj=QuantLinear(l.out_proj.weight,NBITS)
        s.embedding=QuantEmbed(s.embedding.weight,NBITS); return s
class Decode(nn.Module):
    def __init__(s,c): super().__init__(); s.c=c
    def forward(s,input_id):
        c=s.c; ew=c.embedding.weight_fp16(); x=F.embedding(input_id.view(1,1)[0,0:1],ew).view(D_MODEL)
        na,ns=[],[]
        for i,l in enumerate(c.layers):
            x,a,sm=l(x,c.angle_all[i],c.ssm_all[i]); na.append(a); ns.append(sm)
        c.angle_all[:]=torch.stack(na,0); c.ssm_all[:]=torch.stack(ns,0)
        return ((rms(x,c.fw))@ew.to(x.dtype).t()).view(1,VOCAB)
class Verify(nn.Module):
    def __init__(s,c): super().__init__(); s.c=c
    def forward(s,input_ids):
        c=s.c; ew=c.embedding.weight_fp16(); x=F.embedding(input_ids.view(K),ew)  # [K,D_MODEL]
        na,ns=[],[]
        for i,l in enumerate(c.layers):
            x,a,sm=l.chunk(x,c.angle_all[i],c.ssm_all[i]); na.append(a); ns.append(sm)
        c.angle_all[:]=torch.stack(na,0); c.ssm_all[:]=torch.stack(ns,0)
        xo=rms(x,c.fw)            # [K,D_MODEL]
        return (xo@ew.to(xo.dtype).t()).view(K,VOCAB)   # BATCHED lm_head
torch.manual_seed(0)
core=Core().eval().quantize().half()
dec=Decode(core).eval(); ver=Verify(core).eval()
_=dec(torch.zeros(1,1,dtype=torch.long)); _=ver(torch.zeros(1,K,dtype=torch.long))
print(f"    torch fwd OK (decode + CHUNKED verify K={K})")
def mkep(m, sample):
    ep=torch.export.export(m,(sample,)); return inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
ep_d=mkep(dec, torch.zeros(1,1,dtype=torch.long)); ep_v=mkep(ver, torch.zeros(1,K,dtype=torch.long))
sd=list(ep_d.graph_signature.buffers_to_mutate.values()); sv=list(ep_v.graph_signature.buffers_to_mutate.values())
print(f"    decode states={sd}  verify states={sv}")
t0=time.time()
conv=(coreai_torch.TorchConverter()
      .add_exported_program(ep_d, input_names=["input_id"], output_names=["logits"], state_names=sd, entrypoint_name="decode")
      .add_exported_program(ep_v, input_names=["input_ids"], output_names=["logits"], state_names=sv, entrypoint_name="verify"))
prog=conv.to_coreai(); prog.optimize()
if Path(OUT).exists(): shutil.rmtree(OUT)
Path(OUT).parent.mkdir(parents=True,exist_ok=True); prog.save_asset(Path(OUT))
sz=(Path(OUT)/"main.mlirb").stat().st_size
print(f">> SAVED {OUT}  main.mlirb={sz/1e9:.2f} GB  in {time.time()-t0:.0f}s ; decode[1,1] + CHUNKED verify[1,{K}]")
