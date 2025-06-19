# GitHub Actions Workflows

このプロジェクトでは以下の3つのワークフローが順番に実行されます：

## 1. CI - Test on Push (01-ci-test.yml)
**トリガー**: mainブランチへのpush、またはPull Request
**内容**: 
- コードのビルドとテスト
- Universal Binary（Intel/Apple Silicon両対応）の確認

## 2. CD - Draft Release Notes (02-cd-draft-release.yml)  
**トリガー**: mainブランチへのpush
**内容**:
- 次回リリース用のリリースノート下書きを自動生成
- release-drafter actionを使用

## 3. CD - Release & Deploy (03-cd-release.yml)
**トリガー**: バージョンタグ（v*.*.*）のpush
**内容**:
1. リリースノートの生成
2. アプリのビルド（Universal Binary）
3. zipファイルの作成
4. GitHubリリースの作成とzipアップロード
5. Homebrew Formulaの自動更新

## 4. CD - Auto Release on Merge (04-cd-auto-release.yml)
**トリガー**: mainブランチへのpush（PRマージ時）
**内容**:
1. コード変更の有無をチェック（.swift, .m, .plist等）
2. コード変更がない場合はスキップ
3. コミットメッセージから自動でバージョンを決定:
   - `feat:` または `BREAKING CHANGE` → minor bump
   - その他のコード変更 → patch bump
4. 新しいタグを作成してpush
5. 03-cd-release.ymlが自動的にトリガーされる

## リリースフロー

### 自動リリース（推奨）
PRをmainにマージするだけで全て自動化されます：

1. PRを作成してコードレビュー
2. mainにマージ
3. 自動的に:
   - コード変更を検出
   - バージョンを決定（feat: → minor、その他 → patch）
   - タグを作成
   - リリースをビルド・公開
   - Formulaを更新

### 手動リリース（必要な場合のみ）
```bash
# バージョンタグを作成
make version-patch  # または version-minor/major

# タグをプッシュ
git push origin v0.2.3
```