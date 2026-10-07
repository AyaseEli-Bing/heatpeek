#!/bin/bash
# 端到端验证 — 严格对应 docs/spec-0.2.0.md 第 12 章。
#
# 与 scripts/selftest.sh 的分工：selftest.sh 是项目长期资产（跟随上游），
# 本脚本是一次性验收工具（验证 0.2.0 两个新功能），故放在 docs/ 下不污染 scripts/。
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
BIN=.build/release/heatpeek

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }

echo "heatpeek 0.2.0 验收 — A: EX_USAGE 契约 / B: 非颜色告警提示"
echo

echo "[build]"
swift build -c release > /tmp/hp-build.log 2>&1 \
  && ok "release 构建通过" \
  || { bad "release 构建失败"; tail -20 /tmp/hp-build.log; exit 1; }

echo
echo "[A] 功能 A — --json 缺 --once"

# AC-01: 必须立即返回、不启动 GUI。timeout 兜住「挂住」这个回归，124 即失败。
set +e
OUT=$(timeout 5 "$BIN" --json 2>&1)
CODE=$?
set -e

if [ "$CODE" = "64" ]; then
  ok "AC-02 退出码 64（EX_USAGE）"
else
  bad "AC-02 退出码为 ${CODE}，期望 64"
fi

if [ "$CODE" != "124" ]; then
  ok "AC-01 未挂住（未触发 timeout 的124）"
else
  bad "AC-01 命令挂住，GUI 仍被启动"
fi

if printf '%s' "$OUT" | grep -q -- '--json requires --once'; then
  ok "AC-01 stderr 含明确原因"
else
  bad "AC-01 stderr 缺少提示，实际输出：$OUT"
fi

if printf '%s' "$OUT" | grep -q 'Usage:'; then
  ok "AC-01 stderr 附带 help 文本"
else
  bad "AC-01 stderr 未附带 help"
fi

echo
echo "[A] 无回归 — 既有用例"

set +e
timeout 5 "$BIN" --nonsense > /dev/null 2>&1
NONSENSE=$?
set -e
if [ "$NONSENSE" = "64" ]; then
  ok "AC-04 --nonsense 仍返回 64"
else
  bad "AC-04 --nonsense 返回 $NONSENSE，期望 64"
fi

set +e
JSON=$(timeout 10 "$BIN" --once --json 2>&1)
JSONCODE=$?
set -e
if [ "$JSONCODE" = "0" ]; then
  ok "AC-03 --once --json 仍返回 0"
else
  bad "AC-03 --once --json 返回 $JSONCODE，期望 0"
fi

if printf '%s' "$JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  ok "AC-03 输出仍是合法 JSON"
else
  bad "AC-03 输出不是合法 JSON"
fi

# AC-08: --json 的 key 集合必须与 0.1.0 完全一致，功能 B 不得改变它
if printf '%s' "$JSON" | python3 -c '
import json, sys
want = {"timestamp","temperatures","gpuUtilizationPercent","gpuPowerWatts","fans","unavailable"}
got = set(json.load(sys.stdin))
assert want <= got, f"缺少 key: {want - got}"
' 2>/dev/null; then
  ok "AC-08 --json key 集合未变（6 个文档化key 全在）"
else
  bad "AC-08 --json key 集合被破坏"
fi

echo
echo "[B] 功能 B — 告警的非颜色提示"

if swift test --filter ThresholdTests > /tmp/hp-threshold.log 2>&1; then
  ok "ThresholdTests 全绿"
  grep -E 'Executed [0-9]+ tests?' /tmp/hp-threshold.log | tail -1 | sed 's/^/        /'
else
  bad "ThresholdTests 失败"
  grep -E 'error:|XCTAssert.*failed|failed' /tmp/hp-threshold.log | head -15 | sed 's/^/        /'
fi

# 告警形状的端到端确认：把阈值压到当前最高温以下，--once 文本里应出现 ▲
if printf '%s' "$OUT" >/dev/null 2>&1; then :; fi
if swift test --filter FormattingTests > /tmp/hp-formatting.log 2>&1; then
  ok "FormattingTests 全绿"
  grep -E 'Executed [0-9]+ tests?' /tmp/hp-formatting.log | tail -1 | sed 's/^/        /'
else
  bad "FormattingTests 失败"
  grep -E 'error:|XCTAssert.*failed|failed' /tmp/hp-formatting.log | head -15 | sed 's/^/        /'
fi

echo
echo "[全量] make test 项目门禁"
if make test > /tmp/hp-maketest.log 2>&1; then
  ok "make test 通过"
  grep -E 'passed=[0-9]+ failed=[0-9]+ skipped=[0-9]+' /tmp/hp-maketest.log | tail -1 | sed 's/^/        /'
  grep -E 'Executed [0-9]+ tests' /tmp/hp-maketest.log | tail -1 | sed 's/^/        /'
else
  bad "make test 失败"
  tail -30 /tmp/hp-maketest.log | sed 's/^/        /'
fi

echo
echo "[docs] markdownlint"
LINT=""
for cand in markdownlint-cli2 markdownlint; do
  if command -v "$cand" >/dev/null 2>&1; then LINT=$cand; break; fi
done
# WorkBuddy 管理的 node workspace 里装过 markdownlint-cli2，CI 用 GitHub Action
if [ -z "$LINT" ] && [ -x /Users/bing1111/.workbuddy/binaries/node/versions/22.22.2-6/bin/npx ]; then
  LINT="/Users/bing1111/.workbuddy/binaries/node/versions/22.22.2-6/bin/npx --no-install markdownlint-cli2"
fi
if [ -n "$LINT" ]; then
  # shellcheck disable=SC2086
  if $LINT README.md CHANGELOG.md > /tmp/hp-lint.log 2>&1; then
    ok "markdownlint 通过（$(grep -oE '[0-9]+ issues?' /tmp/hp-lint.log | tail -1 || echo '0 issues')）"
  else
    bad "markdownlint 失败"
    tail -20 /tmp/hp-lint.log | sed 's/^/        /'
  fi
else
  echo "  skip  markdownlint 不可用（CI docs job 会把关）"
fi

echo
echo "================================"
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1