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
    private var debounceWorkItem: DispatchWorkItem?

    // MARK: - Singleton
    static let shared = MouseTrackingManager()

    private init() {}

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
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    // MARK: - Private Methods

    private func setupGlobalMouseMonitor() {
        // マウスの移動を監視する
        // - ドラッグ中は mouseMoved の代わりに *Dragged イベントが発生するのでそちらも監視する
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMouseLocation(NSEvent.mouseLocation)
            }
        }
    }

    private func updateMouseLocation(_ location: CGPoint) {
        currentMouseLocation = location
        isMouseActive = true
        scheduleHideWithDebounce()
    }

    private func scheduleHideWithDebounce() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.isMouseActive = false
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Config.Timing.inactivityThreshold,
            execute: workItem
        )
    }

    deinit {
        stopTracking()
    }
}
