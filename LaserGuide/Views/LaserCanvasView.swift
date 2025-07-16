// LaserCanvasView.swift
import SwiftUI

struct LaserCanvasView: View {
    @ObservedObject var viewModel: LaserViewModel
    let screen: NSScreen
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                
                // Always use Metal-optimized rendering
                Canvas { context, size in
                    drawLasers(context: context, size: size)
                }
                .drawingGroup(opaque: false, colorMode: .nonLinear) // Enhanced Metal optimization
                
                // Distance indicators for off-screen cursor
                let indicators = getDistanceIndicators(size: geometry.size)
                ForEach(indicators, id: \.corner) { indicator in
                    Text("\(Int(indicator.percentage))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                        .position(indicator.position)
                        .drawingGroup() // GPU render text too
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
                let intersection = calculateScreenEdgeIntersection(from: corner, target: targetPoint, screenSize: size)
                
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
    
    private func calculateScreenEdgeIntersection(from: CGPoint, target: CGPoint, screenSize: CGSize) -> CGPoint? {
        let deltaX = target.x - from.x
        let deltaY = target.y - from.y
        
        // If no movement, return nil
        if deltaX == 0 && deltaY == 0 {
            return nil
        }
        
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1
        
        // Check intersection with each edge
        // Left edge (x = 0)
        if deltaX != 0 {
            let t1 = (0 - from.x) / deltaX
            let t2 = (screenSize.width - from.x) / deltaX
            
            tMin = max(tMin, min(t1, t2))
            tMax = min(tMax, max(t1, t2))
        }
        
        // Top/bottom edges (y = 0 or height)
        if deltaY != 0 {
            let t1 = (0 - from.y) / deltaY
            let t2 = (screenSize.height - from.y) / deltaY
            
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
                x: from.x + deltaX * tMax,
                y: from.y + deltaY * tMax
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
        
        // Pre-create gradient for reuse
        let gradient = Gradient(stops: Config.Visual.gradientStops)
        
        // Batch draw all lasers
        for corner in corners {
            // Skip if target is too close to corner (optimization)
            let deltaX = targetPoint.x - corner.x
            let deltaY = targetPoint.y - corner.y
            let length = hypot(deltaX, deltaY)
            
            guard length > 1.0 else { continue }
            
            // Create tapered path efficiently
            let path = createLaserPath(from: corner, to: targetPoint, distance: length, deltaX: deltaX, deltaY: deltaY)
            
            // Apply gradient fill
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
    
    @inline(__always)
    private func createLaserPath(from corner: CGPoint, to target: CGPoint, distance: CGFloat, deltaX: CGFloat, deltaY: CGFloat) -> Path {
        Path { pathBuilder in
            // Normalize and create perpendicular vector
            let perpX = -deltaY / distance
            let perpY = deltaX / distance
            
            // Width at corner (thick) and at target (thin)
            let cornerWidth: CGFloat = 8.0
            let targetWidth: CGFloat = 0.5
            
            // Create trapezoid points
            let corner1 = CGPoint(x: corner.x + perpX * cornerWidth, y: corner.y + perpY * cornerWidth)
            let corner2 = CGPoint(x: corner.x - perpX * cornerWidth, y: corner.y - perpY * cornerWidth)
            let target1 = CGPoint(x: target.x + perpX * targetWidth, y: target.y + perpY * targetWidth)
            let target2 = CGPoint(x: target.x - perpX * targetWidth, y: target.y - perpY * targetWidth)
            
            // Draw trapezoid
            pathBuilder.move(to: corner1)
            pathBuilder.addLine(to: target1)
            pathBuilder.addLine(to: target2)
            pathBuilder.addLine(to: corner2)
            pathBuilder.closeSubpath()
        }
    }
}