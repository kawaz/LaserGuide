// LaserCanvasView.swift
import SwiftUI

struct LaserCanvasView: View {
    @ObservedObject var viewModel: LaserViewModel
    let screen: NSScreen
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                
                if Config.Performance.useCoreAnimationLayers {
                    // Use Metal-optimized rendering
                    Canvas { context, size in
                        drawLasers(context: context, size: size)
                    }
                    .drawingGroup() // Metal optimization
                } else {
                    // Fallback to standard rendering
                    Canvas { context, size in
                        drawLasers(context: context, size: size)
                    }
                }
            }
        }
    }
    
    private func drawLasers(context: GraphicsContext, size: CGSize) {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height)
        ]
        
        let globalMouseLocation = viewModel.currentMouseLocation
        
        // Convert to local coordinates
        let localX = globalMouseLocation.x - screen.frame.minX
        let localY = globalMouseLocation.y - screen.frame.minY
        let convertedY = screen.frame.height - localY
        let targetPoint = CGPoint(x: localX, y: convertedY)
        
        // Calculate normalized distance (0-1) for visual feedback
        let maxDistance = hypot(size.width, size.height)
        let normalizedDistance = min(viewModel.mouseDistance / maxDistance, 1.0)
        
        for corner in corners {
            let path = Path { p in
                p.move(to: corner)
                p.addLine(to: targetPoint)
            }
            
            // Create gradient
            let gradient = Gradient(stops: Config.Visual.gradientStops)
            
            // Calculate line width based on distance
            let lineWidth = Config.Visual.minLineWidth + 
                           (Config.Visual.maxLineWidth - Config.Visual.minLineWidth) * (1.0 - normalizedDistance)
            
            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: corner,
                    endPoint: targetPoint
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}