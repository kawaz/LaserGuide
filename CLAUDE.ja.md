# CursorFinder AIアシスタントガイドライン

このドキュメントはCursorFinderプロジェクトで作業するAIアシスタント向けのコンテキストとガイドラインを提供します。

## プロジェクト概要

CursorFinderは、大画面や複数ディスプレイでマウスカーソルを見つけやすくするmacOSアプリです。画面の四隅からマウスカーソルに向かってレーザーラインを表示します。

## 開発ワークフロー

### ブランチ管理
- **フィーチャーブランチを使用**: 大きな変更は必ずフィーチャーブランチで作業
- **git worktreeを使用**: メインプロジェクトディレクトリでブランチを切り替えない
  ```bash
  # 機能用の新しいworktreeを作成
  git worktree add .worktrees/feature-name -b feature/feature-name
  
  # worktreeディレクトリで作業
  cd .worktrees/feature-name
  
  # マージ後、クリーンアップ
  git worktree remove .worktrees/feature-name
  git branch -d feature/feature-name
  ```
- **workspaceファイルを更新**: worktree作成時、新しいディレクトリを含むよう[`.code-workspace`](CursorFinder.code-workspace)を更新
- **マージ前に承認を得る**: mainにマージする前に変更を人間に説明し、確認を得る

### コミットの実践
- **適切なコミットを常に作成**: 明確なメッセージで原子的なコミットを作成
- **コンベンショナルコミットを使用**: `feat:`、`fix:`、`docs:`、`chore:`、`refactor:`、`test:`
- **定期的にコミット**: 単一のコミットに多くの変更を蓄積しない

### バージョン管理
- **自動バージョニング**: mainにマージされたPRが自動リリースをトリガー
- **バージョン決定**: 
  - `feat:` → マイナーバージョンアップ
  - その他のコード変更 → パッチバージョンアップ
  - ドキュメントのみの変更 → リリースなし

### 変更のテスト
- **`make dev`を使用**: デバッグ版をビルドして実行し、変更をテスト
- **既存機能を確認**: 変更前に現在の動作を理解

## ドキュメントのメンテナンス

### ドキュメントの同期を保つ
コード変更時、常に確認と更新:
1. `README.md`と`README.ja.md` - ユーザー向け機能とビルド手順
2. `CONTRIBUTING.md`と`CONTRIBUTING.ja.md` - 開発ワークフロー変更
3. `CHANGELOG.md`と`CHANGELOG.ja.md` - 注目すべき変更（リリースワークフローで自動更新）
4. `.github/workflows/README.md`と`README.ja.md` - ワークフロー変更
5. `docs/code-signing.md`と`code-signing.ja.md` - セキュリティや署名関連の変更

### ドキュメントの原則
- **単一の情報源**: ファイル間でコンテンツを重複させない
- **相互参照**: 重複させるのではなくドキュメント間でリンク
- **最新に保つ**: コード変更と同じコミットでドキュメントを更新
- **読者を考慮**: READMEはユーザー向け、CONTRIBUTINGは開発者向け

## コード構成

### プロジェクト構造
```
CursorFinder/
├── CursorFinder/          # Swiftソースコード
│   ├── Views/            # SwiftUIビュー
│   ├── Models/           # ビューモデルとデータモデル
│   ├── Managers/         # ビジネスロジックマネージャー
│   └── Config/           # 設定定数
├── .github/workflows/    # CI/CD自動化
├── Formula/              # Homebrew formula
├── docs/                 # 技術ドキュメント
└── Makefile             # ビルド自動化
```

### 主要ファイル
- [`LaserViewModel.swift`](CursorFinder/Models/LaserViewModel.swift) - コアレーザー表示ロジック
- [`Config.swift`](CursorFinder/Config.swift) - アプリ設定定数
- [`Makefile`](Makefile) - ビルドとリリースコマンド
- [`Formula/cursorfinder.rb`](Formula/cursorfinder.rb) - Homebrew配布

## リリースプロセス

