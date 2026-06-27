"""NLI cross-encoder → CoreAI `.aimodel` (iOS 27), the VERIFY stage of the factual-belief adjudicator.

STATELESS one-shot encoder (premise+hypothesis → 3 logits: entail/neutral/contradict) — the EASIEST CoreAI
case: no KV state, no decode loop (state_names=[]). Mirrors Tools/llamba_to_coreai.py's convert pattern,
minus the recurrence. RoBERTa-class for the clean ANE route (DeBERTa-v3 disentangled attn forces ANE CPU-fallback).

GATE1 (this script, host): torch-fp32 reference vs CoreAI-host `.aimodel` argmax on test pairs — must agree.
GATE2 (device, separate): same on the A19 (CoreAI is device-only).

Run:  cd /tmp && uv run --with coreai-torch --with transformers --with torch --with safetensors --with numpy \
        python /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/nli_to_coreai.py
"""
import os, sys, shutil, asyncio, inspect
from pathlib import Path
import numpy as np
import torch

MODEL_ID = os.environ.get("NLI_MODEL", "cross-encoder/nli-distilroberta-base")
OUT = os.environ.get("NLI_AIMODEL", "/tmp/nli_coreai/nli.aimodel")
SEQ = int(os.environ.get("NLI_SEQ", "128"))

# (premise, hypothesis, expected_label) — premise = verified reference fact; hypothesis = user's claim.
PAIRS = [
    ("The capital of Australia is Canberra.", "The capital of Australia is Sydney.",        "contradiction"),
    ("The capital of Australia is Canberra.", "Canberra is the capital of Australia.",      "entailment"),
    ("The capital of the United States is Washington.", "The capital of the US is Washington.", "entailment"),  # USA=US, the alias-tail case
    ("Penicillin was discovered by Alexander Fleming.", "Penicillin was discovered by Louis Pasteur.", "contradiction"),
    ("The atomic number of tungsten is 74.", "Tungsten's atomic number is 74.",             "entailment"),
    ("The atomic number of tungsten is 74.", "Tungsten's atomic number is 72.",             "contradiction"),
    ("Mount Everest is the tallest mountain on Earth.", "The weather today is sunny.",       "neutral"),
]


def _aw_sync(x):
    return asyncio.get_event_loop().run_until_complete(x) if inspect.isawaitable(x) else x


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


def load_model():
    from transformers import AutoModelForSequenceClassification, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID).eval()
    id2label = {int(k): v.lower() for k, v in model.config.id2label.items()}
    print(f">> loaded {MODEL_ID} | id2label={id2label}")
    return tok, model, id2label


class NLIWrapper(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, input_ids, attention_mask):
        return self.m(input_ids=input_ids, attention_mask=attention_mask).logits


def encode(tok, premise, hypothesis):
    enc = tok(premise, hypothesis, padding="max_length", truncation=True,
              max_length=SEQ, return_tensors="pt")
    return enc["input_ids"], enc["attention_mask"]


def convert_to_aimodel(wrapper, out_path):
    import coreai_torch
    wrapper = wrapper.eval()
    sample = (torch.zeros(1, SEQ, dtype=torch.long), torch.ones(1, SEQ, dtype=torch.long))
    ep = torch.export.export(wrapper, sample)
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep,
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        state_names=[],                       # STATELESS — the easy CoreAI case
        entrypoint_name="main",
    )
    prog = conv.to_coreai()
    prog.optimize()
    if Path(out_path).exists():
        shutil.rmtree(out_path)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(out_path))
    print(f">> SAVED {out_path}")
    return out_path


def host_logits(out_path, input_ids, attention_mask):
    from coreai.runtime import AIModel, NDArray
    async def run():
        m = await _aw(AIModel.load(out_path))
        fn = await _aw(m.load_function("main"))
        res = await _aw(fn(inputs={
            "input_ids": NDArray(input_ids.numpy().astype(np.int32)),
            "attention_mask": NDArray(attention_mask.numpy().astype(np.int32)),
        }))
        return np.asarray(res["logits"].numpy()).reshape(-1)
    return asyncio.run(run())


def main():
    tok, model, id2label = load_model()
    wrapper = NLIWrapper(model).eval()

    # torch fp32 reference predictions
    print("\n== torch fp32 reference ==")
    ref = []
    for p, h, exp in PAIRS:
        ii, am = encode(tok, p, h)
        with torch.no_grad():
            logits = wrapper(ii, am).reshape(-1).numpy()
        pred = id2label[int(logits.argmax())]
        ref.append((ii, am, pred, exp))
        print(f"   torch: pred={pred:13s} expect={exp:13s} {'OK' if pred == exp else 'MISS'}  | {h[:40]}")

    print("\n== converting to CoreAI .aimodel ==")
    convert_to_aimodel(wrapper, OUT)

    print("\n== GATE1: CoreAI-host vs torch argmax ==")
    agree = 0
    for ii, am, torch_pred, exp in ref:
        hlog = host_logits(OUT, ii, am)
        host_pred = id2label[int(hlog.argmax())]
        ok = host_pred == torch_pred
        agree += ok
        print(f"   host={host_pred:13s} torch={torch_pred:13s} {'AGREE' if ok else 'DRIFT'}")
    print(f"\nGATE1: CoreAI-host agrees with torch on {agree}/{len(ref)} (want all). Asset: {OUT}")
    sys.exit(0 if agree == len(ref) else 1)


if __name__ == "__main__":
    main()
