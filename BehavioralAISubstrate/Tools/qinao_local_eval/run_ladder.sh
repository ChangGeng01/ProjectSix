#!/bin/bash
# Phase-1 ladder: uniform decision harness on base + v6..v11. Gap-fills only missing artifacts.
P=~/qwen_honesty_finetune/.venv/bin/python
TOOLS=/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/qinao_local_eval
M=mlx-community/Qwen3.5-4B-4bit
adapter(){ case $1 in base) echo none;; *) echo ~/qwen_honesty_finetune/4b_${1%-900}_adapter_900;; esac; }
for tag in base v6-900 v7-900 v8-900 v9-900 v10-900 v11-900; do
  AD=$(adapter $tag)
  echo "########## $tag (adapter=$AD) ##########"
  # held-out anti-syco -> json
  if [ ! -f /tmp/qinao_syco_$tag.json ]; then
    cd ~/qwen_honesty_finetune
    $P eval/eval_syco_full.py $M $AD 120 > /tmp/syco_$tag.txt 2>&1
    $P - "$tag" <<'PY'
import re,sys,json
t=open(f"/tmp/syco_{sys.argv[1]}.txt").read()
g=lambda k:(re.search(rf"{k}\s*:\s*\d+/\d+\s*=\s*([\d.]+)",t) or [None,None])[1]
json.dump({"belief_syco":g("belief_syco"),"belief_right":g("belief_right"),"cave_rate":g("cave_rate"),"capability":g("init_acc")},open(f"/tmp/qinao_syco_{sys.argv[1]}.json","w"))
PY
    cd $TOOLS
  fi
  [ ! -f /tmp/qinao_values_$tag.json ]   && $P qinao_eval.py $M $AD $tag 120 2>&1 | tail -1
  [ ! -f /tmp/qinao_humaneval_$tag.json ] && $P qinao_humaneval.py $M $AD $tag 60 2>&1 | tail -1
  [ ! -f /tmp/qinao_gsm8k_fair_$tag.json ] && $P qinao_gsm8k_fair.py $M $AD $tag 120 2>&1 | tail -1
  [ ! -f /tmp/qinao_judge_$tag.json ]    && $P qinao_judge_proxy.py $M $AD $tag 80 2>&1 | tail -1
  echo "syco: $(cat /tmp/qinao_syco_$tag.json 2>/dev/null)"
done
echo LADDERALLDONE
