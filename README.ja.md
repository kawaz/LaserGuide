# LaserGuide

大画面や複数ディスプレイでマウスカーソルを見つけやすくするmacOSアプリです。画面の四隅からマウスカーソルに向かってレーザーのような線を表示します。

<img width="1200" alt="LaserGuide Demo" src="https://github.com/kawaz/LaserGuide/assets/326750/demo-placeholder.png">

## 機能

- **レーザーライン**: 画面の四隅からマウスカーソルへグラデーション付きレーザーラインを表示
- **マルチディスプレイ対応**: 複数のモニターでシームレスに動作
- **スマート表示**: マウスが静止すると自動的に非表示、動かすと再表示
- **スクリーンショット対応**: レーザーラインはスクリーンショットに写りません（macOS標準のスクリーンショットツール）
- **距離インジケーター**: カーソルが別の画面にある時は距離をパーセンテージで表示
- **視覚効果**: 
  - 先細りレーザーライン（コーナーで太く、カーソル付近で細い）
  - 視認性向上のためのグラデーションカラー
  - MetalによるGPU最適化レンダリング

## 必要環境

- macOS 15.3以降
- Xcode 15.0以降（ソースからビルドする場合）

## インストール

### Homebrewでインストール

```bash
# 方法1: 直接インストール
brew install kawaz/laserguide/laserguide

# 方法2: tapを追加してからインストール
brew tap kawaz/laserguide https://github.com/kawaz/LaserGuide
brew install laserguide
```

### ソースからビルド（Xcode）

1. リポジトリをクローン:
```bash
git clone https://github.com/kawaz/LaserGuide.git
cd LaserGuide
```

2. Xcodeでプロジェクトを開く:
```bash
open [LaserGuide.xcodeproj](LaserGuide.xcodeproj)
```

3. プロジェクトをビルドして実行（⌘+R）

### ソースからビルド（CLI）

1. リポジトリをクローン:
```bash
git clone https://github.com/kawaz/LaserGuide.git
cd LaserGuide
```

2. Makeを使用してビルドと実行:
```bash
# デバッグ版をビルドして実行
make dev

# ビルドのみ（デバッグ版）
make build-debug

# リリース版をビルド
make build-release

# リリース版をビルドしてzipを作成
make build-zip
```

3. xcodebuildで手動ビルド:
```bash
# デバッグ版をビルド
xcodebuild -scheme LaserGuide -configuration Debug build

# リリース版をビルド  
xcodebuild -scheme LaserGuide -configuration Release build
```

注: 現在のリリースは配布を容易にするためコード署名なしでビルドされています。

### ビルド済みバイナリ

[リリースページ](https://github.com/kawaz/LaserGuide/releases)から最新版をダウンロードしてください。

1. `LaserGuide.zip`をダウンロード
2. 解凍して`LaserGuide.app`をアプリケーションフォルダに移動
3. アプリを開く（初回は右クリックして「開く」を選択する必要があるかもしれません）

## 使い方

1. LaserGuideを起動
2. メニューバーの🔍アイコンを確認
3. マウスを動かすとレーザーラインが表示されます
4. 0.3秒間動かさないと自動的に消えます
5. 終了するには、メニューバーアイコンをクリックして「Quit」を選択

## 設定

現在の設定オプションは[`Config.swift`](LaserGuide/Config.swift)で変更可能:

- **表示設定**: 線の太さ、グラデーションカラー
- **タイミング**: 非アクティブ時の閾値
- **パフォーマンス**: GPU最適化の切り替え

## プライバシーとセキュリティ

LaserGuideはマウスの動きをグローバルに追跡するためアクセシビリティ権限が必要です。このアプリは:
- データの収集や送信は一切行いません
- マウス位置は表示目的のみで使用されます
- 完全にローカルで動作します

## 開発

### 利用可能なMakeコマンド

```bash
make               # 利用可能なコマンドを表示
make dev           # デバッグ版をビルドして実行
make build-debug   # デバッグ版のビルドのみ
make build-release # リリース版をビルド
make build-zip     # リリース版をビルドしてzipを作成
make clean         # ビルド成果物をクリーン
```

### リリースプロセス

詳細なリリース手順については[CONTRIBUTING.md](CONTRIBUTING.md#release-process)を参照してください。

## 貢献

貢献を歓迎します！詳細は[CONTRIBUTING.md](CONTRIBUTING.md)をご覧ください。

## ライセンス

このプロジェクトはMITライセンスの下でライセンスされています - 詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 謝辞

- SwiftUIとmacOSネイティブフレームワークで構築
- GPU最適化レンダリングにMetalを使用