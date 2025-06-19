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
    
    // Performance optimization properties
    private var lastUpdateLocation: CGPoint = .zero
    private var isActivelyMoving: Bool = false
    private var updateInterval: TimeInterval = 1.0 / 30.0 // Start with 30 FPS
    
    init(screen: NSScreen) {
        self.screen = screen
        setupInactivityPublisher()
        startAdaptiveMouseTracking()
    }
    
    private func setupInactivityPublisher() {
        inactivitySubject
            .debounce(for: .seconds(Config.Timing.inactivityThreshold), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let currentTime = Date()
                if currentTime.timeIntervalSince(self.lastMouseMoveTime) >= Config.Timing.inactivityThreshold {
                    self.isVisible = false
                    self.isActivelyMoving = false
                    // Reset to lower frame rate when idle
                    self.updateInterval = 1.0 / 30.0
                }
            }
            .store(in: &cancellables)
    }
    
    private func startAdaptiveMouseTracking() {
        // Use a single timer with adaptive interval
        scheduleNextUpdate()
    }
    
    private func scheduleNextUpdate() {
        mousePositionTimer?.invalidate()
        
        mousePositionTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            let location = NSEvent.mouseLocation
            let movementDelta = hypot(location.x - self.lastUpdateLocation.x, 
                                    location.y - self.lastUpdateLocation.y)
            
            // Adaptive frame rate based on movement
            if movementDelta > 10.0 {
                // Fast movement - increase to 120 FPS
                self.updateInterval = 1.0 / 120.0
                self.isActivelyMoving = true
            } else if movementDelta > 0.5 {
                // Normal movement - 60 FPS
                self.updateInterval = 1.0 / 60.0
                self.isActivelyMoving = true
            } else {
                // Minimal or no movement - reduce to 30 FPS
                self.updateInterval = 1.0 / 30.0
                self.isActivelyMoving = false
            }
            
            // Only update if position changed significantly
            if movementDelta > 0.1 || self.currentMouseLocation == .zero {
                if self.currentMouseLocation != location {
                    self.lastMouseMoveTime = Date()
                    self.isVisible = true
                    self.inactivitySubject.send()
                }
                
                // Calculate distance from screen center
                let screenCenter = CGPoint(
                    x: self.screen.frame.midX,
                    y: self.screen.frame.midY
                )
                let distance = hypot(location.x - screenCenter.x, location.y - screenCenter.y)
                
                // Update on main thread only if needed
                if abs(self.currentMouseLocation.x - location.x) > 0.5 ||
                   abs(self.currentMouseLocation.y - location.y) > 0.5 {
                    DispatchQueue.main.async {
                        self.currentMouseLocation = location
                        self.mouseDistance = distance
                    }
                }
                
                self.lastUpdateLocation = location
            }
            
            // Schedule next update
            self.scheduleNextUpdate()
        }
    }
    
    func startTracking() {
        stopTracking()
        
        // Monitor mouse movement for immediate response
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            self.lastMouseMoveTime = Date()
            
            // Immediately show laser on movement
            if !self.isVisible {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isVisible = true
                    self.inactivitySubject.send()
                }
            }
            
            // Boost update rate on movement
            if !self.isActivelyMoving {
                self.isActivelyMoving = true
                self.updateInterval = 1.0 / 120.0
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