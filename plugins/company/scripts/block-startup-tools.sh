#!/bin/bash
# PreToolUse hook for the "company" plugin (v3.1).
# トリガーターン (=/company:secretary の起動直後ターン) は対象ツールを物理ブロックする。
# トリガーターン判定は UserPromptSubmit (inject-secretary-context.sh) が
# session_id + cwd で一意化したマーカーを作るかどうかで行う。

set -e

INPUT=$(cat 2>/dev/null || echo "{}")

TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

case "$TOOL_NAME" in
  Bash|Read|Grep|Glob|AskUserQuestion) ;;
  *) exit 0 ;;
esac

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('session_id', 'nosession'))
except Exception:
    print('nosession')
" 2>/dev/null || echo "nosession")

# inject-secretary-context.sh と同じ規則でマーカーパスを再構成する
SESSION_ID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="nosession"
CWD_HASH=$(pwd | python3 -c "import sys,hashlib; print(hashlib.sha1(sys.stdin.buffer.read().rstrip(b'\n')).hexdigest()[:12])" 2>/dev/null || echo "nohash")
TRIGGER_MARKER="/tmp/company-plugin-trigger-${SESSION_ID}-${CWD_HASH}"

if [ ! -f "$TRIGGER_MARKER" ]; then
  exit 0
fi

cat >&2 <<EOF
🚨 [company plugin] 秘書ちゃん起動直後のターンは '${TOOL_NAME}' ツールは使えません。

このターンは挨拶テキストだけを返してください。次の作業はすべて禁止:
  ❌ Bash 実行 (フォルダ作成・初期化も含む)
  ❌ Read で state.md や README を読む
  ❌ Grep / Glob でファイル探索
  ❌ AskUserQuestion (クリック式選択肢UI)
  ❌ Agent ツールでサブエージェント呼び出し
  ❌ 「現状報告」「方向性確認」「最初の一手」などの先回り提案

ユーザーが次のメッセージで具体的な指示を出してから、通常通り使えるようになります。
EOF
exit 2
