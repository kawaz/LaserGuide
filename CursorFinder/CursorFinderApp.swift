// CursorFinderApp.swift
import SwiftUI
import Combine

// MARK: - App Entry Point
@main
struct CursorFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var screenManager = ScreenManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        screenManager.setupOverlays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "🔍"
        }

        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func screensDidChange() {
        screenManager.setupOverlays()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - ScreenManager
class ScreenManager: ObservableObject {
    @Published var overlayWindows: [NSWindow] = []

    init() {
        setupOverlays()
    }

    func setupOverlays() {
        removeOverlays()

        for screen in NSScreen.screens {
            let viewModel = LaserViewModel()
            let hostingController = NSHostingController(
                rootView: LaserOverlayView(viewModel: viewModel, screen: screen)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )

            window.contentView = hostingController.view
            window.backgroundColor = .clear
            window.isOpaque = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true

            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)

            viewModel.startTracking()
            overlayWindows.append(window)
        }
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

// MARK: - ViewModel
class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var currentMouseLocation: CGPoint = .zero

    private var cancellables = Set<AnyCancellable>()
    private var mouseMoveMonitor: Any?
    private var mouseDragMonitor: Any?
    private var inactivitySubject = PassthroughSubject<Void, Never>()
    private var lastMouseMoveTime: Date = Date()
    private let inactivityThreshold: TimeInterval = 0.3
    private var mousePositionTimer: Timer?

    init() {
        setupInactivityPublisher()
        startMousePositionTimer()
    }

    private func setupInactivityPublisher() {
        inactivitySubject
            .debounce(for: .seconds(inactivityThreshold), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 最後のマウス移動から2秒以上経過した場合のみ非表示にする
                let currentTime = Date()
                if currentTime.timeIntervalSince(self.lastMouseMoveTime) >= self.inactivityThreshold {
                    self.isVisible = false
                }
            }
            .store(in: &cancellables)
    }

    private func startMousePositionTimer() {
        // 60FPSに近い更新頻度で位置を更新
        mousePositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let location = NSEvent.mouseLocation

            // 現在の位置と保存されている位置が異なる場合、マウスが移動したとみなす
            if self.currentMouseLocation != location {
                self.lastMouseMoveTime = Date()
                self.isVisible = true
                self.inactivitySubject.send()
            }

            DispatchQueue.main.async {
                self.currentMouseLocation = location
            }
        }
    }

    func startTracking() {
        stopTracking()

        // マウス移動の監視（mouseMovedはleftMouseDraggedの動きを含まないので両方監視）
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            self.lastMouseMoveTime = Date()

            // マウスの動きを検出したらUIを表示
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isVisible = true
                self.inactivitySubject.send()
            }
        }

        // UI更新はメインスレッドで行う
        DispatchQueue.main.async { [weak self] in
            self?.isVisible = true
        }
    }

    func stopTracking() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }

        if let monitor = mouseDragMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDragMonitor = nil
        }
    }

    deinit {
        stopTracking()
        mousePositionTimer?.invalidate()
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }
}

// MARK: - Views
struct LaserOverlayView: View {
    @ObservedObject var viewModel: LaserViewModel
    let screen: NSScreen

    var body: some View {
        ZStack {
            if viewModel.isVisible {
                LaserCanvasView(viewModel: viewModel, screen: screen)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct LaserCanvasView: View {
    @ObservedObject var viewModel: LaserViewModel
    let screen: NSScreen

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear // 透明な背景

                Canvas { context, size in
                    // ビューの四隅の座標（ローカル座標系）
                    let corners = [
                        CGPoint(x: 0, y: 0),
                        CGPoint(x: size.width, y: 0),
                        CGPoint(x: 0, y: size.height),
                        CGPoint(x: size.width, y: size.height)
                    ]

                    // グローバル座標系でのマウス位置
                    let globalMouseLocation = viewModel.currentMouseLocation

                    // 現在の画面のローカル座標系に変換
                    // macOSの座標系では左下が原点、Y軸は上向きが正
                    let localX = globalMouseLocation.x - screen.frame.minX
                    let localY = globalMouseLocation.y - screen.frame.minY

                    // macOSでの座標系（左下原点）からSwiftUIの座標系（左上原点）に変換
                    let convertedY = screen.frame.height - localY

                    let targetPoint = CGPoint(x: localX, y: convertedY)

                    // 各コーナーからマウス位置へのレーザー線を描画
                    for corner in corners {
                        let path = Path { p in
                            p.move(to: corner)
                            p.addLine(to: targetPoint)
                        }

                        // グラデーションの設定
                        let gradient = Gradient(stops: [
                            .init(color: Color.blue.opacity(1.0), location: 0.0),
                            .init(color: Color.green.opacity(0.7), location: 0.4),
                            .init(color: Color.red.opacity(0.6), location: 0.8),
                            .init(color: Color.black.opacity(0), location: 1.0)
                        ])

                        // 線を描画
                        context.stroke(
                            path,
                            with: .linearGradient(
                                gradient,
                                startPoint: corner,
                                endPoint: targetPoint
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }
                }
                .drawingGroup() // Metalレンダリングエラーを回避するための最適化
            }
        }
    }
}
