# GitHub Secrets Setup Guide

**Note**: These secrets are not currently used as automated builds are configured without code signing. This documentation is for future implementation when code signing is re-enabled.

## 1. 証明書のエクスポート

ターミナルで以下を実行：

```bash
# パスワードを設定（GitHub Secretsで使用）
CERT_PASSWORD="your-secure-password-here"

# 証明書をエクスポート
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "$CERT_PASSWORD" \
  -o ~/Desktop/zunsystem-cert.p12 \
  "Apple Development: developer@zunsystem.co.jp (73BDJ3PX3V)"

# Base64エンコード（クリップボードにコピー）
base64 -i ~/Desktop/zunsystem-cert.p12 | pbcopy

# 証明書ファイルを削除（安全のため）
rm ~/Desktop/zunsystem-cert.p12
```

## 2. GitHubリポジトリでSecretsを設定

1. https://github.com/kawaz/CursorFinder/settings/secrets/actions にアクセス
2. 「New repository secret」をクリック
3. 以下のSecretsを追加：

### APPLE_CERTIFICATE_BASE64
- Name: `APPLE_CERTIFICATE_BASE64`
- Value: 上記でコピーしたBase64文字列

### APPLE_CERTIFICATE_PASSWORD
- Name: `APPLE_CERTIFICATE_PASSWORD`
- Value: エクスポート時に設定したパスワード

### APPLE_DEVELOPMENT_TEAM
- Name: `APPLE_DEVELOPMENT_TEAM`
- Value: `UPR984SGG4`

### APPLE_SIGNING_IDENTITY
- Name: `APPLE_SIGNING_IDENTITY`
- Value: `Apple Development: developer@zunsystem.co.jp (73BDJ3PX3V)`

## 3. 設定の確認

すべてのSecretsが設定されたら、次回のリリースから自動的に署名付きビルドが作成されます。

## セキュリティ注意事項

- 証明書ファイル（.p12）は機密情報です
- エクスポート後は必ず削除してください
- パスワードは強固なものを使用してください
- GitHub Secretsは暗号化されて保存されます