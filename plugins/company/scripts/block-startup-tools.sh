#!/bin/bash
# PreToolUse hook for the "company" plugin (v2.3.0).
# トリガーターン (=「秘書よろ」等の起動直後ターン) は対象ツールを物理ブロックする。
# トリガーターン判定は UserPromptSubmit (inject-secretary-context.sh) が
# /tmp/company-plugin-trigger-turn を作るかどうかで行う。
#
# 旧 STARTUP_LOCK ベース (v2.1.0/2.2.0) はトリガー検出の方が直接的なので置換。

set -e

# stdin から JSON 入力を読む
INPUT=$(cat 2>/dev/null || echo "{}")

# tool_name を取り出す
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# ブロック対象ツールでなければスルー
case "$TOOL_NAME" in
  Bash|Read|Grep|Glob|AskUserQuestion) ;;
  *) exit 0 ;;
esac

# トリガーマーカー (UserPromptSubmit が現ターンを「純粋トリガー」と判定すると作る)
TRIGGER_MARKER="/tmp/company-plugin-trigger-turn"

if [ ! -f "$TRIGGER_MARKER" ]; then
  exit 0  # 通常ターン → ツール使用 OK
fi

# トリガーターン: 対象ツールを物理拒否
cat >&2 <<EOF
🚨 [company plugin] 秘書ちゃん起動直後のターンは '${TOOL_NAME}' ツールは使えません。

このターンは「挨拶テキスト」だけを返してください。次の作業はすべて禁止です:
  ❌ Bash 実行 (フォルダ作成・初期化・状況把握、すべて含む)
  ❌ Read で README や spec.md を読む
  ❌ Grep / Glob でファイル探索
  ❌ AskUserQuestion (クリック式選択肢UI)
  ❌ Agent ツールでサブエージェント呼び出し
  ❌ 「現状報告」「方向性確認」「最初の一手」などの先回り提案
  ❌ プロジェクトフォルダの作成・初期化 (それも次のターン)

ユーザーが次のメッセージで具体的な指示を出してから、init bash や調査も含めて
通常通り使えるようになります。
EOF
exit 2
