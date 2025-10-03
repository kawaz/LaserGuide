// ScreenManager.swift
import SwiftUI

class ScreenManager: ObservableObject {
    @Published var overlayWindows: [NSWindow] = []

    init() {
        setupOverlays()
    }

    func setupOverlays() {
        removeOverlays()

        for screen in NSScreen.screens {
            let viewModel = LaserViewModel(screen: screen)
            let hostingController = NSHostingController(
                rootView: LaserOverlayView(viewModel: viewModel, screen: screen)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )

            let window = createOverlayWindow(for: screen)
            window.contentView = hostingController.view
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)

            viewModel.startTracking()
            overlayWindows.append(window)
        }
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // 基本設定
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true

        // パフォーマンス最適化
        window.displaysWhenScreenProfileChanges = false
        window.allowsConcurrentViewDrawing = true

        // スクリーンショット除外
        window.sharingType = .none

        // Core Animation設定
        if Config.Performance.useCoreAnimationLayers {
            window.contentView?.wantsLayer = true

            if let layer = window.contentView?.layer {
                layer.isOpaque = false
                layer.drawsAsynchronously = true
                layer.contentsScale = window.backingScaleFactor

                // Metal レンダリング（最新の最適化）
                if #available(macOS 10.14, *) {
                    layer.contentsFormat = .RGBA8Uint  // または .RGBA16Float for HDR
                    // layer.acceleratesDisplay = true  // これも非推奨の可能性
                }
            }
        }

        // レベルとビヘイビア
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow))
        )
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]

        return window
    }

    func removeOverlays() {
        for window in overlayWindows {
            if let contentView = window.contentViewController as? NSHostingController<LaserOverlayView> {
                contentView.rootView.viewModel.stopTracking()
            }
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
