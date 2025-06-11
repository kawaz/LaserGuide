// Config.swift
import SwiftUI

struct Config {
    // MARK: - Visual Settings
    struct Visual {
        static let laserLineWidth: CGFloat = 2.0
        static let laserOpacity: Double = 1.0
        
        // Gradient colors for laser effect
        static let gradientStops: [Gradient.Stop] = [
            .init(color: Color.blue.opacity(1.0), location: 0.0),
            .init(color: Color.green.opacity(0.7), location: 0.4),
            .init(color: Color.red.opacity(0.6), location: 0.8),
            .init(color: Color.black.opacity(0), location: 1.0)
        ]
        
        // Distance-based line width range
        static let minLineWidth: CGFloat = 1.0
        static let maxLineWidth: CGFloat = 8.0
        
        // Drawing optimization
        static let enableMetalOptimization = true
    }
    
    // MARK: - Timing Settings
    struct Timing {
        static let inactivityThreshold: TimeInterval = 0.3
        static let mousePositionUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 FPS
    }
    
    // MARK: - Window Settings
    struct Window {
        // Use screenSaver level to avoid being captured by screenshots
        static let windowLevel: NSWindow.Level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        static let collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }
    
    // MARK: - Performance Settings
    struct Performance {
        // Use Core Animation layers for better GPU utilization
        static let useCoreAnimationLayers = true
        
        // Limit update frequency when mouse is not moving
        static let idleUpdateInterval: TimeInterval = 1.0 / 30.0 // 30 FPS when idle
    }
    
}