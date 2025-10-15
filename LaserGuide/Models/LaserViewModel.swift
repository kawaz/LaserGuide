// LaserViewModel.swift
import SwiftUI
import Combine

class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero

    private let screenInfo: ScreenInfo
    private let allScreens: [ScreenInfo]
    private var subscribers = Set<AnyCancellable>()
    private let mouseTrackingManager = MouseTrackingManager.shared

    init(screenInfo: ScreenInfo, allScreens: [ScreenInfo]) {
        self.screenInfo = screenInfo
        self.allScreens = allScreens
        setupMouseTracking()
    }

    /// Get the screen containing the given point
    private func getScreen(containing point: CGPoint) -> ScreenInfo? {
        return allScreens.first { screenInfo in
            screenInfo.screen.frame.contains(point)
        }
    }

    /// Calculate PPI correction factor for cross-display laser drawing
    /// - Parameter cursorLocation: Current cursor position
    /// - Returns: Correction factor (1.0 if same screen, ppiRatio if different)
    func correctionFactor(for cursorLocation: CGPoint) -> CGFloat {
        guard let cursorScreen = getScreen(containing: cursorLocation) else {
            return 1.0
        }

        // If cursor is on the same screen as this laser overlay, no correction needed
        if cursorScreen.displayID == screenInfo.displayID {
            return 1.0
        }

        // Apply PPI-based correction for cross-display drawing
        return screenInfo.correctionFactor(cursorScreen: cursorScreen)
    }
    
    private func setupMouseTracking() {
        // MouseTrackingManagerからマウス位置の変更を監視
        mouseTrackingManager.$currentMouseLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentMouseLocation = location
            }
            .store(in: &subscribers)
        
        // MouseTrackingManagerからマウスアクティブ状態の変更を監視
        mouseTrackingManager.$isMouseActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.isVisible = isActive
            }
            .store(in: &subscribers)
    }
    
    func startTracking() {
        // グローバルマウス追跡を開始
        mouseTrackingManager.startTracking()
    }
    
    func stopTracking() {
        // 個別のViewModelが停止されても、他のスクリーンで使用されている可能性があるため
        // MouseTrackingManagerは停止しない
        subscribers.removeAll()
    }
    
    deinit {
        stopTracking()
    }
}