### 自動リリース
1. mainにプッシュされたコード変更が自動的に検出される
2. コミットメッセージによりバージョンが決定される
3. タグが自動的に作成される
4. アプリがビルドされ、バージョン付きzipファイルでリリースされる
5. Homebrew Formulaが自動的に更新される

### 手動制御
- `make version-patch/minor/major` - 手動バージョン制御
- 特定のバージョン要件に便利

## 現在の状態に関する注記

### コード署名
- **現在無効**: ビルドは`CODE_SIGNING_REQUIRED=NO`を使用
- **ドキュメントあり**: 将来の実装については[`docs/code-signing.md`](docs/code-signing.md)参照
- **理由**: オープンソースプロジェクトの配布が容易

### ワークフロー
1. [`01-ci-test.yml`](.github/workflows/01-ci-test.yml) - 毎pushでテスト
2. [`04-cd-auto-release-and-deploy.yml`](.github/workflows/04-cd-auto-release-and-deploy.yml) - mainへのpushで自動バージョニング、ビルド、デプロイ

## 変更のガイドライン

### 変更前
1. 現在の実装を理解
2. 類似機能の存在を確認
3. 既存機能への影響を考慮

### 変更時
1. `make dev`でローカルテスト
2. 関連ドキュメントを更新
3. 明確で原子的なコミットを作成
4. CI/CD互換性を確保

### 変更後
1. ドキュメントが更新されていることを確認
2. ワークフローが引き続き機能することを確認
3. Makefileターゲットが正しく動作することを確認

## 一般的なタスク

### 新機能の追加
1. worktreeでフィーチャーブランチを作成:
   ```bash
   git worktree add .worktrees/feature-name -b feature/feature-name
   cd .worktrees/feature-name
   ```
2. [`.code-workspace`](CursorFinder.code-workspace)を更新して新しいworktreeを含める
3. 適切なマネージャー/ビューで実装
4. 設定を追加する場合は[`Config.swift`](CursorFinder/Config.swift)を更新
5. `make dev`でテスト
6. README.mdの機能セクションを更新（日本語版も）
7. `feat:`プレフィックスでコミット
8. ブランチをプッシュして人間に変更を説明
9. 承認後、mainにマージ
10. worktreeをクリーンアップ:
    ```bash
    cd ../..
    git worktree remove .worktrees/feature-name
    git branch -d feature/feature-name
    ```

### バグ修正
1. 簡単な修正: mainで直接作業
2. 複雑な修正: worktreeでフィーチャーブランチを使用
3. 根本原因を特定
4. 最小限の変更で修正
5. 修正をテスト
6. `fix:`プレフィックスでコミット

### ドキュメントの更新
1. 関連する.mdファイルを変更（英語版と日本語版の両方）
2. ドキュメント間の一貫性を確保
3. `docs:`プレフィックスでコミット（リリースをトリガーしない）

## 重要な注意事項

- **ブランチの規律**: フィーチャーブランチには常にworktreeを使用、mainディレクトリで切り替えない
- **人間の承認**: 大きな変更をmainにマージする前に確認を得る
- **ワークスペースのメンテナンス**: worktree作成/削除時に`.code-workspace`を更新
- **クリーンアップ**: 機能がマージされたらworktreeを削除
- **ドキュメントレビュー**: ドキュメントが実装と一致することを定期的に確認
- **ワークフロー更新**: ワークフロー変更は慎重にテスト
- **破壊的変更**: 現在はマイナーバージョンアップとして扱われる
- **セキュリティ**: シークレットやAPIキーを決してコミットしない
- **コードスタイル**: 既存のSwiftパターンと規約に従う

## 確認すべき質問

新しいセッションを開始する際に考慮すべき質問:
1. 「プロジェクトの現在の状態は？」
2. 「保留中の変更や問題はありますか？」
3. 「リリースプロセスに変更はありましたか？」
4. 「新しい要件や制約はありますか？」

このドキュメントは、プロジェクト構造、ワークフロー、開発プラクティスに大きな変更があった際に更新する必要があります。