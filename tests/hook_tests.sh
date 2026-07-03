#!/bin/bash
# company plugin のフック動作テスト。
# トリガー判定 / GO 判定 (フェーズ) / context.md 注入 / セッション分離 /
# Git ルート基準 を検証する。CI から `bash tests/hook_tests.sh` で実行される。

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
INJECT="$REPO_ROOT/plugins/company/scripts/inject-secretary-context.sh"
BLOCK="$REPO_ROOT/plugins/company/scripts/block-startup-tools.sh"

PASS=0
FAIL=0

ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

# 条件が真なら pass、偽なら fail
check() {
  if [ "$1" = "true" ]; then ok "$2"; else ng "$2"; fi
}

# BLOCK フックを叩いて exit code を返す
block_rc() {
  local rc=0
  printf '%s' "$1" | bash "$BLOCK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# マーカーが存在するか (true/false)
marker_exists() {
  if ls /tmp/company-plugin-trigger-"$1"-* >/dev/null 2>&1; then echo true; else echo false; fi
}

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK" /tmp/company-plugin-trigger-* 2>/dev/null || true; }
trap cleanup EXIT

cd "$WORK" || exit 1
git init -q
git config user.email test@example.com
git config user.name test
mkdir -p .company src/deep
touch .company/ACTIVE
cat > .company/context.md <<'EOF'
# 現在の前提
- 現在フォーカス: 認証機能の実装
- 技術構成: Next.js + Supabase
EOF
cat > .company/tasks.md <<'EOF'
# タスク
- [ ] ログインAPI
- [x] 初期セットアップ
EOF

echo "== トリガー判定 =="
rm -f /tmp/company-plugin-trigger-* 2>/dev/null
printf '%s' '{"prompt":"/company:secretary","session_id":"t1"}' | bash "$INJECT" >/dev/null 2>&1
check "$(marker_exists t1)" "純粋トリガーでマーカー作成"

printf '%s' '{"prompt":"アプリ作りたい","session_id":"t1"}' | bash "$INJECT" >/dev/null 2>&1
if [ "$(marker_exists t1)" = "false" ]; then ok "通常発言でマーカー削除"; else ng "通常発言でマーカー削除"; fi

echo "== 物理ブロック =="
printf '%s' '{"prompt":"/company:secretary","session_id":"t2"}' | bash "$INJECT" >/dev/null 2>&1
if [ "$(block_rc '{"tool_name":"Bash","session_id":"t2"}')" = "2" ]; then
  ok "トリガー中の Bash は exit 2"
else
  ng "トリガー中の Bash は exit 2"
fi
if [ "$(block_rc '{"tool_name":"Write","session_id":"t2"}')" = "0" ]; then
  ok "ブロック対象外ツール (Write) は通過"
else
  ng "ブロック対象外ツール (Write) は通過"
fi

echo "== セッション分離 =="
printf '%s' '{"prompt":"/company:secretary","session_id":"sa"}' | bash "$INJECT" >/dev/null 2>&1
if [ "$(block_rc '{"tool_name":"Bash","session_id":"sb"}')" = "0" ]; then
  ok "別セッションは干渉しない"
else
  ng "別セッションは干渉しない"
fi

echo "== フェーズ (GO) 判定 =="
out=$(printf '%s' '{"prompt":"進捗","session_id":"p1"}' | bash "$INJECT" 2>/dev/null)
if printf '%s' "$out" | grep -q "ヒアリングフェーズ"; then ok "GO なしはヒアリングフェーズ"; else ng "GO なしはヒアリングフェーズ"; fi
touch .company/GO
out=$(printf '%s' '{"prompt":"進捗","session_id":"p1"}' | bash "$INJECT" 2>/dev/null)
if printf '%s' "$out" | grep -q "開発フェーズ"; then ok "GO ありは開発フェーズ"; else ng "GO ありは開発フェーズ"; fi
rm -f .company/GO

echo "== context.md 注入 =="
out=$(printf '%s' '{"prompt":"進捗","session_id":"c1"}' | bash "$INJECT" 2>/dev/null)
if printf '%s' "$out" | grep -q "現在フォーカス: 認証機能の実装"; then ok "context.md の内容が注入される"; else ng "context.md の内容が注入される"; fi
if printf '%s' "$out" | grep -q "未完タスク: 1 件"; then ok "未完タスク数が正しい"; else ng "未完タスク数が正しい"; fi

echo "== Git ルート基準 =="
out_root=$(cd "$WORK" && printf '%s' '{"prompt":"進捗","session_id":"g1"}' | bash "$INJECT" 2>/dev/null | grep "保存先:")
out_sub=$(cd "$WORK/src/deep" && printf '%s' '{"prompt":"進捗","session_id":"g1"}' | bash "$INJECT" 2>/dev/null | grep "保存先:")
if [ -n "$out_root" ] && [ "$out_root" = "$out_sub" ]; then
  ok "ルートとサブディレクトリで保存先が同じ"
else
  ng "ルートとサブディレクトリで保存先が同じ"
fi

echo "== ACTIVE なしは無出力 =="
rm -f .company/ACTIVE
out=$(printf '%s' '{"prompt":"進捗","session_id":"n1"}' | bash "$INJECT" 2>/dev/null)
if [ -z "$out" ]; then ok "ACTIVE なしはコンテキスト注入しない"; else ng "ACTIVE なしはコンテキスト注入しない"; fi

echo ""
echo "==================="
echo "PASS: $PASS  /  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
