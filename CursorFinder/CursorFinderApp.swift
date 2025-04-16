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
                rootView: LaserOverlayView(viewModel: viewModel)
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
    @Published var mouseLocation: CGPoint = .zero
    @Published var isVisible: Bool = true
    @Published var currentScreen: NSScreen?

    private var cancellables = Set<AnyCancellable>()
    private var mouseMoveMonitor: Any?
    private var lastMouseLocation: CGPoint = .zero
    private var inactivitySubject = PassthroughSubject<Void, Never>()
    private let inactivityThreshold: TimeInterval = 2.0

    init() {
        setupInactivityPublisher()
    }

    private func setupInactivityPublisher() {
        inactivitySubject
            .debounce(for: .seconds(inactivityThreshold), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isVisible = false
            }
            .store(in: &cancellables)
    }

    func startTracking() {
        stopTracking()

        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }

            let globalLocation = NSEvent.mouseLocation

            // マウスがあるスクリーンを特定
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(globalLocation) }) {
                let screenLocation = CGPoint(
                    x: globalLocation.x - screen.frame.origin.x,
                    y: screen.frame.height - (globalLocation.y - screen.frame.origin.y)
                )

                // UIの更新はメインスレッドで行う
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentScreen = screen
                    self.updateMouseLocationInternal(screenLocation)
                }
            }
        }

        // UI更新はメインスレッドで行う
        DispatchQueue.main.async { [weak self] in
            self?.isVisible = true
        }
    }

    // 内部での使用のみのメソッド
    private func updateMouseLocationInternal(_ newLocation: CGPoint) {
        if mouseLocation != newLocation {
            mouseLocation = newLocation
            isVisible = true
            inactivitySubject.send()
        }
    }

    // 外部から呼ばれる可能性のあるメソッド
    func updateMouseLocation(_ newLocation: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            self?.updateMouseLocationInternal(newLocation)
        }
    }

    func stopTracking() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
    }

    deinit {
        stopTracking()
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }
}

// MARK: - Views
struct LaserOverlayView: View {
    @ObservedObject var viewModel: LaserViewModel

    var body: some View {
        ZStack {
            if viewModel.isVisible, let currentScreen = viewModel.currentScreen {
                LaserCanvasView(viewModel: viewModel, screen: currentScreen)
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

                    // マウスがこの画面にあるかどうかを判断
                    let isMouseInThisScreen = viewModel.currentScreen == screen

                    // 各コーナーからマウス位置へのレーザー線を描画
                    for corner in corners {
                        let targetPoint: CGPoint

                        if isMouseInThisScreen {
                            // マウスがこの画面にある場合は、マウス位置に向けてレーザーを表示
                            targetPoint = viewModel.mouseLocation
                        } else {
                            // マウスがこの画面にない場合は、画面の境界上の最も近い点に向けてレーザーを表示
                            let globalMouseLocation = NSEvent.mouseLocation
                            let screenFrame = screen.frame

                            // 画面の境界上の最も近い点を計算
                            let closestPoint = CGPoint(
                                x: max(screenFrame.minX, min(globalMouseLocation.x, screenFrame.maxX)),
                                y: max(screenFrame.minY, min(globalMouseLocation.y, screenFrame.maxY))
                            )

                            // ローカル座標系に変換
                            targetPoint = CGPoint(
                                x: closestPoint.x - screenFrame.origin.x,
                                y: screenFrame.height - (closestPoint.y - screenFrame.origin.y)
                            )
                        }

                        let path = Path { p in
                            p.move(to: corner)
                            p.addLine(to: targetPoint)
                        }

                        // グラデーションの設定
                        let gradient = Gradient(stops: [
                            .init(color: Color.red.opacity(0.7), location: 0),
                            .init(color: Color.red.opacity(0.4), location: 0.8),
                            .init(color: Color.red.opacity(0), location: 1.0)
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
