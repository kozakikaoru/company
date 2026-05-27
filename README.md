# 🏢 company plugin

あなた専用の **仮想会社** プラグイン。秘書ちゃんが受付になり、PM・エンジニア・デザイナーなど 9 名の専門家に作業を振り分けてくれます。会話内容は `~/Documents/company/<プロジェクト名>/` に仕様書・議事録・タスクとして自動で整理されます。

---

## 構成

```
あなた
  ↓
🎀 秘書ちゃん  ← skill + UserPromptSubmit hook で常駐
  ↓ Agent ツールで振り分け
  ├─ 📋 PM(プロダクトマネージャー)
  ├─ 🏛 アーキテクト
  ├─ ⚙️ エンジニア
  ├─ 🎨 デザイナー
  ├─ 🔍 QA
  ├─ 🛡 セキュリティ
  ├─ 📢 マーケティング
  ├─ 💰 ビジネス
  └─ 🔬 リサーチャー
```

すべての記録は `~/Documents/company/<プロジェクト名>/` に保存されます。

---

## インストール

### 1. ローカルテスト(開発中の動作確認)

```bash
claude --plugin-dir /Users/kayu/Projects/skils/company-plugin
```

### 2. 永続的にインストール

Claude Code のプラグインマーケットプレイスに追加するか、`~/.claude/plugins/` 配下に配置します(具体的な手順は Claude Code のバージョンに依存)。

### 3. インストール確認

Claude Code 内で以下を実行:

```
/plugin list
```

`company` が表示されればOK。

---

## 使い方

### 起動

```
/company:hisho
```

または

```
/company:company
```

会話の中で呼ぶこともできます:

```
秘書ちゃんお願い
```

秘書ちゃんが立ち上がって、まず「**どのプロジェクトのお仕事ですか?**」と聞いてきます。プロジェクト名を伝えると `~/Documents/company/<プロジェクト名>/` を初期化します(既存なら開く)。

### 起動後の動作

毎ターン、UserPromptSubmit フックが秘書ちゃんモードのコンテキストを自動注入します。これにより:

- ユーザーの発言は `notes/YYYY-MM-DD.md` に時系列で記録
- 仕様の話は `specs/spec.md` に逐次反映
- タスクは `tasks/tasks.md` に追加
- 決定事項は `decisions/decisions.md` に記録
- 専門領域の作業は対応する subagent に自動で振り分けられる

ユーザーは秘書ちゃんとだけ会話すればOK。

### 終了

```
会社モードオフ
```

または

```
秘書ちゃんおやすみ
```

ACTIVE フラグが削除され、フックの注入が止まります。再度起動すれば続きから再開できます。

---

## フォルダー構造

```
~/Documents/company/
├── .current                    # 現在アクティブなプロジェクト名
└── <プロジェクト名>/
    ├── ACTIVE                  # 起動中フラグ
    ├── README.md               # プロジェクト概要
    ├── specs/                  # PMが管理
    │   └── spec.md
    ├── notes/                  # 秘書が管理
    │   └── YYYY-MM-DD.md
    ├── tasks/                  # 全員で消化
    │   └── tasks.md
    ├── ideas/
    ├── decisions/              # 決定事項(なぜそうしたか)
    ├── architecture/           # アーキテクトが管理
    ├── design/                 # デザイナーが管理
    ├── security/               # セキュリティが管理
    ├── marketing/              # マーケが管理
    ├── business/               # ビジネスが管理
    └── research/               # リサーチャーが管理
```

---

## 役職一覧

| 役職 | 主担当 | 呼び出しキーワード例 |
|---|---|---|
| 🎀 秘書ちゃん | 受付・常駐・議事録・振り分け | (自動) |
| 📋 PM | 仕様整理、優先順位 | 「仕様まとめて」「優先順位は?」 |
| 🏛 アーキテクト | システム設計、技術選定 | 「全体設計考えて」「技術スタックは?」 |
| ⚙️ エンジニア | 実装、バグ修正 | 「実装して」「このバグ直して」 |
| 🎨 デザイナー | UI/UX、画面設計 | 「画面設計して」「UI考えて」 |
| 🔍 QA | テスト、品質チェック | 「テストして」「受け入れ基準は?」 |
| 🛡 セキュリティ | 脆弱性、認証、データ保護 | 「セキュリティ大丈夫?」「認証どうする?」 |
| 📢 マーケティング | コピー、アプリ名 | 「キャッチコピー」「アプリ名考えて」 |
| 💰 ビジネス | マネタイズ、価格 | 「マネタイズは?」「価格設定」 |
| 🔬 リサーチャー | 競合・ユーザー調査 | 「競合調べて」「市場規模は?」 |

---

## カスタマイズ

### 新しい役職を追加したい

`agents/<役職名>.md` を新規作成し、YAML frontmatter の `description` にその役職の責務と呼び出しキーワードを書く。秘書ちゃんは `subagent_type: <役職名>` で呼び出せます。

### 保存先を変更したい

`scripts/inject-secretary-context.sh` と `skills/hisho/SKILL.md` の `~/Documents/company/` 部分を書き換えるだけ。

### 秘書ちゃんの口調を変えたい

`scripts/inject-secretary-context.sh` の注入コンテキスト、または `skills/hisho/SKILL.md` の挨拶テンプレートを修正。

---

## トラブルシューティング

### 秘書ちゃんモードが動いていない気がする

```bash
ls ~/Documents/company/.current
cat ~/Documents/company/.current
```

ファイルが無ければ未起動。あれば中身のプロジェクト名のフォルダーに `ACTIVE` があるか確認:

```bash
ls ~/Documents/company/$(cat ~/Documents/company/.current)/ACTIVE
```

### hook がエラーで動かない

直接スクリプトを実行して動作確認:

```bash
/Users/kayu/Projects/skils/company-plugin/scripts/inject-secretary-context.sh
```

秘書モード起動中なら注入コンテキストが、未起動なら何も出力されないのが正常。

### 手動で秘書モードを解除したい

```bash
rm -f ~/Documents/company/.current
rm -f ~/Documents/company/*/ACTIVE
```
