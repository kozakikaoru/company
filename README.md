# 🏢 company plugin

あなた専用の **仮想会社** プラグイン。秘書ちゃんが受付になり、**5 つの役割別サブエージェント**にタスクを振り分けて、AI 主体で app 開発を加速します。

**設計思想**: 「人間が読む仕様書」から「AI が使い倒す状態管理」へ。全プロジェクトデータは `<repo>/.company/` に集約 (デフォルト `.gitignore` 追加、必要ならコミット運用に切替可)。

---

## 5 つのサブエージェント

秘書ちゃんが状況に応じて自動振り分けします:

| Subagent | 責務 | 発動タイミング |
|---|---|---|
| `producer` (プロデューサー) | 仕様検討 / 設計 / 技術選定 / UX 判断 / 収益モデル | 「どう設計?」「技術は?」「これでいい?」 |
| `engineer` (エンジニア) | コード実装・修正・リファクタ (GO 後のみ) | 「作って」「直して」「動くようにして」 |
| `auditor` (監査役) | テスト実行/作成、レビュー、型/lint、セキュリティ、a11y | `engineer` の直後に自動呼び出し + 「レビューして」 |
| `analyst` (アナリスト) | Web 検索、競合/市場、ライブラリ、エラー原因、コードベース探索 | 「調べて」「〇〇どこにある?」「このエラーは?」 |
| `advisor` (アドバイザー) | 既存コード/仕様/概念の解説、比較、判断理由の再構築 | 「これって何?」「なぜこう?」「教えて」 |

**構成**:
```
あなた
  ↓
🎀 秘書ちゃん (女の子キャラ、一人称「私」、ずっと常駐)
  ↓ Agent ツールで振り分け (自動)
  ├─ 🎯 producer  (プロデューサー)
  ├─ ⚙️ engineer  (エンジニア)
  ├─ 🔍 auditor   (監査役)
  ├─ 📚 analyst   (アナリスト)
  └─ 💡 advisor   (アドバイザー)
```

---

## インストール

### 1. ローカルテスト

```bash
claude --plugin-dir /path/to/company-plugin
```

### 2. マーケットプレイスから

Claude Code のプラグインマーケットプレイスに追加、または `~/.claude/plugins/` 配下に配置。

```
/plugin list
```
で `company` が表示されればOK。

---

## 使い方

### 起動

**`/company:secretary`** で起動 (起動方法はこれのみ)

### README 作成 (`/company:readme`)

`/company:readme` で README を作成できる。エンドユーザー向けの宣伝文ではなく、開発者が読む README を決まった構成・粒度で生成する。技術スタックやディレクトリ構成はリポジトリから自動抽出し、不足情報だけ確認する。全文を提示してレビューを挟み、承認されたら `README.md` に反映する。秘書ちゃんモード中に「README 作って」と頼んでも発動する。

### 起動時の挙動 (2 段階起動)

**ターン 1** (`/company:secretary` コマンドだけ): 挨拶テキストのみ、ツール使用ゼロ (`PreToolUse` フックが Bash/Read/AskUserQuestion 等を `exit 2` で物理拒否)

**ターン 2** (具体的な指示): init bash が走ってプロジェクト準備:
- `$PWD/.company/` を作成
- `context.md` / `state.md` / `tasks.md` / `log.md` の雛形を生成
- `.gitignore` に `.company/` を自動追記 (git repo で、まだ入ってなければ)
- 指示の処理開始

### ヒアリング短縮

必ず 4 項目を聞くわけではない:
- 既存プロジェクトの続き → 何も聞かず実行
- 詳細な依頼 (仕様が書かれていた) → 要約 → 「GO?」を即確認
- ラフな依頼 → 不足項目を 1 問ずつ

ユーザーが明示的に承認したら開発フェーズへ。

### 保存先

```
<プロジェクトリポジトリ>/
├── .company/            ← 秘書ちゃんデータ全部
│   ├── ACTIVE           # 起動中フラグ
│   ├── GO               # 開発GOフラグ (承認後にできる)
│   ├── context.md       # ★ working memory (毎ターン注入・常に短い): 現在フォーカス/スコープ/制約/技術構成/未解決事項
│   ├── state.md         # 詳細記録 (オンデマンド): 概要/決定事項(日付付きで成長)/仕様詳細
│   ├── tasks.md         # 未完/完了タスク
│   └── log.md           # 追加専用の履歴
└── .gitignore           # .company/ が自動追記される (デフォルト)
```

**context.md と state.md の使い分け**: 毎ターン注入されるのは短い `context.md` のみ。決定事項が積み上がっても注入が肥大化しないよう、詳細は `state.md` に逃がして `context.md` は要点だけ保つ。

---

## トラブルシューティング

### 秘書ちゃんモードが動いてない気がする

```bash
ls $PWD/.company/ACTIVE
```
無ければ未起動 → `/company:secretary` で起動。

### hook がエラーで動かない

```bash
/path/to/company-plugin/plugins/company/scripts/inject-secretary-context.sh
```
を直接実行。秘書モード起動中なら注入コンテキストが出る。

### 手動で秘書モードを解除したい

```bash
rm -f $PWD/.company/ACTIVE
```

---

## カスタマイズ

### 秘書ちゃんの人格を変えたい

`plugins/company/skills/secretary/SKILL.md` の冒頭「秘書ちゃんは 女の子キャラ...」の記述を変更。

### サブエージェントを増やしたい

`plugins/company/agents/<新agent>.md` を追加。frontmatter の `description` に発動条件を書く。安易に増やさないこと (5 役割で構造化されているのが売り)。
