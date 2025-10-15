# マルチディスプレイPPI補正 - 実装詳細

## 概要

異なるピクセル密度を持つディスプレイ間で正確なレーザーライン角度を実現するためのPPI（Pixels Per Inch）補正の実装。

## 実装日

2025年10月7日

## コアコンポーネント

### 1. ScreenInfo (`Models/ScreenInfo.swift`)

PPI計算を含むディスプレイ情報を管理：

```swift
struct ScreenInfo {
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    let ppi: CGFloat
    let physicalSize: CGSize  // ミリメートル単位

    func correctionFactor(cursorScreen: ScreenInfo) -> CGFloat {
        return cursorScreen.ppi / self.ppi
    }
}
```

**機能:**
- 物理サイズと解像度からPPIを自動計算
- 補正係数計算メソッドを提供
- 物理サイズが取得できない場合の標準PPIフォールバック
- ディスプレイ名と内蔵判定のヘルパープロパティ

### 2. ScreenManager更新 (`Managers/ScreenManager.swift`)

ディスプレイ情報の管理を強化：

```swift
class ScreenManager: ObservableObject {
    private(set) var screenInfos: [ScreenInfo] = []

    func setupOverlays() {
        screenInfos = NSScreen.screens.compactMap { ScreenInfo(screen: $0) }

        for screenInfo in screenInfos {
            let viewModel = LaserViewModel(
                screenInfo: screenInfo,
                allScreens: screenInfos
            )
            // ... オーバーレイ設定
        }
    }
}
```

**変更点:**
- 全ディスプレイの`ScreenInfo`配列を構築・キャッシュ
- 各`LaserViewModel`にディスプレイ情報を渡す

### 3. LaserViewModel更新 (`Models/LaserViewModel.swift`)

PPI補正ロジックを追加：

```swift
class LaserViewModel: ObservableObject {
    private let screenInfo: ScreenInfo
    private let allScreens: [ScreenInfo]

    func correctionFactor(for cursorLocation: CGPoint) -> CGFloat {
        guard let cursorScreen = getScreen(containing: cursorLocation) else {
            return 1.0
        }

        // 同一画面の場合は補正不要
        if cursorScreen.displayID == screenInfo.displayID {
            return 1.0
        }

        // 異なる画面の場合はPPIベースの補正を適用
        return screenInfo.correctionFactor(cursorScreen: cursorScreen)
    }
}
```

**ロジック:**
- カーソルを含む画面を検出
- 同一画面の場合は1.0（補正なし）を返す
- 異なる画面の場合はPPI比率を返す

### 4. LaserCanvasView更新 (`Views/LaserCanvasView.swift`)

レーザー描画に補正を適用：

```swift
private func drawAllLasers(
    context: GraphicsContext,
    target: CGPoint,
    targetSIMD: SIMD2<Float>,
    correctionFactor: Float,
    gradient: Gradient
) {
    for corner in corners {
        let delta = targetSIMD - corner

        // PPI補正を適用
        let correctedTarget = corner + delta * correctionFactor
        let correctedDelta = correctedTarget - corner
        let correctedDistance = length(correctedDelta)

        // 補正された値で描画
        let path = createOptimizedLaserPath(
            from: corner,
            to: correctedTarget,
            delta: correctedDelta,
            distance: correctedDistance
        )
        // ...
    }
}
```

**補正が適用される箇所:**
1. レーザーラインの終点
2. レーザーラインのグラデーション
3. 距離インジケータ（パーセンテージ計算）

## 動作原理

### 例: カーソルが内蔵ディスプレイ、レーザーがLGディスプレイ

**ディスプレイスペック:**
- 内蔵: 3456×2234, 344mm, PPI = 255
- LG: 3440×1440, 1053mm, PPI = 83

**補正計算:**
```
補正係数 = カーソル側PPI / レーザー側PPI
        = 255 / 83
        = 3.07
```

**結果:**
- LGディスプレイ上のレーザーラインが角から**3.07倍遠く**に伸びる
- LGの大きな物理ピクセルを補正
- 物理的な角度が内蔵ディスプレイ上のカーソル角度と一致

### 例: カーソルがLGディスプレイ、レーザーが内蔵ディスプレイ

**補正計算:**
```
補正係数 = カーソル側PPI / レーザー側PPI
        = 83 / 255
        = 0.33
```

**結果:**
- 内蔵ディスプレイ上のレーザーラインが角から**0.33倍短く**なる
- 内蔵の小さな物理ピクセルを補正
- 物理的な角度がLGディスプレイ上のカーソル角度と一致

## アルゴリズム詳細

### 距離補正式

角`C`からカーソル位置`P`へのレーザーラインの場合：

```
元のベクトル: D = P - C
補正されたベクトル: D' = D × 補正係数
補正されたターゲット: P' = C + D'
```

これにより維持されるもの：
- ✅ 方向: 角からの角度が同じ
- ✅ 物理的正確性: PPI比率でスケーリング
- ✅ 視覚的一貫性: ディスプレイ間で正しく指し示す

### 座標系

論理座標系（macOSネイティブ）を使用：
- システム環境設定のディスプレイ配置を尊重
- 物理的配置の推測が不要
- あらゆるディスプレイ設定で動作

## パフォーマンスへの配慮

1. **PPI計算:** オーバーレイ設定時に一度だけ実行
2. **補正係数:** フレームごとに計算するが軽量
3. **SIMD演算:** ベクトル計算にSIMDを使用して効率化
4. **追加オーバーヘッドなし:** 補正は単純な乗算

## テストチェックリスト

- [ ] カーソルが内蔵、レーザーがLG: ラインが正しく指す
- [ ] カーソルがLG、レーザーが内蔵: ラインが正しく指す
- [ ] カーソルが同一画面: 補正なし（係数 = 1.0）
- [ ] 3台以上のディスプレイ: 各ディスプレイが独立して補正
- [ ] 距離インジケータが正しいパーセンテージを表示
- [ ] パフォーマンス低下なし

## 既知の制限事項

1. **配置のミスマッチ:**
   - 論理的配置が物理的配置と大きく異なる場合
   - ユーザーは物理配置に合わせてシステム環境設定を調整すべき

2. **ディスプレイミラーリング:**
   - ミラーリングされたディスプレイではテストされていない
   - ミラーリング設定では補正が不要な可能性

3. **回転:**
   - 回転されたディスプレイではテストされていない
   - 追加の角度補正が必要な可能性

## 今後の拡張

1. **ユーザーキャリブレーション:**
   - オプションの手動調整係数（0.5倍 - 2.0倍）
   - 微調整のための設定UI

2. **回転サポート:**
   - ディスプレイ回転を検出
   - 回転されたディスプレイに角度補正を適用

3. **ミラーリング検出:**
   - ミラーリングされたディスプレイを検出
   - 適切な場合に補正を無効化

## 参考資料

- 設計判断: `docs/multi-display-ppi-correction.md`
- ディスプレイ情報スクリプト: `scripts/display-info.swift`
- 問題議論: 2025-10-07 マルチディスプレイ補正分析
