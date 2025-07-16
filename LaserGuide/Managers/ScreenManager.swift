// ScreenManager.swift
import SwiftUI

class ScreenManager: ObservableObject {
    @Published var overlayWindows: [NSWindow] = []
    
    init() {
        setupOverlays()
    }
    
    func setupOverlays() {
        removeOverlays()
        
        for screen in NSScreen.screens {
            let viewModel = LaserViewModel(screen: screen)
            let hostingController = NSHostingController(
                rootView: LaserOverlayView(viewModel: viewModel, screen: screen)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )
            
            let window = createOverlayWindow(for: screen)
            window.contentView = hostingController.view
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)
            
            viewModel.startTracking()
            overlayWindows.append(window)
        }
    }
    
    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = Config.Window.windowLevel
        window.collectionBehavior = Config.Window.collectionBehavior
        window.ignoresMouseEvents = true
        window.hasShadow = false
        
        // Exclude from screenshots by setting sharing type
        window.sharingType = .none
        
        // Enable Core Animation layer for better GPU performance
        if Config.Performance.useCoreAnimationLayers {
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.isOpaque = false
        }
        
        return window
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
