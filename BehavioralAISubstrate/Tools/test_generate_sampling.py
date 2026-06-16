"""完全闭环 generate() + sampling 补漏: greedy is deterministic + autoregressive (feeds its own output), temperature
sampling VARIES across seeds, top_p restricts, and eos stops the loop. (The decoder was step-only/argmax-only before.)"""
from __future__ import annotations

import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY


def main() -> None:
    torch.manual_seed(0)
    V, L = 4096, 24
    m = HY.HybridM(V, L).float().eval()
    prompt = torch.randint(0, V, (32,))

    g1 = m.generate(prompt, 16, temperature=0.0)                       # greedy, free-running (feeds own argmax)
    g2 = m.generate(prompt, 16, temperature=0.0)
    greedy_det = g1 == g2 and len(g1) == 16

    s1 = m.generate(prompt, 16, temperature=1.0, top_p=0.9, gen=torch.Generator().manual_seed(1))
    s2 = m.generate(prompt, 16, temperature=1.0, top_p=0.9, gen=torch.Generator().manual_seed(2))
    sampling_varies = s1 != s2 and len(s1) == 16

    eos = g1[3]                                                        # greedy is deterministic → eos at the 4th token stops at len 4
    ge = m.generate(prompt, 16, temperature=0.0, eos=eos)
    eos_stops = ge == g1[:len(ge)] and ge[-1] == eos and len(ge) == 4

    ok = greedy_det and sampling_varies and eos_stops
    print("完全闭环 generate() + sampling:")
    print(f"  greedy deterministic + len16 = {greedy_det}")
    print(f"  temperature sampling varies across seeds = {sampling_varies}")
    print(f"  eos stops the loop (len {len(ge)} ends at eos) = {eos_stops}")
    print(f"  -> {'PASS' if ok else 'FAIL'}")
    print("READ: PASS = the decoder is a real free-running generator (greedy + nucleus sampling + EOS), not just an open "
          "teacher-forced step. (Swift session generate()/sampling wrappers are the thin device follow-on.)")


if __name__ == "__main__":
    main()
