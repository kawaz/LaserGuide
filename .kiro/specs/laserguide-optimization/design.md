# Design Document

## Overview

LaserGuideアプリケーションの品質向上と配布プロセス自動化のための包括的な改善設計です。現在のコードベース分析により、以下の主要問題が特定されました：

1. **不要なコード**: 使用されていない設定値、重複したロジック
2. **レーザー表示の非表示問題**: タイマーとイベントモニターの競合状態
3. **CI/CD配布プロセス**: 不完全なワークフロー設定

## Architecture

### 問題分析結果

#### 1. 不要なコードの特定
- `Config.Visual.laserOpacity`: 使用されていない
- `Config.Visual.fadeAnimationDuration`: 使用されていない  
- `Config.Visual.minLineWidth/maxLineWidth`: 使用されていない
- `Config.Timing.mousePositionUpdateInterval`: 使用されていない
- `Config.Performance.idleUpdateInterval`: 使用されていない
- `Config.Performance.enableHighPerformanceMode`: 使用されていない
- `LaserViewModel.mouseDistance`: 計算されているが表示に使用されていない

#### 2. レーザー表示問題の根本原因
- `scheduleNextUpdate()`の再帰的タイマーが適切に停止されない
- `inactivitySubject`のdebounceと`mouseMoveMonitor`の競合
- `isVisible`状態の非同期更新による競合状態
- メモリリーク: タイマーとモニターの不完全な解放
- トレイメニュー表示時: マウスイベントが発生しないためレーザーが固定される
- システムUI表示時: レーザーが適切に一時停止されない

#### 3. CI/CD問題
- ワークフローファイルが途中で切れている
- Formulaファイルが古いバージョンを参照
- Caskとの重複配布設定

## Components and Interfaces

### 1. コードクリーンアップコンポーネント

```swift
// 簡素化されたConfig構造
struct Config {
    struct Visual {
        static let gradientStops: [Gradient.Stop] = [...]
        static let enableMetalOptimization = true
    }
    
    struct Timing {
        static let inactivityThreshold: TimeInterval = 0.3
    }
    
    struct Window {
        static let windowLevel: NSWindow.Level = ...
        static let collectionBehavior: NSWindow.CollectionBehavior = ...
    }
}
```

### 2. 改善されたLaserViewModel

```swift
class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    
    private var cancellables = Set<AnyCancellable>()
    private var mouseMoveMonitor: Any?
    private var hideTimer: Timer?
    private let screen: NSScreen
    
    // 単一の責任を持つタイマー管理
    private func scheduleHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Config.Timing.inactivityThreshold, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isVisible = false
            }
        }
    }
}
```

### 3. CI/CD自動化システム

```yaml
# 完全なワークフロー設計
name: CD - Auto Release and Deploy
on:
  push:
    branches: [main]
    
jobs:
  auto-release:
    runs-on: macos-latest
    steps:
      - name: Check changes and determine version
      - name: Build universal binary
      - name: Create GitHub release
      - name: Update Homebrew Cask
      - name: Notify completion
```

## Data Models

### 1. 簡素化されたViewModelデータフロー

```
MouseEvent → LaserViewModel → UI Update
     ↓
  Timer Reset → Hide Delay → UI Hide
```

### 2. CI/CDデータフロー

```
Git Push → Change Detection → Version Bump → Build → Release → Cask Update
```

## Error Handling

### 1. レーザー表示エラー処理
- タイマーの重複実行防止
- メモリリークの防止
- 状態同期の保証

### 2. CI/CDエラー処理
- ビルド失敗時の適切なエラー報告
- バージョン競合の検出と回避
- Homebrew更新失敗時のロールバック

## Testing Strategy

### 1. 単体テスト
- LaserViewModelの状態遷移テスト
- タイマー管理のテスト
- メモリリーク検出テスト

### 2. 統合テスト
- マルチスクリーン環境でのテスト
- CI/CDパイプラインのテスト
- Homebrew配布のテスト

### 3. パフォーマンステスト
- GPU使用率の監視
- メモリ使用量の監視
- レスポンス時間の測定

## Implementation Plan

### Phase 1: コードクリーンアップ
1. 不要な設定値の除去
2. 使用されていないプロパティの削除
3. 重複ロジックの統合

### Phase 2: レーザー表示問題の修正
1. タイマー管理の単純化
2. 状態管理の改善
3. メモリリーク修正

### Phase 3: CI/CD自動化
1. ワークフローファイルの完成
2. Homebrew配布の自動化
3. エラーハンドリングの追加

### Phase 4: 品質保証
1. テストの追加
2. パフォーマンス監視
3. ドキュメント更新