# GitHub Actions Workflows

このプロジェクトでは以下の2つのワークフローが実行されます：

## 1. CI - Test on Push ([01-ci-test.yml](01-ci-test.yml))
**トリガー**: mainブランチへのpush、またはPull Request
**内容**: 
- コードのビルドとテスト
- Universal Binary（Intel/Apple Silicon両対応）の確認

## 2. CD - Auto Release and Deploy ([04-cd-auto-release-and-deploy.yml](04-cd-auto-release-and-deploy.yml))
**トリガー**: mainブランチへのpush
**内容**:
1. コード変更の有無をチェック（.swift, .m, .plist等）
2. コード変更がない場合はスキップ
3. コミットメッセージから自動でバージョンを決定:
   - `feat:` または `BREAKING CHANGE` → minor bump
   - その他のコード変更 → patch bump
4. 新しいタグを作成
5. アプリをビルド（ユニバーサルバイナリ）
6. zipファイルを作成（バージョン付き名）
7. GitHubリリースを作成してzipをアップロード
8. Homebrew Formulaを自動更新

## リリースフロー

### 自動リリース
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

# タグをプッシュ（注: 手動タグは自動ビルドされません）
git push origin v0.2.3
```

**注意**: 手動でタグをプッシュしても自動ビルドはされません。手動リリースが必要な場合は、GitHub UIから直接リリースを作成してください。