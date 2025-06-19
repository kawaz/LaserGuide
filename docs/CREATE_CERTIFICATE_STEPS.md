# developer@zunsystem.co.jpで証明書を作成する手順

## 1. XcodeにApple IDを追加

1. Xcodeを開く
2. メニューバーから: Xcode → Settings (または Preferences)
3. Accounts タブをクリック
4. 左下の「+」ボタンをクリック
5. 「Apple ID」を選択
6. developer@zunsystem.co.jp でサインイン

## 2. 開発証明書の作成

1. Accounts画面で developer@zunsystem.co.jp を選択
2. 右側の「Manage Certificates...」をクリック
3. 左下の「+」ボタンをクリック
4. 「Apple Development」を選択
5. 証明書が自動的に作成される

## 3. 証明書の確認

ターミナルで以下を実行：
```bash
security find-identity -v -p codesigning | grep zunsystem
```

## 4. プロジェクトの署名設定

1. CursorFinder.xcodeprojを開く
2. プロジェクト設定 → Signing & Capabilities
3. Team を新しいアカウントのチームに変更
4. Signing Certificate を新しい証明書に変更

## 5. テスト署名

```bash
# ビルドディレクトリをクリーン
rm -rf ~/Library/Developer/Xcode/DerivedData/CursorFinder-*

# 新しい証明書でビルド
xcodebuild -scheme CursorFinder -configuration Release build

# 署名を確認
codesign -dv --verbose=4 build/Release/CursorFinder.app
```

## トラブルシューティング

### 証明書が表示されない場合
1. Xcodeを再起動
2. Apple IDでサインインし直す
3. Keychain Accessで古い証明書を削除

### ビルドエラーの場合
1. Product → Clean Build Folder
2. Derived Dataを削除
3. Xcodeを再起動