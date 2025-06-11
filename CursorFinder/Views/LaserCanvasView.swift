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
        
        for corner in corners {
            // Create tapered path (trapezoid/triangle shape)
            let path = Path { p in
                // Calculate perpendicular vector for creating trapezoid width
                let dx = targetPoint.x - corner.x
                let dy = targetPoint.y - corner.y
                let length = hypot(dx, dy)
                
                if length > 0 {
                    // Normalize and create perpendicular vector
                    let perpX = -dy / length
                    let perpY = dx / length
                    
                    // Width at corner (thick) and at target (thin)
                    let cornerWidth: CGFloat = 8.0
                    let targetWidth: CGFloat = 0.5
                    
                    // Create trapezoid points
                    let corner1 = CGPoint(x: corner.x + perpX * cornerWidth, y: corner.y + perpY * cornerWidth)
                    let corner2 = CGPoint(x: corner.x - perpX * cornerWidth, y: corner.y - perpY * cornerWidth)
                    let target1 = CGPoint(x: targetPoint.x + perpX * targetWidth, y: targetPoint.y + perpY * targetWidth)
                    let target2 = CGPoint(x: targetPoint.x - perpX * targetWidth, y: targetPoint.y - perpY * targetWidth)
                    
                    // Draw trapezoid
                    p.move(to: corner1)
                    p.addLine(to: target1)
                    p.addLine(to: target2)
                    p.addLine(to: corner2)
                    p.closeSubpath()
                }
            }
            
            // Create gradient
            let gradient = Gradient(stops: Config.Visual.gradientStops)
            
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: corner,
                    endPoint: targetPoint
                )
            )
        }
    }
}