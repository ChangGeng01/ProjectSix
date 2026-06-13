#!/usr/bin/env python3
"""EAGLE — train a tiny feature-level draft head on the target's OWN greedy outputs (self-distillation), and
measure the OFFLINE next-token acceptance (the decisive gate before any Core ML / Swift / device work).

EAGLE drafts at the FEATURE level: a small residual head predicts the next penultimate feature f_{t+1} from
(f_t, e_{t+1}) — the current feature + the embedding of the token just produced — and the target's own lm-head
maps f_hat to a token. Trained on the target's greedy self-generations → high agreement, no separate-model
prefill. Byte-identity at decode is guaranteed by the target verify regardless of head quality; head quality only
sets the ACCEPTANCE (speedup). This script reports that acceptance so we know if the head is worth shipping.

HONEST scope: head quality is DATA-BOUND. EAGLE papers train on ~68K samples; what we can self-generate on a Mac
in minutes is far less, so expect modest acceptance — the point is a real number + a working pipeline, scalable
with more data/epochs. Run: /tmp/cml312/bin/python3 Tools/eagle_train_head.py [n_prompts] [gen_len] [epochs]
"""
import sys
import time

import mlx.core as mx
import mlx.nn as nn
import mlx.optimizers as optim
from mlx_lm import load
from mlx_lm.models.cache import make_prompt_cache

MODEL = "mlx-community/Llama-3.2-3B-Instruct-4bit"
N_PROMPTS = int(sys.argv[1]) if len(sys.argv) > 1 else 64
GEN_LEN = int(sys.argv[2]) if len(sys.argv) > 2 else 160
EPOCHS = int(sys.argv[3]) if len(sys.argv) > 3 else 6
OUT = "/tmp/draft/eagle_head.safetensors"

PROMPTS = [
    "Explain how photosynthesis works.", "Write a short story about a robot.",
    "What are the causes of World War I?", "Describe the water cycle.",
    "Give me a recipe for chocolate chip cookies.", "How does a computer's CPU work?",
    "Summarize the plot of Romeo and Juliet.", "What is machine learning?",
    "Describe the solar system.", "How do vaccines work?",
    "Write a poem about the ocean.", "Explain the theory of relativity simply.",
    "What is the difference between weather and climate?", "How does the stock market work?",
    "Describe the human digestive system.", "What caused the fall of the Roman Empire?",
]


def feats(model, ids):
    """Penultimate features [1, L, H] for token ids [1, L] (the lm-head input)."""
    return model.model(ids)


def lm_logits(model, f):
    if getattr(model, "lm_head", None) is not None:
        return model.lm_head(f)
    return model.model.embed_tokens.as_linear(f)


class EagleHead(nn.Module):
    """Residual fuse head: f_{t+1} ≈ f_t + MLP(concat(f_t, e_{t+1}))."""
    def __init__(self, h, mid=2048):
        super().__init__()
        self.fc1 = nn.Linear(2 * h, mid, bias=False)
        self.fc2 = nn.Linear(mid, h, bias=False)

    def __call__(self, f, e):
        x = mx.concatenate([f, e], axis=-1)
        return f + self.fc2(nn.silu(self.fc1(x)))


