// LaserViewModel.swift
import SwiftUI
import Combine

extension Notification.Name {
    static let calibrationDidSave = Notification.Name("LaserGuide.calibrationDidSave")
    static let calibrationDidChange = Notification.Name("LaserGuide.calibrationDidChange")
    static let usePhysicalLayoutDidChange = Notification.Name("LaserGuide.usePhysicalLayoutDidChange")
}

class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    @Published var physicalConfiguration: DisplayConfiguration?
    @Published var usePhysicalLayout: Bool = true
    @Published var displayNumber: Int?  // モニター識別番号（表示中のみ）
    @Published var showIdentification: Bool = false  // 識別番号の表示状態

    private var subscribers = Set<AnyCancellable>()
    private let mouseTrackingManager = MouseTrackingManager.shared
    private let calibrationManager = CalibrationDataManager.shared

    init() {
        // Load settings from UserDefaults
        usePhysicalLayout = UserDefaults.standard.bool(forKey: "UsePhysicalLayout")
        if UserDefaults.standard.object(forKey: "UsePhysicalLayout") == nil {
            // Default to true if not set
            usePhysicalLayout = true
            UserDefaults.standard.set(true, forKey: "UsePhysicalLayout")
        }

        setupMouseTracking()
        loadPhysicalConfiguration()
        setupCalibrationObserver()
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

    private func setupCalibrationObserver() {
        // キャリブレーション保存の通知を監視
        NotificationCenter.default.publisher(for: .calibrationDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadPhysicalConfiguration()
            }
            .store(in: &subscribers)

        // キャリブレーション変更の通知を監視（リアルタイムプレビュー用）
        NotificationCenter.default.publisher(for: .calibrationDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadPhysicalConfiguration()
            }
            .store(in: &subscribers)

        // 物理レイアウト使用設定の変更を監視
        NotificationCenter.default.publisher(for: .usePhysicalLayoutDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let enabled = notification.object as? Bool {
                    self?.usePhysicalLayout = enabled
                    NSLog("🔧 Physical layout mode: \(enabled ? "ON" : "OFF")")
                }
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

    private func loadPhysicalConfiguration() {
        physicalConfiguration = calibrationManager.loadCalibration()
        if physicalConfiguration != nil {
            NSLog("📐 Physical layout calibration loaded for laser display")
        } else {
            NSLog("⚠️ No physical layout calibration found, using logical coordinates only")
        }
    }

    /// Reload physical configuration (called when calibration is updated)
    func reloadPhysicalConfiguration() {
        loadPhysicalConfiguration()
    }

    deinit {
        stopTracking()
    }
}
