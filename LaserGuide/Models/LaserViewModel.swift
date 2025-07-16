// LaserViewModel.swift
import SwiftUI
import Combine

class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    
    private let screen: NSScreen
    private var subscribers = Set<AnyCancellable>()
    private let mouseTrackingManager = MouseTrackingManager.shared
    
    init(screen: NSScreen) {
        self.screen = screen
        setupMouseTracking()
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
