#!/bin/bash
# PreToolUse hook for the "company" plugin (v2.1.0).
# 秘書ちゃん起動直後 (STARTUP_LOCK が存在する間) は特定ツールを物理的にブロックする。
# SKILL.md の「挨拶以外何もしない」ルールを Claude が読み飛ばしても、
# ハーネス側でツール実行を止めることで起動時の暴走を防ぐ。
#
# STARTUP_LOCK のライフサイクル:
#   - 作成: SKILL の init bash の最後で `touch` される
#   - 削除: 次の UserPromptSubmit (=次のユーザー発言) で削除される
#   - つまり STARTUP_LOCK がある間 = 「起動直後のターンで、まだユーザーから次の指示が来ていない」状態

set -e

# stdin から JSON 入力を読む (Claude Code は tool_name 等を JSON で渡す)
INPUT=$(cat 2>/dev/null || echo "{}")

# tool_name を取り出す (python3 を使うのが確実)
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# ブロック対象ツールでなければスルー
case "$TOOL_NAME" in
  Bash|Read|Grep|Glob|AskUserQuestion) ;;
  *) exit 0 ;;
esac

# プロジェクトの STARTUP_LOCK 確認
CWD=$(pwd)
PROJECT=$(basename "$CWD")

# 特殊ディレクトリ・危険文字を含む basename はスルー (UserPromptSubmit hook と同じガード)
case "$PROJECT" in
  ""|"."|".."|"/") exit 0 ;;
  *\$*|*\`*|*\;*|*\&*|*\|*|*\<*|*\>*|*\(*|*\)*|*\{*|*\}*|*\"*|*\'*|*\\*|*$'\n'*) exit 0 ;;
esac

LOCK="$HOME/Documents/company/$PROJECT/STARTUP_LOCK"

# ロックが存在しない → 通常通り (このターンはツール使用 OK)
if [ ! -f "$LOCK" ]; then
  exit 0
fi

# 起動直後のターン: 対象ツールをブロック
# exit 2 で stderr メッセージが Claude にフィードバックされる (拒否理由として LLM に渡る)
cat >&2 <<EOF
🚨 [company plugin] 秘書ちゃん起動直後は '${TOOL_NAME}' ツールは使えません。

このターンは「挨拶テキスト」だけを返してください。次の作業はすべて禁止です:
  ❌ Bash で git/ls/cat 等の状況把握
  ❌ Read で README や spec.md を読む
  ❌ Grep / Glob でファイル探索
  ❌ AskUserQuestion (クリック式選択肢UI)
  ❌ Agent ツールでサブエージェント呼び出し
  ❌ 「現状報告」「方向性確認」「最初の一手」などの先回り提案

ユーザーが次のメッセージで具体的な指示を出してから、通常通り使えるようになります。
EOF
exit 2
