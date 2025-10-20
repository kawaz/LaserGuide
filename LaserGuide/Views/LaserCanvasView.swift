// LaserCanvasView.swift
import SwiftUI
import simd

struct LaserCanvasView: View {
    @ObservedObject var viewModel: LaserViewModel
    private let screenBounds: CGRect
    private let screenSize: CGSize
    private let corners: [SIMD2<Float>]

    private enum Constants {
        static let cornerWidth: CGFloat = 8.0
        static let targetWidth: CGFloat = 0.5
        static let indicatorOffset: CGFloat = 30.0
        static let indicatorFontSize: CGFloat = 16.0
        static let maxPercentage: Double = 999.0
        static let minimumDistance: CGFloat = 1.0
    }

    init(viewModel: LaserViewModel, screen: NSScreen) {
        self.viewModel = viewModel
        self.screenBounds = screen.frame
        self.screenSize = screen.frame.size

        // 事前計算されたコーナー座標
        self.corners = [
            SIMD2(0, 0),
            SIMD2(Float(screenSize.width), 0),
            SIMD2(0, Float(screenSize.height)),
            SIMD2(Float(screenSize.width), Float(screenSize.height))
        ]
    }

    var body: some View {
        Canvas { context, size in
            // 座標変換は一度だけ
            let targetPoint = convertToLocalCoordinates(viewModel.currentMouseLocation)
            let targetSIMD = SIMD2<Float>(Float(targetPoint.x), Float(targetPoint.y))

            // グラデーション事前作成
            let gradient = Gradient(stops: Config.Visual.gradientStops)

            // レーザー描画
            drawAllLasers(
                context: context,
                target: targetPoint,
                targetSIMD: targetSIMD,
                gradient: gradient
            )

            // 画面外の場合のみインジケータ描画
            if isOffScreen(targetPoint, size: size) {
                drawDistanceIndicators(
                    context: context,
                    target: targetPoint,
                    targetSIMD: targetSIMD,
                    size: size
                )
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear) // Metal最適化
    }

    @inline(__always)
    private func convertToLocalCoordinates(_ globalLocation: NSPoint) -> CGPoint {
        let localX = globalLocation.x - screenBounds.minX
        let localY = globalLocation.y - screenBounds.minY
        let convertedY = screenSize.height - localY
        return CGPoint(x: localX, y: convertedY)
    }

    @inline(__always)
    private func isOffScreen(_ point: CGPoint, size: CGSize) -> Bool {
        point.x < 0 || point.x > size.width ||
        point.y < 0 || point.y > size.height
    }

    private func drawAllLasers(
        context: GraphicsContext,
        target: CGPoint,
        targetSIMD: SIMD2<Float>,
        gradient: Gradient
    ) {
        for corner in corners {
            let delta = targetSIMD - corner
            let distance = length(delta)

            // 最小距離チェック
            guard distance > Float(Constants.minimumDistance) else { continue }

            // パス作成（SIMD最適化）
            let path = createOptimizedLaserPath(
                from: corner,
                to: targetSIMD,
                delta: delta,
                distance: distance
            )

            // グラデーション描画
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: CGFloat(corner.x), y: CGFloat(corner.y)),
                    endPoint: target
                )
            )
        }
    }

    @inline(__always)
    private func createOptimizedLaserPath(
        from corner: SIMD2<Float>,
        to target: SIMD2<Float>,
        delta: SIMD2<Float>,
        distance: Float
    ) -> Path {
        Path { path in
            // 正規化された垂直ベクトル
            let normalized = delta / distance
            let perpendicular = SIMD2<Float>(-normalized.y, normalized.x)

            // 幅の計算
            let cornerWidth = Float(Constants.cornerWidth)
            let targetWidth = Float(Constants.targetWidth)

            // 台形の頂点計算（SIMD演算）
            let c1 = corner + perpendicular * cornerWidth
            let c2 = corner - perpendicular * cornerWidth
            let t1 = target + perpendicular * targetWidth
            let t2 = target - perpendicular * targetWidth

            // パス構築
            path.move(to: CGPoint(x: CGFloat(c1.x), y: CGFloat(c1.y)))
            path.addLine(to: CGPoint(x: CGFloat(t1.x), y: CGFloat(t1.y)))
            path.addLine(to: CGPoint(x: CGFloat(t2.x), y: CGFloat(t2.y)))
            path.addLine(to: CGPoint(x: CGFloat(c2.x), y: CGFloat(c2.y)))
            path.closeSubpath()
        }
    }

    private func drawDistanceIndicators(
        context: GraphicsContext,
        target: CGPoint,
        targetSIMD: SIMD2<Float>,
        size: CGSize
    ) {
        let indicators = calculateIndicators(
            target: target,
            targetSIMD: targetSIMD,
            size: size
        )

        for indicator in indicators {
            // Shadow効果付きテキスト描画
            let text = context.resolve(
                Text("\(Int(indicator.percentage))%")
                    .font(.system(
                        size: Constants.indicatorFontSize,
                        weight: .bold,
                        design: .monospaced
                    ))
                    .foregroundColor(.white)
            )

            // 影を追加
            context.drawLayer { ctx in
                // 黒い影
                ctx.opacity = 0.5
                ctx.draw(text, at: CGPoint(
                    x: indicator.position.x + 1,
                    y: indicator.position.y + 1
                ))
            }

            // 本体のテキスト
            context.draw(text, at: indicator.position)
        }
    }

    private func calculateIndicators(
        target: CGPoint,
        targetSIMD: SIMD2<Float>,
        size: CGSize
    ) -> [DistanceIndicator] {
        var indicators: [DistanceIndicator] = []

        for corner in corners {
            if let intersection = calculateScreenEdgeIntersection(
                from: corner,
                to: targetSIMD,
                screenSize: size
            ) {
                // 距離計算
                let visibleDistance = length(intersection - corner)  // 画面内の距離
                let totalDistance = length(targetSIMD - corner)  // 全体の距離

                // 画面内の距離 ÷ 全体の距離
                let percentage = Double(visibleDistance / totalDistance) * 100

                // テキスト位置計算
                let textPosition = calculateTextPosition(
                    intersection: CGPoint(x: CGFloat(intersection.x), y: CGFloat(intersection.y)),
                    size: size
                )

                indicators.append(DistanceIndicator(
                    corner: CGPoint(x: CGFloat(corner.x), y: CGFloat(corner.y)),
                    position: textPosition,
                    percentage: min(percentage, Constants.maxPercentage)
                ))
            }
        }

        return indicators
    }

    @inline(__always)
    private func calculateScreenEdgeIntersection(
        from: SIMD2<Float>,
        to: SIMD2<Float>,
        screenSize: CGSize
    ) -> SIMD2<Float>? {
        let delta = to - from

        // 移動なしの場合
        if length_squared(delta) < 0.001 { return nil }

        var tMin: Float = 0
        var tMax: Float = 1

        let screenWidth = Float(screenSize.width)
        let screenHeight = Float(screenSize.height)

        // X軸の交差チェック
        if delta.x != 0 {
            let t1 = (0 - from.x) / delta.x
            let t2 = (screenWidth - from.x) / delta.x

            tMin = max(tMin, min(t1, t2))
            tMax = min(tMax, max(t1, t2))
        }

        // Y軸の交差チェック
        if delta.y != 0 {
            let t1 = (0 - from.y) / delta.y
            let t2 = (screenHeight - from.y) / delta.y

            tMin = max(tMin, min(t1, t2))
            tMax = min(tMax, max(t1, t2))
        }

        // 交差なし
        if tMin > tMax { return nil }

        // 交点を返す
        if tMax >= 0 && tMax <= 1 {
            return from + delta * tMax
        }

        return nil
    }

    @inline(__always)
    private func calculateTextPosition(intersection: CGPoint, size: CGSize) -> CGPoint {
        var position = intersection
        let offset = Constants.indicatorOffset

        // エッジからオフセット
        if intersection.x <= 0 {
            position.x = offset
        } else if intersection.x >= size.width {
            position.x = size.width - offset
        }

        if intersection.y <= 0 {
            position.y = offset
        } else if intersection.y >= size.height {
            position.y = size.height - offset
        }

        return position
    }

    struct DistanceIndicator {
        let corner: CGPoint
        let position: CGPoint
        let percentage: Double
    }
}
