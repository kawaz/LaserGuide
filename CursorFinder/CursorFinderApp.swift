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
        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
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
        
        // グローバルマウスイベントモニターを設定
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }
            
            let globalLocation = NSEvent.mouseLocation
            
            // ウィンドウがあれば座標変換を行う
            if let window = event.window {
                let windowLocation = window.convertPoint(fromScreen: globalLocation)
                
                DispatchQueue.main.async {
                    self.updateMouseLocation(windowLocation)
                }
            } else {
                // ウィンドウがない場合はグローバル座標を使用
                DispatchQueue.main.async {
                    self.updateMouseLocation(globalLocation)
                }
            }
        }
        
        // 初期状態を設定
        isVisible = true
    }
    
    func updateMouseLocation(_ newLocation: CGPoint) {
        if mouseLocation != newLocation {
            mouseLocation = newLocation
            isVisible = true
            inactivitySubject.send()
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
            if viewModel.isVisible {
                LaserCanvasView(mouseLocation: viewModel.mouseLocation)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct LaserCanvasView: View {
    let mouseLocation: CGPoint
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // ビューの四隅の座標
                let corners = [
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: size.width, y: 0),
                    CGPoint(x: 0, y: size.height),
                    CGPoint(x: size.width, y: size.height)
                ]
                
                // 各コーナーからマウス位置へのレーザー線を描画
                for corner in corners {
                    let path = Path { p in
                        p.move(to: corner)
                        p.addLine(to: mouseLocation)
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
                            endPoint: mouseLocation
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    
                    // グローエフェクトを追加
                    context.addFilter(.blur(radius: 2))
                }
            }
        }
    }
}
