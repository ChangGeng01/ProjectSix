#!/usr/bin/env python3
"""Convert sentence-transformers/all-MiniLM-L6-v2 to a CoreML .mlpackage with
mean-pooling + L2-normalization baked in, so Swift gets a single 384-dim
normalized sentence embedding from (input_ids, attention_mask). Fixed seq len
128 (Swift pads/truncates to match). Also exports vocab.txt for the Swift
WordPiece tokenizer, and validates numerical parity + real semantics."""
import sys
import numpy as np
import torch
import coremltools as ct
from transformers import AutoModel, AutoTokenizer

MODEL = "sentence-transformers/all-MiniLM-L6-v2"
MAXLEN = 128
OUT_MLPACKAGE = "/tmp/minilm/MiniLM.mlpackage"
OUT_VOCAB = "/tmp/minilm/vocab.txt"

print(">> loading", MODEL)
tok = AutoTokenizer.from_pretrained(MODEL)
# eager attention: SDPA (the transformers-5.x default) emits ops coremltools cannot trace.
try:
    model = AutoModel.from_pretrained(MODEL, attn_implementation="eager").eval()
except Exception as e:
    print(">> eager attn_implementation unsupported, falling back:", e)
    model = AutoModel.from_pretrained(MODEL).eval()


class MeanPoolNorm(torch.nn.Module):
    """Transformer -> masked mean pool -> L2 normalize (the all-MiniLM recipe)."""
    def __init__(self, m, maxlen):
        super().__init__()
        self.m = m
        # Pass position_ids + token_type_ids as CONSTANT buffers so the embeddings
        # layer never computes them from input.size() — that dynamic aten::Int cast
        # is what coremltools cannot convert (fixed seq len = maxlen).
        self.register_buffer("pos_ids", torch.arange(maxlen, dtype=torch.long).unsqueeze(0))
        self.register_buffer("tok_type", torch.zeros(1, maxlen, dtype=torch.long))

    def forward(self, input_ids, attention_mask):
        out = self.m(input_ids=input_ids, attention_mask=attention_mask,
                     token_type_ids=self.tok_type, position_ids=self.pos_ids)
        tok_emb = out.last_hidden_state                       # [B, L, 384]
        mask = attention_mask.unsqueeze(-1).to(tok_emb.dtype)  # [B, L, 1]
        summed = (tok_emb * mask).sum(dim=1)                   # [B, 384]
        counts = mask.sum(dim=1).clamp(min=1e-9)               # [B, 1]
        mean = summed / counts
        return torch.nn.functional.normalize(mean, p=2, dim=1)  # [B, 384]


wrapper = MeanPoolNorm(model, MAXLEN).eval()

enc = tok("hello world", padding="max_length", truncation=True,
          max_length=MAXLEN, return_tensors="pt")
ex_ids = enc["input_ids"].to(torch.int32)
ex_mask = enc["attention_mask"].to(torch.int32)

print(">> tracing")
with torch.no_grad():
    traced = torch.jit.trace(wrapper, (ex_ids, ex_mask))
    traced = torch.jit.freeze(traced.eval())  # constant-fold to resolve aten::Int casts

print(">> converting to CoreML mlprogram")
mlmodel = ct.convert(
    traced,
    inputs=[
        ct.TensorType(name="input_ids", shape=(1, MAXLEN), dtype=np.int32),
        ct.TensorType(name="attention_mask", shape=(1, MAXLEN), dtype=np.int32),
    ],
    outputs=[ct.TensorType(name="embedding", dtype=np.float32)],
    minimum_deployment_target=ct.target.iOS16,
    compute_units=ct.ComputeUnit.CPU_ONLY,
    compute_precision=ct.precision.FLOAT32,  # fp16 attention overflows -> NaN; force fp32
    convert_to="mlprogram",
)
mlmodel.save(OUT_MLPACKAGE)
print(">> saved", OUT_MLPACKAGE)

# vocab.txt: line i = token with id i (the Swift tokenizer reads this).
vocab = tok.get_vocab()
ordered = sorted(vocab.items(), key=lambda kv: kv[1])
with open(OUT_VOCAB, "w") as f:
    for token, _ in ordered:
        f.write(token + "\n")
print(">> saved", OUT_VOCAB, "(", len(ordered), "tokens )")
print(">> special ids: CLS", tok.cls_token_id, "SEP", tok.sep_token_id,
      "PAD", tok.pad_token_id, "UNK", tok.unk_token_id)


def embed_ct(text):
    e = tok(text, padding="max_length", truncation=True,
            max_length=MAXLEN, return_tensors="np")
    out = mlmodel.predict({
        "input_ids": e["input_ids"].astype(np.int32),
        "attention_mask": e["attention_mask"].astype(np.int32),
    })
    return out["embedding"][0]


def cos(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


# 1) numerical parity: CoreML vs PyTorch on the same input
with torch.no_grad():
    pt = wrapper(ex_ids, ex_mask).numpy()[0]
cm = embed_ct("hello world")
print("VALIDATION parity cosine(pt, coreml) =", round(cos(pt, cm), 5), "| dim", len(cm))

# 2) real semantics: synonyms closer than unrelated
car, auto, banana = embed_ct("car"), embed_ct("automobile"), embed_ct("banana")
print("SEMANTICS cos(car, automobile) =", round(cos(car, auto), 4),
      "| cos(car, banana) =", round(cos(car, banana), 4))
ok = cos(pt, cm) > 0.99 and cos(car, auto) > cos(car, banana)
print("RESULT:", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
