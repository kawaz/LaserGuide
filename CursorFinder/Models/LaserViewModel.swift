// LaserViewModel.swift
import SwiftUI
import Combine

class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    @Published var mouseDistance: CGFloat = 0 // Distance from screen center
    
    private var cancellables = Set<AnyCancellable>()
    private var mouseMoveMonitor: Any?
    private var inactivitySubject = PassthroughSubject<Void, Never>()
    private var lastMouseMoveTime: Date = Date()
    private var mousePositionTimer: Timer?
    private let screen: NSScreen
    
    init(screen: NSScreen) {
        self.screen = screen
        setupInactivityPublisher()
        startMousePositionTimer()
    }
    
    private func setupInactivityPublisher() {
        inactivitySubject
            .debounce(for: .seconds(Config.Timing.inactivityThreshold), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let currentTime = Date()
                if currentTime.timeIntervalSince(self.lastMouseMoveTime) >= Config.Timing.inactivityThreshold {
                    self.isVisible = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func startMousePositionTimer() {
        mousePositionTimer = Timer.scheduledTimer(withTimeInterval: Config.Timing.mousePositionUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let location = NSEvent.mouseLocation
            
            if self.currentMouseLocation != location {
                self.lastMouseMoveTime = Date()
                self.isVisible = true
                self.inactivitySubject.send()
            }
            
            // Calculate distance from screen center for visual feedback
            let screenCenter = CGPoint(
                x: self.screen.frame.midX,
                y: self.screen.frame.midY
            )
            let distance = hypot(location.x - screenCenter.x, location.y - screenCenter.y)
            
            DispatchQueue.main.async {
                self.currentMouseLocation = location
                self.mouseDistance = distance
            }
        }
    }
    
    func startTracking() {
        stopTracking()
        
        // Monitor mouse movement
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            self.lastMouseMoveTime = Date()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isVisible = true
                self.inactivitySubject.send()
            }
        }
        
        // Don't set isVisible to true on startup - wait for mouse movement
    }
    
    func stopTracking() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
    }
    
    
    deinit {
        stopTracking()
        mousePositionTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}