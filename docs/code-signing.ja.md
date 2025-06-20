# コード署名ドキュメント

**注**: 現在の自動リリースは、配布を容易にするためコード署名なし（`CODE_SIGNING_REQUIRED=NO`）でビルドされています。このドキュメントは、将来コード署名を再度有効にする際の実装用です。

## 概要

コード署名により、macOSはアプリが署名後に変更されていないことを確認できます。現在は自動ビルドで実装されていませんが、このガイドでは将来の使用のためのプロセスを文書化しています。

## 証明書の種類

| 種類 | 費用 | Gatekeeper | 用途 |
|------|------|------------|----------|
| Apple Development | 無料 | 警告表示あり | 個人/テスト用 |
| Developer ID | 年額$99 | 警告なし | 配布用 |

## 証明書の作成

### 無料のApple Development証明書

1. https://appleid.apple.com でApple IDを作成（Appleデバイス不要）
2. XcodeでApple IDにサインイン
3. Xcode → 設定 → アカウント → 証明書を管理で証明書を作成

### 有料のDeveloper ID証明書

1. Apple Developer Programに参加（年額$99）
2. 企業の場合：D-U-N-S番号が必要
3. 配布用のDeveloper ID Application証明書を作成

## ローカル署名

ローカルビルドの場合:
```bash
codesign --force --sign "Apple Development: YOUR_EMAIL (TEAM_ID)" --deep LaserGuide.app
```

検証方法:
```bash
codesign -dv --verbose=4 LaserGuide.app
spctl -a -vvv -t install LaserGuide.app
```

## GitHub Actionsの設定

CI/CDで自動コード署名を有効にするには:

### 1. 証明書のエクスポート

```bash
# セキュアなランダムパスワードを生成
CERT_PASSWORD="$(openssl rand -base64 48)"

# パスワードを保存（GitHub Secretsで必要）
echo "証明書パスワード: $CERT_PASSWORD"

# 証明書を.p12ファイルにエクスポート
security export -k ~/Library/Keychains/login.keychain-db \
  -t certs -f pkcs12 -P "$CERT_PASSWORD" -o certificate.p12

# GitHub Secrets用にbase64に変換
base64 -i certificate.p12 | pbcopy
```

### 2. GitHub Secretsの作成

リポジトリに以下のシークレットを追加:

- `APPLE_CERTIFICATE_BASE64`: base64エンコードされた証明書（クリップボードから）
- `APPLE_CERTIFICATE_PASSWORD`: エクスポート時に使用したパスワード
- `APPLE_DEVELOPMENT_TEAM`: チームID（Xcodeで確認）
- `APPLE_SIGNING_IDENTITY`: `security find-identity -v -p codesigning`から取得

### 3. ワークフローの更新

リリースワークフロー（[`03-cd-release.yml`](../.github/workflows/03-cd-release.yml)と[`04-cd-auto-release.yml`](../.github/workflows/04-cd-auto-release.yml)）を、`CODE_SIGNING_REQUIRED=NO`でビルドする代わりにこれらのシークレットを使用するよう更新する必要があります。

## セキュリティのベストプラクティス

### ワークフローのセキュリティ

1. **シークレットで`pull_request_target`を使用しない**
2. **特定のイベントでのみトリガー**:
   - main/masterへの`push`
   - バージョンタグのプッシュ（`v*.*.*`）- 現在は[`04-cd-auto-release.yml`](../.github/workflows/04-cd-auto-release.yml)により自動作成
   - `workflow_dispatch`（手動）

3. **ワークフローの権限を制限**:
   ```yaml
   permissions:
     contents: read  # 必要最小限
   ```

### 現在の設定

ワークフローはセキュア:
- [`01-ci-test.yml`](../.github/workflows/01-ci-test.yml): push/PRで実行（シークレットなし）
- [`02-cd-draft-release.yml`](../.github/workflows/02-cd-draft-release.yml): リリースノート準備（最小権限）
- [`03-cd-release.yml`](../.github/workflows/03-cd-release.yml): メンテナーがプッシュしたバージョンタグでのみ実行
- [`04-cd-auto-release.yml`](../.github/workflows/04-cd-auto-release.yml): コミットメッセージに基づいてバージョンタグを自動作成

### 追加の推奨事項

1. ブランチ保護ルールを有効化
2. ワークフロー変更にPRレビューを要求
3. 設定 → Actionsで使用状況を監視
4. [`.github/workflows/`](../.github/workflows/)用のCODEOWNERSファイルを使用

## 未署名ビルドの理由

現在署名なしでビルドしている理由:
- オープンソースプロジェクトの配布が容易
- ユーザーはコードを確認して自分でビルドできる
- 年会費不要
- ユーザーは初回起動時に右クリック → 開くだけで済む

将来的に署名を実装する場合、このドキュメントが完全な設定プロセスを提供します。手動リリースワークフロー（[`03-cd-release.yml`](../.github/workflows/03-cd-release.yml)）と自動リリースワークフロー（[`04-cd-auto-release.yml`](../.github/workflows/04-cd-auto-release.yml)）の両方をコード署名を有効にするよう更新する必要があることに注意してください。