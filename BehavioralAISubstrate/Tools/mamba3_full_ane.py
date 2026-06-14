# Clean 2-proper-state Mamba-3 (WITH data-dependent RoPE), angle registered FIRST (mirror Llamba conv-first):
# read angle first (rotation), ssm second; write angle first, ssm second. Tests whether matching Llamba's
# first-registered=first-read=first-written order clears the segmenter "order of token outputs" bug.
import shutil, sys, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear, QuantEmbed
L = int(sys.argv[1]) if len(sys.argv) > 1 else 2
D_MODEL,H,P,N,R,VOCAB = 2048,32,64,64,4,128256
D_INNER,EPS = H*P,1e-5
OUT=f"/tmp/draft_coreai/Mamba32s_L{L}_int8.aimodel"
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
    def forward(s,x,angle,ssm):   # angle FIRST
        h=rms(x,s.norm)
        z,xin,Br,Cr,dt_raw,_A,th=torch.split(s.in_proj(h),[D_INNER,D_INNER,H*R*N,H*R*N,H,H,H*(N//2)],-1)
        xin=xin.view(H,P); B=Br.view(H,R,N); C=Cr.view(H,R,N)
        dt=F.softplus(dt_raw+s.dt_bias)
        new_angle=angle+dt.view(H,1)*th.view(H,N//2)      # READ angle FIRST
        cos=torch.cos(new_angle); sin=torch.sin(new_angle)
        Brot=rope(B,cos,sin); Crot=rope(C,cos,sin)
        dA=torch.exp(dt*(-1.0)).view(H,1,1)
        xm=xin.unsqueeze(-1)*s.mimo_x                      # [H,P,R]
        cur=torch.einsum("hpr,hrn->hpn",xm,Brot)
        new_ssm=dA*ssm + dt.view(H,1,1)*cur               # READ ssm SECOND
        y=torch.einsum("hrn,hpn->hpr",Crot,new_ssm)
        y_out=torch.einsum("hpr,hrp->hp",y,s.mimo_o)+s.D.view(H,1)*xin
        out=s.out_proj(y_out.reshape(D_INNER)*F.silu(z))
        return x+out,new_angle,new_ssm                    # angle FIRST
class M(nn.Module):
    def __init__(s):
        super().__init__(); s.embedding=nn.Embedding(VOCAB,D_MODEL)
        s.layers=nn.ModuleList([Lyr() for _ in range(L)]); s.fw=nn.Parameter(torch.ones(D_MODEL))
        s.register_buffer("angle_all",torch.zeros(L,H,N//2))   # state 1 (FIRST)
        s.register_buffer("ssm_all",torch.zeros(L,H,P,N))      # state 2
    def quantize(s):
        for l in s.layers: l.in_proj=QuantLinear(l.in_proj.weight,8); l.out_proj=QuantLinear(l.out_proj.weight,8)
        s.embedding=QuantEmbed(s.embedding.weight,8); return s
    def forward(s,input_id):
        ew=s.embedding.weight_fp16(); x=F.embedding(input_id,ew).view(D_MODEL)
        na,ns=[],[]
        for i,l in enumerate(s.layers):
            x,a,sm=l(x,s.angle_all[i],s.ssm_all[i]); na.append(a); ns.append(sm)
        s.angle_all[:]=torch.stack(na,0); s.ssm_all[:]=torch.stack(ns,0)   # write angle FIRST
        x=rms(x,s.fw); return (x@ew.to(x.dtype).t()).view(1,VOCAB)
torch.manual_seed(0)
m=M().eval().quantize().half(); _=m(torch.zeros(1,1,dtype=torch.long))
ep=torch.export.export(m.eval(),(torch.zeros(1,1,dtype=torch.long),))
ep=inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
st=list(ep.graph_signature.buffers_to_mutate.values()); print("states:",st)
c=coreai_torch.TorchConverter().add_exported_program(ep,input_names=["input_id"],output_names=["logits"],state_names=st,entrypoint_name="main")
p=c.to_coreai(); p.optimize()
if Path(OUT).exists(): shutil.rmtree(OUT)
Path(OUT).parent.mkdir(parents=True,exist_ok=True); p.save_asset(Path(OUT))
print(f">> SAVED {OUT} states={st}  (STATES env: angle then ssm = {L},{H},{N//2};{L},{H},{P},{N})")
