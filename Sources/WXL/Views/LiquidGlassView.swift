//
//  LiquidGlassView.swift
//  WXL
//
//  Liquid Glass visual effects for macOS
//

import SwiftUI

// MARK: - Liquid Glass Container
struct LiquidGlassContainer<Content: View>: View {
    var content: Content
    @AppStorage("glassOpacity") private var glassOpacity: Double = 0.85

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(glassOpacity)
            )
            .background(
                // 玻璃光泽效果
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15 * glassOpacity),
                        Color.white.opacity(0.05 * glassOpacity),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                // 边框光泽
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3 * glassOpacity),
                                Color.white.opacity(0.1 * glassOpacity),
                                Color.white.opacity(0.05 * glassOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
