# Edge Navigation 再実装プラン

**Date**: 2025-10-25
**Status**: Implementation in progress

## 背景

既存のPhysicalEdgeNavigationManagerは物理座標ベースで実装されており、マウスイベントの座標系との変換が複雑かつ非効率です。Edge Zone Pair設計に基づき、論理座標ベースで一から再実装します。

## 設計原則

### 境界の4種類

1辺上には以下の4種類の範囲が存在します：

- **BB (Block→Block)**: 元からBlock、調整後もBlock → macOSデフォルト動作
- **BP (Block→Pass)**: 元Block、調整後Pass → 移動不可を移動可能に変更（将来実装）
- **PP (Pass→Pass)**: 元からPass、調整後もPass → 物理配置補正付き移動
- **PB (Pass→Block)**: 元Pass、調整後Block → 移動可能を移動不可に変更

### キーコンセプト

- **論理座標のみ使用**: 物理座標は不使用（レーザー表示のみで使用）
- **EdgeZone相対位置マッピング**: Zone内の相対位置t ∈ [0,1)でペアにマッピング
- **高速lookup**: Runtime cache（EdgeZoneCache）で効率化
- **実装難易度順**: PB → PP → BP

## データモデル

### EdgeZonePair修正（方向性なし）

```swift
// Before
struct EdgeZonePair {
    let sourceZoneId: UUID
    let targetZoneId: UUID
}

// After
struct EdgeZonePair {
    let zone1Id: UUID  // DisplayIdentifier順で小さい方
    let zone2Id: UUID  // DisplayIdentifier順で大きい方
}
```

### EdgeNavigationCache（新規）

```swift
class EdgeNavigationCache {
    // モニタID → 方向 → EdgeZoneCache配列（ソート済み）
    private var caches: [String: [EdgeDirection: [EdgeZoneCache]]]

    struct EdgeZoneCache {
        let start: CGFloat      // エッジ上の論理座標（開始）
        let end: CGFloat        // エッジ上の論理座標（終了）[start, end)
        let type: ZoneType      // BB/BP/PP/PB
        let pairedZone: EdgeZoneCache?  // PP/BPの場合のペア先
        let pairedScreen: String?       // ペア先のモニタID
    }

    enum ZoneType {
        case BB, BP, PP, PB
    }
}
```

## イベント処理フロー

```
1. マウスイベント発生
   ↓
2. 同じモニタ？ → Yes → 即return
   ↓ No
3. 脱出座標とエッジ方向を特定
   ↓
4. EdgeZoneCache lookup（線形スキャン: O(n), n<10）
   ↓
5. Zone種類に応じた処理:
   - BB: macOSデフォルト
   - PB: エッジ上にワープ戻し（ブロック）
   - PP: ペア先にワープ（補正）
   - BP: 将来実装（意図検出が必要）
```

## 実装フェーズ

### Phase 1: データモデル修正
**ファイル**: `DisplayIdentifier.swift`, `CalibrationDataManager.swift`

- EdgeZonePair: source/target → zone1/zone2
- 自動生成ロジックで正規化（DisplayIdentifier順）

### Phase 2: EdgeNavigationCache実装
**新規ファイル**: `EdgeNavigationCache.swift`

- EdgeZone → EdgeZoneCache変換
- 高速lookup実装
- Zone種類判定（BB/BP/PP/PB）

### Phase 3: EdgeNavigationManager実装
**新規ファイル**: `EdgeNavigationManager.swift`

#### Phase 3-1: 基本骨格
- CGEventTap setup
- 境界交差検出
- 同一モニタ早期return

#### Phase 3-2: PB機能（Pass→Block）
**優先度: 最高 / 難易度: 最低**

```swift
// 越境検出 → エッジ上にワープ戻し
if zoneCache.type == .PB {
    let constrainedPoint = constrainToEdge(exitPoint, direction, screen)
    CGWarpMouseCursorPosition(constrainedPoint)
}
```

#### Phase 3-3: PP機能（Pass→Pass）
**優先度: 高 / 難易度: 中**

```swift
// Zone内相対位置計算 → ペアZoneマッピング
let t = (exitPoint - zone.start) / (zone.end - zone.start)
let targetPoint = pairedZone.start + t * (pairedZone.end - pairedZone.start)
CGWarpMouseCursorPosition(targetPoint)
```

#### Phase 3-4: アクセシビリティ対応
- 権限チェック
- tapDisabled時の自動停止

### Phase 4: 統合
**ファイル**: `AppDelegate.swift`

- 既存PhysicalEdgeNavigationManager削除
- 新EdgeNavigationManager統合
- メニュー項目更新

### Phase 5: クリーンアップ
- `PhysicalEdgeNavigationManager.swift` 削除
- `LaserViewModel.swift` から不要コード削除

### Phase 6: テスト
1. PB機能テスト（越境ブロック）
2. PP機能テスト（ワープ補正）
3. 物理ギャップ対応確認

## 削除対象

- `PhysicalEdgeNavigationManager.swift`（全体）
- 物理座標ベースのワープロジック（全て）
- cursorDidWarp通知関連（フリッカー隠蔽は不要）

## 将来実装

### BP機能（Block→Pass）
**優先度: 低 / 難易度: 最高**

- 越境意図検出（deltaX/deltaY利用）
- BB/PBゾーンから近いPass端点経由でワープ

### 修飾キー対応
- BP/PPを一時的にBlockに変更
- Option/Command等でPassゾーンをBlockゾーンにトグル

## 参考ドキュメント

- `edge-zone-pair-design.md` - 統一モデル設計
- `edge-navigation-design.md` - 旧設計（参考用）
- `smart-edge-navigation.md` - ユーザー向けドキュメント
