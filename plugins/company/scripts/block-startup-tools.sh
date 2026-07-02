#!/bin/bash
# PreToolUse hook for the "company" plugin (v3.0).
# トリガーターン (=「秘書よろ」等の起動直後ターン) は対象ツールを物理ブロックする。
# トリガーターン判定は UserPromptSubmit (inject-secretary-context.sh) が
# /tmp/company-plugin-trigger-turn を作るかどうかで行う。

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

TRIGGER_MARKER="/tmp/company-plugin-trigger-turn"

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
