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
                
                // Distance indicators for off-screen cursor
                ForEach(getDistanceIndicators(size: geometry.size), id: \.corner) { indicator in
                    Text("\(Int(indicator.percentage))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                        .position(indicator.position)
                }
            }
        }
    }
    
    struct DistanceIndicator {
        let corner: CGPoint
        let position: CGPoint
        let percentage: Double
    }
    
    private func getDistanceIndicators(size: CGSize) -> [DistanceIndicator] {
        var indicators: [DistanceIndicator] = []
        
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
        
        // Check if cursor is outside screen bounds
        if targetPoint.x < 0 || targetPoint.x > size.width || targetPoint.y < 0 || targetPoint.y > size.height {
            for corner in corners {
                // Calculate intersection point with screen edge
                let intersection = calculateScreenEdgeIntersection(from: corner, to: targetPoint, screenSize: size)
                
                if let intersectionPoint = intersection {
                    // Calculate distance from intersection to actual cursor position
                    let intersectionDistance = hypot(targetPoint.x - intersectionPoint.x, targetPoint.y - intersectionPoint.y)
                    let visibleDistance = hypot(intersectionPoint.x - corner.x, intersectionPoint.y - corner.y)
                    
                    // Calculate percentage (visible distance vs remaining distance)
                    let percentage = (intersectionDistance / visibleDistance) * 100
                    
                    // Position text slightly inside the screen from intersection point
                    let offset: CGFloat = 30
                    var textPosition = intersectionPoint
                    
                    // Adjust position based on which edge
                    if intersectionPoint.x <= 0 {
                        textPosition.x = offset
                    } else if intersectionPoint.x >= size.width {
                        textPosition.x = size.width - offset
                    }
                    
                    if intersectionPoint.y <= 0 {
                        textPosition.y = offset
                    } else if intersectionPoint.y >= size.height {
                        textPosition.y = size.height - offset
                    }
                    
                    indicators.append(DistanceIndicator(
                        corner: corner,
                        position: textPosition,
                        percentage: min(percentage, 999) // Cap at 999%
                    ))
                }
            }
        }
        
        return indicators
    }
    
    private func calculateScreenEdgeIntersection(from: CGPoint, to: CGPoint, screenSize: CGSize) -> CGPoint? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        
        // If no movement, return nil
        if dx == 0 && dy == 0 {
            return nil
        }
        
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1
        
        // Check intersection with each edge
        // Left edge (x = 0)
        if dx != 0 {
            let t1 = (0 - from.x) / dx
            let t2 = (screenSize.width - from.x) / dx
            
            tMin = max(tMin, min(t1, t2))
            tMax = min(tMax, max(t1, t2))
        }
        
        // Top/bottom edges (y = 0 or height)
        if dy != 0 {
            let t1 = (0 - from.y) / dy
            let t2 = (screenSize.height - from.y) / dy
            
            tMin = max(tMin, min(t1, t2))
            tMax = min(tMax, max(t1, t2))
        }
        
        // If tMin > tMax, no intersection
        if tMin > tMax {
            return nil
        }
        
        // Use tMax for the intersection point (where line exits the screen)
        if tMax >= 0 && tMax <= 1 {
            return CGPoint(
                x: from.x + dx * tMax,
                y: from.y + dy * tMax
            )
        }
        
        return nil
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