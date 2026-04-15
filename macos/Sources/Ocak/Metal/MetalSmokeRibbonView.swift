import SwiftUI
import MetalKit

/// SwiftUI wrapper that hosts the Metal smoke ribbon renderer.
struct MetalSmokeRibbonView: NSViewRepresentable {
    let density: Float
    let turbulenceScale: Float
    let edgeDissipation: Float
    let smokeColor: Color
    let pulseScale: Float

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        if let renderer = SmokeRibbonRenderer(metalView: mtkView) {
            renderer.density = density
            renderer.turbulenceScale = turbulenceScale
            renderer.edgeDissipation = edgeDissipation
            renderer.pulseScale = pulseScale

            let nsColor = NSColor(smokeColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            renderer.smokeColor = SIMD4(Float(r), Float(g), Float(b), Float(a))

            mtkView.delegate = renderer
            context.coordinator.renderer = renderer
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.density = density
        renderer.turbulenceScale = turbulenceScale
        renderer.edgeDissipation = edgeDissipation
        renderer.pulseScale = pulseScale

        let nsColor = NSColor(smokeColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        renderer.smokeColor = SIMD4(Float(r), Float(g), Float(b), Float(a))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var renderer: SmokeRibbonRenderer?
    }
}
