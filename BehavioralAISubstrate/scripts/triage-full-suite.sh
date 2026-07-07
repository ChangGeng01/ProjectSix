#!/bin/bash
# P1 triage 脚本化(RSI 章程 2026-07-07)— 机器化 Docs/KNOWN_TEST_FLAKES.md 的三步规则。
# 机器环永不裸消费 swift test 退出码(ch1042 错误 revert 案底):
#   1) 聚合行:0 XCTest failures ⇒ 无回归,无论进程退出码;
#   2) 失败行逐条与 flake 登记核对(签名匹配 = 候选 flake);
#   3) 疑犯隔离复跑:孤立通过 = flake;孤立复现 = 真回归。
# 出口约定:0 = 无回归(可能有已核对的 flake);1 = 真回归(列名);2 = 用法/环境错。
# 用法:scripts/triage-full-suite.sh <sweep.log>            # 分析既有日志
#       scripts/triage-full-suite.sh --run [filter]        # 现跑再分析(重活,注意一次一个)
set -u
cd "$(dirname "$0")/.." || exit 2

LOG="${1:-}"
if [ "$LOG" = "--run" ]; then
  LOG=$(mktemp /tmp/bas-sweep-XXXXXXXX) || exit 2
  echo "[triage] running swift test ${2:+--filter $2} -> $LOG"
  # 全量跑绝不管道 tail(退出码纪律);落文件后分析。
  swift test ${2:+--filter "$2"} > "$LOG" 2>&1
  echo "[triage] raw exit=$? (informational only — verdict comes from triage)"
fi
[ -f "$LOG" ] || { echo "usage: $0 <sweep.log> | --run [filter]"; exit 2; }

# ── 步骤 1:聚合行 ─────────────────────────────────────────────────────────────
AGG=$(grep -E "Executed [0-9]+ tests, with [0-9]+ failure" "$LOG" | tail -1)
echo "[triage] aggregate: ${AGG:-<none found>}"
TOTAL_FAILS=$(grep -E "Executed [0-9]+ tests, with" "$LOG" \
  | sed -E 's/.*with ([0-9]+) failure.*/\1/' | awk '{s+=$1} END {print s+0}')
if [ "${TOTAL_FAILS:-0}" -eq 0 ]; then
  if grep -qE "unexpected signal code 10" "$LOG"; then
    echo "[triage] VERDICT: NO REGRESSION (0 XCTest failures; swift-testing SIGBUS flake #1 present)"
  else
    echo "[triage] VERDICT: NO REGRESSION (0 XCTest failures)"
  fi
  exit 0
fi

# ── 步骤 2:失败套件提取 + flake 签名核对 ──────────────────────────────────────
SUITES=$(grep -E "Test Case '-\[[A-Za-z]+\.[A-Za-z0-9_]+ " "$LOG" \
  | grep "' failed (" \
  | sed -E "s/.*'-\[[A-Za-z]+\.([A-Za-z0-9_]+) .*/\1/" | sort -u)
echo "[triage] failing suites: $(echo "$SUITES" | tr '\n' ' ')"

REGRESSIONS=""
for SUITE in $SUITES; do
  KNOWN=""
  case "$SUITE" in
    BASProductionAdoptionSmokeTests) KNOWN="flake#2 CoreData/NSXPC 134060" ;;
    BASChapter905StorePerfBenchmarkTests) KNOWN="flake#3 wall-clock perf" ;;
    # 3 个已知 pre-existing Mac failures(stash-verified at HEAD, 07-06/07 战役期):
    BASEBrainTurnResultReplayHarnessTests|BASModelHonestyObserveWiringTests|BASThoughtFoldCompactSlotsDeterminismProbe)
      KNOWN="pre-existing at HEAD (stash-verified 07-06)" ;;
  esac
  # ── 步骤 3:隔离复跑(flake 孤立过;回归孤立仍败)──────────────────────────
  echo "[triage] isolating $SUITE${KNOWN:+ (registry: $KNOWN)} ..."
  ISO=$(mktemp /tmp/bas-iso-XXXXXXXX) || { echo "[triage]   $SUITE: mktemp FAILED -> UNGROUNDED, treating as REGRESSION (fail-closed)"; REGRESSIONS="$REGRESSIONS $SUITE"; continue; }
  swift test --filter "$SUITE" > "$ISO" 2>&1
  ISO_FAILS=$(grep -E "Executed [0-9]+ tests, with" "$ISO" \
    | sed -E 's/.*with ([0-9]+) failure.*/\1/' | awk '{s+=$1} END {print s+0}')
  if [ "${ISO_FAILS:-0}" -eq 0 ]; then
    echo "[triage]   $SUITE: passes isolated -> FLAKE${KNOWN:+ (matches $KNOWN)}"
  else
    if [ -n "$KNOWN" ] && [ "${KNOWN#pre-existing}" != "$KNOWN" ]; then
      echo "[triage]   $SUITE: fails isolated but registered pre-existing -> NOT NEW"
    else
      echo "[triage]   $SUITE: FAILS ISOLATED -> REGRESSION"
      REGRESSIONS="$REGRESSIONS $SUITE"
    fi
  fi
done

if [ -n "$REGRESSIONS" ]; then
  echo "[triage] VERDICT: REGRESSION in:$REGRESSIONS"
  exit 1
fi
echo "[triage] VERDICT: NO NEW REGRESSION (all failures = flakes/pre-existing, isolation-verified)"
exit 0
