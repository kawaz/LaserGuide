// MouseTrackingManager.swift
import SwiftUI
import Combine

/// システム全体のマウス追跡を管理するクラス
/// アプリケーションのフォーカス状態に依存せず、グローバルなマウスイベントを監視する
class MouseTrackingManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentMouseLocation: CGPoint = .zero
    @Published var isMouseActive: Bool = false
    
    // MARK: - Private Properties
    private var mouseMoveMonitor: Any?
    private var hideTimer: Timer?
    private var subscribers = Set<AnyCancellable>()
    
    // MARK: - Singleton
    static let shared = MouseTrackingManager()
    
    private init() {
        setupMouseTracking()
    }
    
    // MARK: - Public Methods
    
    /// マウス追跡を開始する
    func startTracking() {
        stopTracking()
        setupGlobalMouseMonitor()
    }
    
    /// マウス追跡を停止する
    func stopTracking() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupMouseTracking() {
        // 初期化時にマウス位置を取得
        currentMouseLocation = NSEvent.mouseLocation
    }
    
    private func setupGlobalMouseMonitor() {
        // グローバルマウスイベントを監視
        // トレイアイコンクリック中でも継続して動作する
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] _ in
            guard let self = self else { return }
            
            let location = NSEvent.mouseLocation
            
            // メインスレッドで状態を更新
            DispatchQueue.main.async {
                self.updateMouseLocation(location)
            }
        }
    }
    
    private func updateMouseLocation(_ location: CGPoint) {
        currentMouseLocation = location
        isMouseActive = true
        scheduleHideTimer()
    }
    
    private func scheduleHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Config.Timing.inactivityThreshold,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isMouseActive = false
            }
        }
    }
    
    deinit {
        stopTracking()
    }
}