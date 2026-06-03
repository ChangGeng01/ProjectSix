# MiniLM.mlmodelc — model card & attribution

`MiniLM.mlmodelc` is a CoreML conversion of **sentence-transformers/all-MiniLM-L6-v2**.

- **Source model**: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- **License**: Apache-2.0 (free, permissive — bundling + redistribution permitted with attribution)
- **What it is**: a 6-layer MiniLM sentence encoder, 384-dim output, ~22M params.
- **Conversion**: PyTorch → CoreML `mlprogram` via `Tools/minilm_to_coreml.py` (coremltools),
  with **mean-pooling + L2-normalization baked into the graph**, so the model maps
  `(input_ids[1,128] int32, attention_mask[1,128] int32) → embedding[384] float32` directly.
- **Precision**: fp32, CPU compute (deterministic; the fp16 ANE/GPU path produced NaN at
  conversion, so fp32 is pinned).
- **Validation** (in `Tools/minilm_to_coreml.py`, one local run — NOT in CI): CoreML-vs-PyTorch
  cosine ≈1.0 (>0.99 gate); cos(car, automobile) ≈0.86 vs cos(car, banana) ≈0.39 (observed values).
- **Tokenizer**: `BASBertWordPieceTokenizer` (pure-Swift port of HF BERT-uncased BasicTokenizer +
  `_clean_text` + `_tokenize_chinese_chars` + WordPiece) + `vocab.txt` (the 30,522-token
  bert-base-uncased vocab). EXACT HF parity is locked by `testTokenizerMatchesHuggingFaceReference`
  (ASCII, punctuation, subwords, CJK, control chars).
- **Repo weight**: the fp32 `weights/weight.bin` is ~86 MB committed as a plain git blob (under
  GitHub's 100 MB limit but with little headroom). Consider git-lfs (`*.bin filter=lfs`) before more
  history accretes, or fetch-at-build from a release / HF asset with a checksum.

To regenerate: `python Tools/minilm_to_coreml.py` (needs torch + transformers<5 + coremltools),
then `xcrun coremlcompiler compile MiniLM.mlpackage <dir>` and copy `MiniLM.mlmodelc` here.

No paid API or external service is involved — this runs fully on-device, offline, at $0.
