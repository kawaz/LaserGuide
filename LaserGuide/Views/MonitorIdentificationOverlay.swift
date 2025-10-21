// MonitorIdentificationOverlay.swift
import SwiftUI
import Cocoa

/// Displays a brief identification flash on a specific monitor
class MonitorIdentificationOverlay {
    static let shared = MonitorIdentificationOverlay()

    private init() {}

    /// Flash identification number and border on specified screen
    /// - Parameters:
    ///   - screen: Target NSScreen to display overlay
    ///   - number: Display number to show
    ///   - duration: Duration in seconds (default: 2.0)
    func flash(on screen: NSScreen, number: Int, duration: TimeInterval = 2.0) {
        // Create overlay window for this screen
        let window = createOverlayWindow(for: screen, number: number)

        // Show window
        window.orderFrontRegardless()

        // Animate fade in and fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }, completionHandler: {
            // Wait, then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.6) { [weak window] in
                guard let window = window else { return }

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0.0
                }, completionHandler: { [weak window] in
                    // Close window
                    window?.close()
                })
            }
        })
    }

    private func createOverlayWindow(for screen: NSScreen, number: Int) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.alphaValue = 0.0  // Start invisible

        // Create SwiftUI view with number and border
        let contentView = IdentificationView(number: number)
        window.contentView = NSHostingView(rootView: contentView)

        return window
    }
}

/// SwiftUI view showing monitor number and border
struct IdentificationView: View {
    let number: Int

    var body: some View {
        ZStack {
            // Border glow
            Rectangle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Center number
            Text("\(number)")
                .font(.system(size: 200, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 0)
        }
        .background(Color.black.opacity(0.05))
    }
}
