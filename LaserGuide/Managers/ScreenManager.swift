// ScreenManager.swift
import SwiftUI

class ScreenManager: ObservableObject {
    static let shared = ScreenManager()

    @Published var overlayWindows: [NSWindow] = []
    var hostingControllers: [NSHostingController<LaserOverlayView>] = []  // Public for CalibrationViewModel access
    private var hideWorkItems: [DispatchWorkItem] = []  // Track hide tasks to cancel them

    private init() {
        setupOverlays()
    }

    func setupOverlays() {
        removeOverlays()

        for screen in NSScreen.screens {
            let viewModel = LaserViewModel()
            let overlayView = LaserOverlayView(viewModel: viewModel, screen: screen)
            let hostingController = NSHostingController(rootView: overlayView)

            let window = createOverlayWindow(for: screen)
            window.contentViewController = hostingController
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)

            viewModel.startTracking()
            overlayWindows.append(window)
            hostingControllers.append(hostingController)  // Keep strong reference
            hideWorkItems.append(DispatchWorkItem {})  // Placeholder (cancelled immediately)
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
        // Cancel all pending hide tasks
        for workItem in hideWorkItems {
            workItem.cancel()
        }

        for controller in hostingControllers {
            controller.rootView.viewModel.stopTracking()
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        hostingControllers.removeAll()
        hideWorkItems.removeAll()
    }

    /// Flash identification number on specified screen
    func flashIdentification(on screen: NSScreen, number: Int, duration: TimeInterval = 2.0) {
        NSLog("🔍 flashIdentification called: screen=\(screen.localizedName), number=\(number)")
        NSLog("🔍 Total hosting controllers: \(hostingControllers.count)")

        // Find the hosting controller for this screen
        guard let controllerIndex = hostingControllers.firstIndex(where: { $0.rootView.screen == screen }) else {
            NSLog("❌ Could not find hosting controller for screen: \(screen.localizedName)")
            return
        }

        NSLog("🔍 Found controller at index: \(controllerIndex)")

        // Cancel previous hide task for this screen
        hideWorkItems[controllerIndex].cancel()

        let viewModel = hostingControllers[controllerIndex].rootView.viewModel

        // Set number and show
        NSLog("🔍 Setting displayNumber=\(number), showIdentification=true")
        viewModel.displayNumber = number
        viewModel.showIdentification = true

        // Create new hide task
        let hideTask = DispatchWorkItem { [weak viewModel] in
            NSLog("🔍 Hiding identification")
            viewModel?.showIdentification = false
            viewModel?.displayNumber = nil
        }
        hideWorkItems[controllerIndex] = hideTask

        // Schedule hide after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: hideTask)
    }
}
