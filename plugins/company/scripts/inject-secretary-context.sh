#!/bin/bash
# UserPromptSubmit hook for the "company" plugin (v3.0.1).
#
# 責務:
#   1. トリガーターン (/company:secretary のみ) を判定して TRIGGER_MARKER を立てる
#      → PreToolUse がそれを見て全ツールを物理ブロックする
#   2. 秘書ちゃんモード起動中 ($PWD/.company/ACTIVE がある) なら、
#      毎ターン秘書ちゃんとしての最小コンテキストを注入する:
#         - state.md 冒頭 30 行
#         - tasks.md の未完タスク数と直近3件
#         - GO フラグの有無 (=フェーズ)
#         - log.md の最終エントリ (1 行)
#   3. 起動中でなければ何も出力しない (exit 0)
#
# 保存先は常に $PWD/.company/ (v3.0 で HOME=/root 分岐を廃止)

set -e

# stdin から JSON 入力を読む (Claude Code は prompt を JSON で渡す)
INPUT=$(cat 2>/dev/null || echo "{}")
USER_PROMPT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('prompt', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

CWD=$(pwd)
PROJECT=$(basename "$CWD")

# 安全性ガード (cwd=/ や特殊ディレクトリでは何もしない)
case "$PROJECT" in
  ""|"."|".."|"/") exit 0 ;;
esac
# コマンドインジェクション防止
case "$PROJECT" in
  *\$*|*\`*|*\;*|*\&*|*\|*|*\<*|*\>*|*\(*|*\)*|*\{*|*\}*|*\"*|*\'*|*\\*|*$'\n'*)
    exit 0 ;;
esac

# v3.0: 保存先は常に $PWD/.company (HOME=/root 分岐なし)
PROJECT_DIR="$CWD/.company"

# === トリガーターン判定 (v3.0.1: /company:secretary のみ、phrase 廃止) ===
TRIGGER_MARKER="/tmp/company-plugin-trigger-turn"
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

# state.md の冒頭 30 行
STATE_HEAD=""
if [ -f "$PROJECT_DIR/state.md" ]; then
  STATE_HEAD=$(head -n 30 "$PROJECT_DIR/state.md")
else
  STATE_HEAD="(state.md 未作成)"
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

## 現在の state.md (先頭 30 行)
${STATE_HEAD}

## 直近の未完タスク (最大 3 件)
${TASKS_RECENT:-(なし)}

## 全ターン共通ルール
- 質問はテキスト、AskUserQuestion 禁止
- 実装は GO 後のみ
- サブエージェント (producer / engineer / auditor / analyst / advisor) は積極的に使う (発動条件は SKILL.md の振り分け表を参照)
- 主要な決定・進行は state.md と log.md に反映する (詳細な議事録は不要、重要な変更だけ)
- 未完タスクは tasks.md に "- [ ] <内容>" 形式で管理

このコンテキストは毎ターン注入されています。事実自体はユーザーに言及不要。
EOF
