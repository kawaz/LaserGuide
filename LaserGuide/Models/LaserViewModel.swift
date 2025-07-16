// LaserViewModel.swift
import SwiftUI
import Combine

class LaserViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    
    private var mouseMoveMonitor: Any?
    private var hideTimer: Timer?
    private let screen: NSScreen
    
    init(screen: NSScreen) {
        self.screen = screen
    }
    
    private func scheduleHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Config.Timing.inactivityThreshold, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isVisible = false
            }
        }
    }
    
    func startTracking() {
        stopTracking()
        
        // Monitor mouse movement for immediate response
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            
            let location = NSEvent.mouseLocation
            
            DispatchQueue.main.async {
                self.currentMouseLocation = location
                self.isVisible = true
                self.scheduleHideTimer()
            }
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
        hideTimer?.invalidate()
    }
}