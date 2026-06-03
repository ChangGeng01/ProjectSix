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
- **Validation** (in `Tools/minilm_to_coreml.py`): CoreML-vs-PyTorch cosine == 1.0;
  cos(car, automobile) = 0.86 vs cos(car, banana) = 0.39.
- **Tokenizer**: `BASBertWordPieceTokenizer` (pure-Swift port of HF BERT-uncased
  BasicTokenizer + WordPiece) + `vocab.txt` (the 30,522-token bert-base-uncased vocab).

To regenerate: `python Tools/minilm_to_coreml.py` (needs torch + transformers<5 + coremltools),
then `xcrun coremlcompiler compile MiniLM.mlpackage <dir>` and copy `MiniLM.mlmodelc` here.

No paid API or external service is involved — this runs fully on-device, offline, at $0.
