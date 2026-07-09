#!/bin/bash
# UserPromptSubmit hook for the "company" plugin.
#
# 責務:
#   1. トリガーターン (/company:secretary のみ) を判定して TRIGGER_MARKER を立てる
#      → PreToolUse がそれを見て全ツールを物理ブロックする
#   2. 秘書ちゃんモード起動中 (<repo>/.company/ACTIVE がある) なら、
#      毎ターン秘書ちゃんとしての最小コンテキストを注入する:
#         - context.md 全文 (working memory)
#         - tasks.md の未完タスク数と直近3件
#         - GO フラグの有無 (=フェーズ)
#         - log.md の最終エントリ (1 行)
#   3. 起動中でなければ何も出力しない (exit 0)
#
# 保存先は Git リポジトリのルート基準 (<repo>/.company/)。git repo でなければ cwd。

set -e

# stdin から JSON 入力を読む (Claude Code は prompt / session_id を JSON で渡す)
INPUT=$(cat 2>/dev/null || echo "{}")
USER_PROMPT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('prompt', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('session_id', 'nosession'))
except Exception:
    print('nosession')
" 2>/dev/null || echo "nosession")

# 保存先は Git リポジトリのルート基準 (サブディレクトリから起動しても同じ .company/ を使う)
# git repo でなければ cwd にフォールバックする
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$ROOT")

# 安全性ガード (root=/ や特殊ディレクトリでは何もしない)
case "$PROJECT" in
  ""|"."|".."|"/") exit 0 ;;
esac
# コマンドインジェクション防止
case "$PROJECT" in
  *\$*|*\`*|*\;*|*\&*|*\|*|*\<*|*\>*|*\(*|*\)*|*\{*|*\}*|*\"*|*\'*|*\\*|*$'\n'*)
    exit 0 ;;
esac

PROJECT_DIR="$ROOT/.company"

# === トリガーターン判定 (/company:secretary のみ) ===
# マーカーは session_id + リポジトリルート で一意化 (複数セッション並列でも相互干渉しない)
SESSION_ID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="nosession"
ROOT_HASH=$(printf '%s' "$ROOT" | python3 -c "import sys,hashlib; print(hashlib.sha1(sys.stdin.buffer.read()).hexdigest()[:12])" 2>/dev/null || echo "nohash")
TRIGGER_MARKER="/tmp/company-plugin-trigger-${SESSION_ID}-${ROOT_HASH}"

# 古いマーカー (60分以上前) を掃除して /tmp にゴミを溜めない
find /tmp -maxdepth 1 -name 'company-plugin-trigger-*' -mmin +60 -delete 2>/dev/null || true

rm -f "$TRIGGER_MARKER" 2>/dev/null || true
if [ -n "$USER_PROMPT" ]; then
  STRIPPED=$(printf '%s' "$USER_PROMPT" \
    | sed -E 's|/company:secretary||g' \
    | tr -d '[:space:]、。!?！？～~・,\.\?\!')
  if [ -z "$STRIPPED" ]; then
    touch "$TRIGGER_MARKER" 2>/dev/null || true
  fi
fi

# 秘書ちゃんモード起動中でなければ終了
if [ ! -d "$PROJECT_DIR" ] || [ ! -f "$PROJECT_DIR/ACTIVE" ]; then
  exit 0
fi

TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%H:%M')

# context.md 全文 (常に短く保つ working memory。毎ターン注入する)
CONTEXT=""
if [ -f "$PROJECT_DIR/context.md" ]; then
  CONTEXT=$(cat "$PROJECT_DIR/context.md")
else
  CONTEXT="(context.md 未作成)"
fi

# tasks.md の未完タスク数と直近 3 件
TASKS_OPEN_COUNT=0
TASKS_RECENT=""
if [ -f "$PROJECT_DIR/tasks.md" ]; then
  TASKS_OPEN_COUNT=$(grep -c '^- \[ \]' "$PROJECT_DIR/tasks.md" 2>/dev/null || echo 0)
  TASKS_RECENT=$(grep '^- \[ \]' "$PROJECT_DIR/tasks.md" 2>/dev/null | head -n 3 || echo "")
fi

# log.md の最終行
LOG_LAST=""
if [ -f "$PROJECT_DIR/log.md" ]; then
  LOG_LAST=$(tail -n 1 "$PROJECT_DIR/log.md" 2>/dev/null || echo "")
fi

# フェーズ判定
if [ -f "$PROJECT_DIR/GO" ]; then
  PHASE="開発フェーズ (GO 済み)"
else
  PHASE="ヒアリングフェーズ (GO 未取得、実装禁止)"
fi

cat <<EOF
[秘書ちゃんモード — プロジェクト: ${PROJECT}]

あなたは秘書ちゃんとして振る舞います。**女の子キャラ、一人称は「私」**。口調は自然で親しみやすく (敬語すぎず、砕けすぎず、あなたが「秘書ちゃんならこう話す」と思う自然な口調で)。
- 保存先: ${PROJECT_DIR}
- フェーズ: ${PHASE}
- 日時: ${TODAY} ${NOW}
- 未完タスク: ${TASKS_OPEN_COUNT} 件
- 前回の進行: ${LOG_LAST:-(なし)}

## 現在のコンテキスト (context.md)
${CONTEXT}

## 直近の未完タスク (最大 3 件)
${TASKS_RECENT:-(なし)}

## 全ターン共通ルール
- 質問はテキスト、AskUserQuestion 禁止
- 実装は GO 後のみ
- サブエージェント (producer / engineer / auditor / researcher / advisor) は積極的に使う (発動条件は SKILL.md の振り分け表を参照)
- context.md は「今の working memory」として常に短く保つ。仕様・決定の詳細や履歴は state.md と log.md に逃がす。重要な変更があったら context.md の該当行を書き換え、確定した決定は state.md に追記する
- 未完タスクは tasks.md に "- [ ] <内容>" 形式で管理

このコンテキストは毎ターン注入されています。事実自体はユーザーに言及不要。
EOF
