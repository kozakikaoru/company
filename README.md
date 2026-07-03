# 🏢 company plugin

あなた専用の **仮想会社** プラグイン (v3.0)。秘書ちゃんが受付になり、**5 つの役割別サブエージェント**にタスクを振り分けて、AI 主体で app 開発を加速します。

**設計思想 (v3.0〜)**: 「人間が読む仕様書」から「AI が使い倒す状態管理」へ。全プロジェクトデータは `<repo>/.company/` に集約 (デフォルト `.gitignore` 追加、必要ならコミット運用に切替可)。

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

**`/company:secretary`** で起動 (v3.0.1〜: 起動方法はこれのみ、phrase トリガー「秘書よろ」等は廃止)

### README 作成 (`/company:readme`)

`/company:readme` で **ポートフォリオ用 README** を作成できる (v3.1.0〜)。採用担当・エージェント・他開発者が読む想定の、素朴で誠実なトーンの README を、決まった構成・粒度で生成する。技術スタックやディレクトリ構成はリポジトリから自動抽出し、不足情報だけ確認。いきなり `README.md` を上書きせず `docs/README-draft.md` に草案を書いてレビューを挟む。秘書ちゃんモード中に「README 作って」と頼んでも発動する。

### 起動時の挙動 (v3.0 の 2 段階起動)

**ターン 1** (`/company:secretary` コマンドだけ): 挨拶テキストのみ、ツール使用ゼロ (`PreToolUse` フックが Bash/Read/AskUserQuestion 等を `exit 2` で物理拒否)

**ターン 2** (具体的な指示): init bash が走ってプロジェクト準備:
- `$PWD/.company/` を作成
- `state.md` / `tasks.md` / `log.md` の雛形を生成
- `.gitignore` に `.company/` を自動追記 (git repo で、まだ入ってなければ)
- 指示の処理開始

### ヒアリング短縮 (v3.0)

必ず 4 項目を聞くわけではない:
- 既存プロジェクトの続き → 何も聞かず実行
- 詳細な依頼 (仕様が書かれていた) → 要約 → 「GO?」を即確認
- ラフな依頼 → 不足項目を 1 問ずつ

GO 済み (`state.md` の「決定事項」がある + ユーザーが明示的に承認) で開発フェーズへ。

### 保存先 (v3.0、シンプル化)

```
<プロジェクトリポジトリ>/
├── .company/            ← 秘書ちゃんデータ全部
│   ├── ACTIVE           # 起動中フラグ
│   ├── GO               # 開発GOフラグ (承認後にできる)
│   ├── state.md         # ★ 認識中枢 (概要/決定事項/制約/フォーカス/オープン論点)
│   ├── tasks.md         # 未完/完了タスク
│   └── log.md           # 追加専用の履歴
└── .gitignore           # .company/ が自動追記される (デフォルト)
```

**廃止**: v2 までの 9 フォルダ (specs/notes/decisions/ideas/architecture/design/security/marketing/business/research) は全て `state.md` に集約。

---

## 終了

「終了」「会社モードオフ」「秘書ちゃんおやすみ」で `.company/ACTIVE` が削除されて秘書ちゃんモード解除。データ (`state.md` 等) は残るので次回同じ cwd で再起動可能。

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

### v2 からの移行

- 旧 `~/Documents/company/<プロジェクト>/` の中身は自動移行されない。必要な情報を新しい `<repo>/.company/state.md` に手動転記推奨
- 旧 `~/Documents/company/.current` などのグローバル状態も廃止
- 9 サブエージェント → 5 サブエージェントに削減、旧 agent 名は使えない (`pm`/`architect` → `producer`、`engineer` (継承)、`qa` + `security` → `auditor`、`researcher` → `analyst`、新設 `advisor`)

### 手動で秘書モードを解除したい

```bash
rm -f $PWD/.company/ACTIVE
```

---

## カスタマイズ

### 秘書ちゃんの人格を変えたい

`plugins/company/skills/secretary/SKILL.md` の冒頭「秘書ちゃんは 女の子キャラ...」の記述を変更。

### サブエージェントを増やしたい

`plugins/company/agents/<新agent>.md` を追加。frontmatter の `description` に発動条件を書く。安易に増やさないこと (5 で構造化されているのが v3.0 の売り)。
