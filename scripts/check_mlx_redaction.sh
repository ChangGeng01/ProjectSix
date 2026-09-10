#!/usr/bin/env bash
# M222 — MLX redaction check (護欄 #2 + #3 from the Qinao master plan).
#
# Enforces that MLX / Hugging Face type names never appear in any
# Qinao module other than QinaoMLX. The seam is:
#
#   QinaoMLX  → may import MLXLLM / MLXLMCommon / MLXHuggingFace /
#               HuggingFace / Tokenizers, BASMLXAdapter
#               (this module IS the bridge)
#   Qinao*    → must not name any MLX/HF type or import MLX/HF
#               (substrate types stay invisible to consumers)
#
# Without this check, a careless re-export from QinaoMLX could leak
# `ModelContainer` / `ChatSession` into a Qinao* public signature,
# making downstream hosts couple to MLX internals without realizing it.
#
# The script greps for:
#   1. `import MLXLLM | MLXLMCommon | MLXHuggingFace | HuggingFace | Tokenizers | BASMLXAdapter`
#   2. Type names: `ModelContainer`, `ChatSession`,
#      `ModelConfiguration`, `LanguageModelSession`,
#      `MLXLLMConfiguration`, etc.
#
# Allowed: QinaoMLX (the bridge — it MAY import BASMLXAdapter and name MLX/HF
# types; that is its job) and QinaoSampleHost (executable DEMO exception, rationale
# below at the allowlist). Tested: every other Qinao module under QinaoRuntimeSDK/Sources/.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

QINAO_SOURCES="QinaoRuntimeSDK/Sources"
# Allowlist: QinaoMLX is the library bridge that all other Qinao
# libraries route MLX through. QinaoSampleHost is the executable
# demo target — by design it shows the full SDK + BAS surface for
# end-to-end demonstrations (M233 --lora-train, M234
# --apple-fm-curriculum) and is not part of the Qinao public
# library API. Adding QinaoSampleHost to the allowlist preserves
# the redaction guarantee for libraries consumers actually link
# against.
ALLOWED_MODULES_REGEX="(QinaoMLX|QinaoSampleHost)"

# Tokens that must not appear outside QinaoMLX.
IMPORT_REGEX='^[[:space:]]*import[[:space:]]+(MLXLLM|MLXLMCommon|MLXHuggingFace|HuggingFace|Tokenizers|BASMLXAdapter)\b'
# LanguageModelSession is FoundationModels (Apple Intelligence),
# NOT MLX — comments referencing it in QinaoAppleFoundation /
# QinaoStreamingOrganEndpoint are legitimate. The MLX-specific
# types we ban are only the ones that come from mlx-swift-lm /
# swift-transformers / swift-huggingface.
TYPE_REGEX='\b(MLXOrganAdapter|MLXModelCatalog|MLXLLMConfiguration|ChatSession|ModelContainer|huggingFaceLoadModelContainer|hubDownloader|huggingFaceTokenizerLoader)\b'

# Pick a portable searcher (rg if installed, else grep).
search() {
    local regex="$1"
    local target_dir="$2"
    if command -v rg >/dev/null 2>&1; then
        rg --line-number --no-heading \
            --type swift \
            --glob "!{QinaoMLX,QinaoSampleHost}/**" \
            "$regex" "$target_dir" 2>/dev/null || true
    else
        # POSIX grep fallback. Walk files explicitly so we can
        # filter the QinaoMLX directory out before scanning.
        find "$target_dir" -type f -name '*.swift' \
            -not -path "*/QinaoMLX/*" \
            -not -path "*/QinaoSampleHost/*" \
            -print0 2>/dev/null \
            | xargs -0 grep -nE "$regex" 2>/dev/null || true
    fi
}

violations_import=$(search "$IMPORT_REGEX" "$QINAO_SOURCES")
violations_type=$(search "$TYPE_REGEX" "$QINAO_SOURCES")

count=0
if [ -n "$violations_import" ]; then
    echo "MLX redaction: forbidden import in non-QinaoMLX module:"
    echo "$violations_import"
    count=$((count + 1))
fi
if [ -n "$violations_type" ]; then
    echo "MLX redaction: forbidden type name in non-QinaoMLX module:"
    echo "$violations_type"
    count=$((count + 1))
fi

if [ $count -gt 0 ]; then
    echo ""
    echo "MLX redaction check FAILED ($count category violation(s))."
    echo "Only QinaoMLX may carry MLX / HuggingFace types. Move the"
    echo "leaking code into QinaoMLX or wrap it behind a Qinao-owned"
    echo "type."
    exit 1
fi

# Clean message deliberately names NO modules: naming the exempted bridge modules here
# made output-greppers misread the innocence statement as a violation list (2026-07-12
# operator report). The allowlist + rationale live at ALLOWED_MODULES_REGEX above.
echo "check_mlx_redaction: clean — no MLX/HF type names outside the allowlisted" \
    "bridge modules (see ALLOWED_MODULES_REGEX in this script for the exemptions)."
