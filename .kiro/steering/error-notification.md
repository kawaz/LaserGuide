---
inclusion: always
---

# エラー通知とユーザー支援

## 1Passwordエージェントエラー検出
- git操作やSSH操作で1Password関連のエラーを検出した場合、音声で通知する
- エラーパターン：
  - SSH認証失敗
  - 1Password Agentタイムアウト
  - キー取得エラー
  - TouchID承認待ちタイムアウト

## 音声通知の実行
エラー検出時は以下のコマンドで音声通知：
```bash
say "Kiroです。1Passwordエージェントからエラーが返ってきたので確認をお願いします"
```

## 通知が必要なエラーメッセージパターン
- "sign_and_send_pubkey: signing failed"
- "Permission denied (publickey)"
- "Could not read from remote repository"
- "1Password"を含むエラーメッセージ
- "SSH"認証関連のエラー
- TouchID関連のタイムアウト

## 対応手順
1. エラーを検出
2. 音声で通知
3. エラー内容を説明
4. 解決方法を提案
5. 必要に応じて再試行を提案