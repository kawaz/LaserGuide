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
    private var lastUpdateTime: Date = .init()
    private var debounceWorkItem: DispatchWorkItem?

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
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    // MARK: - Private Methods

    private func setupMouseTracking() {
        // 初期化時にマウス位置を取得
        currentMouseLocation = NSEvent.mouseLocation
    }

    private func setupGlobalMouseMonitor() {
        // グローバルマウスイベントを監視
        // マウスの実際の移動のみを検出（スクロールの慣性は無視）
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
        lastUpdateTime = Date()

        // レーザーを表示
        if !isMouseActive {
            isMouseActive = true
        }

        // Debounce: 前回のhide処理をキャンセルして新しくスケジュール
        scheduleHideWithDebounce()
    }

    private func scheduleHideWithDebounce() {
        // 既存のワークアイテムをキャンセル
        debounceWorkItem?.cancel()

        // 新しいワークアイテムを作成
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 最後の更新から指定時間経過していたら非表示
            let timeSinceLastUpdate = Date().timeIntervalSince(self.lastUpdateTime)
            if timeSinceLastUpdate >= Config.Timing.inactivityThreshold {
                self.isMouseActive = false
            }
        }

        debounceWorkItem = workItem

        // 指定時間後に実行
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Config.Timing.inactivityThreshold,
            execute: workItem
        )
    }

    deinit {
        stopTracking()
    }
}
