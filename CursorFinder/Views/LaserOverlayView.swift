// LaserOverlayView.swift
import SwiftUI

struct LaserOverlayView: View {
    @ObservedObject var viewModel: LaserViewModel
    let screen: NSScreen
    
    var body: some View {
        ZStack {
            if viewModel.isVisible {
                LaserCanvasView(viewModel: viewModel, screen: screen)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}