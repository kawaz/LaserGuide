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

## リリースフロー

```bash
# 1. コード変更をコミット
git add . && git commit -m "feat: 新機能"
git push

# 2. バージョンタグを作成
make version-patch  # または version-minor/major

# 3. タグをプッシュ（自動でリリース処理が開始）
git push origin v0.2.3
```

これで自動的に：
- リリースが作成される
- アプリがビルドされる
- Formulaが更新される
- ユーザーは `brew upgrade cursorfinder` でアップデート可能