def main():
    import os
    os.makedirs("/tmp/draft", exist_ok=True)
    print(f">> loading {MODEL}")
    model, tok = load(MODEL)
    embed = model.model.embed_tokens
    H = model.args.hidden_size

    # ---- Self-distillation data: run the 3B greedy, capture (f_t, token_{t+1}) sequences. ----
    print(f">> generating self-distill data ({N_PROMPTS} prompts × {GEN_LEN} tokens)…")
    seqs_f, seqs_tok = [], []
    t0 = time.time()
    for i in range(min(N_PROMPTS, len(PROMPTS) * 8)):
        prompt = PROMPTS[i % len(PROMPTS)]
        msg = tok.apply_chat_template([{"role": "user", "content": prompt}], add_generation_prompt=True)
        ids = mx.array(msg)[None]
        cache = make_prompt_cache(model)
        f_list, tok_list = [], []
        last = model.model(ids, cache=cache)[:, -1, :]   # [1, H] — prefill, feature of the last prompt token
        for _ in range(GEN_LEN):
            nxt = int(mx.argmax(lm_logits(model, last), axis=-1).item())
            f_list.append(last)
            tok_list.append(nxt)
            if nxt == tok.eos_token_id:
                break
            last = model.model(mx.array([[nxt]]), cache=cache)[:, 0, :]   # [1, H] — one cached step
            mx.eval(last)
        if len(tok_list) >= 3:
            seqs_f.append(mx.concatenate(f_list, axis=0))   # [T, H]
            seqs_tok.append(tok_list)
    n_pairs = sum(len(s) - 1 for s in seqs_tok)
    print(f">> data: {len(seqs_tok)} sequences, {n_pairs} (f_t, token) pairs, {time.time()-t0:.0f}s")

    # HELD-OUT split (no train-on-test): last 12 sequences are eval-only.
    n_eval = min(12, len(seqs_tok) // 4)
    train_f, train_t = seqs_f[:-n_eval], seqs_tok[:-n_eval]
    eval_f, eval_t = seqs_f[-n_eval:], seqs_tok[-n_eval:]
    print(f">> split: {len(train_t)} train / {len(eval_t)} held-out sequences")

    # Build training tensors: input f_t, e_{t+1}; target f_{t+1}, token_{t+2}.
    F_in, E_in, F_tgt, T_tgt = [], [], [], []
    for f_seq, t_seq in zip(train_f, train_t):
        T = len(t_seq)
        for t in range(T - 2):
            F_in.append(f_seq[t]); E_in.append(embed(mx.array([t_seq[t + 1]]))[0])
            F_tgt.append(f_seq[t + 1]); T_tgt.append(t_seq[t + 2])
    F_in = mx.stack(F_in); E_in = mx.stack(E_in); F_tgt = mx.stack(F_tgt); T_tgt = mx.array(T_tgt)
    print(f">> training set: {F_in.shape[0]} pairs")

    head = EagleHead(H)
    opt = optim.AdamW(learning_rate=1e-4)

    def loss_fn(head, f, e, ft, tt):
        fh = head(f, e)
        feat_loss = mx.mean(mx.abs(fh - ft))                 # smooth-ish L1 on features
        logits = lm_logits(model, fh)
        ce = mx.mean(nn.losses.cross_entropy(logits, tt))
        return feat_loss + 0.1 * ce

    lvg = nn.value_and_grad(head, loss_fn)
    bs = 256
    N = F_in.shape[0]
    for ep in range(EPOCHS):
        perm = mx.array(list(range(N)))
        # simple shuffle via argsort of random keys
        keys = mx.random.uniform(shape=(N,))
        perm = mx.argsort(keys)
        tot = 0.0; nb = 0
        for b in range(0, N, bs):
            idx = perm[b:b + bs]
            l, g = lvg(head, F_in[idx], E_in[idx], F_tgt[idx], T_tgt[idx])
            opt.update(head, g); mx.eval(head.parameters(), opt.state)
            tot += float(l.item()); nb += 1
        print(f">> epoch {ep+1}/{EPOCHS} loss={tot/max(1,nb):.4f}")

    # ---- HONEST acceptance on HELD-OUT data, two ways. ----
    # (1) Teacher-forced 1-step (upper bound): head sees the target's TRUE feature f_t, predict token_{t+2}.
    tf_correct = tf_total = 0
    for f_seq, t_seq in zip(eval_f, eval_t):
        for t in range(len(t_seq) - 2):
            fh = head(f_seq[t][None], embed(mx.array([t_seq[t + 1]])))
            pred = int(mx.argmax(lm_logits(model, fh), axis=-1).item())
            tf_correct += int(pred == t_seq[t + 2]); tf_total += 1
    tf_acc = tf_correct / max(1, tf_total)

    # (2) AUTOREGRESSIVE draft (what decode actually does): from the target's true f_t, draft K tokens feeding the
    # head's OWN predicted features back. Accept = consecutive matches with the target continuation (errors compound).
    K = 4
    drafted = matched = starts = 0
    accept_lens = []
    for f_seq, t_seq in zip(eval_f, eval_t):
        for t in range(len(t_seq) - K - 2):
            f_cur = f_seq[t][None]
            tok_prev = t_seq[t + 1]          # the token f_t produced (known at decode)
            acc_len = 0
            for k in range(K):
                fh = head(f_cur, embed(mx.array([tok_prev])))
                pred = int(mx.argmax(lm_logits(model, fh), axis=-1).item())
                drafted += 1
                if pred == t_seq[t + 2 + k]:
                    matched += 1; acc_len += 1
                    f_cur = fh; tok_prev = pred   # autoregress on the predicted feature
                else:
                    break
            accept_lens.append(acc_len); starts += 1
    ar_acc = matched / max(1, drafted)
    mean_len = sum(accept_lens) / max(1, len(accept_lens))
    print(f">> HELD-OUT teacher-forced 1-step accept = {tf_acc:.3f}  ({tf_correct}/{tf_total})")
    print(f">> HELD-OUT AUTOREGRESSIVE accept = {ar_acc:.3f}, mean accepted draft length = {mean_len:.2f}/{K} "
          f"(this is the real spec-decode signal)")

    from mlx.utils import tree_flatten
    mx.save_safetensors(OUT, dict(tree_flatten(head.parameters())))
    print(f">> SAVED head → {OUT}")
    print(">> GATE: offline accept >~0.6 → worth the Core ML+Swift+device build; lower → more data/epochs needed.")


if __name__ == "__main__":
    main()
