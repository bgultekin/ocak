import Metal
import MetalKit
import SwiftUI

/// Metal renderer for the smoke ribbon effect.
/// Manages a CAMetalLayer, render pipeline, and continuous animation loop.
final class SmokeRibbonRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    private var uniformBuffer: MTLBuffer

    // Parameters
    var density: Float = 1.0 { didSet { needsUpdate = true } }
    var turbulenceScale: Float = 1.0 { didSet { needsUpdate = true } }
    var edgeDissipation: Float = 0.5 { didSet { needsUpdate = true } }
    var smokeColor: SIMD4<Float> = SIMD4(0.04, 0.51, 1.0, 0.6) { didSet { needsUpdate = true } }
    var pulseScale: Float = 1.0 { didSet { needsUpdate = true } }

    private var needsUpdate = true
    private let startTime: CFTimeInterval

    private struct Uniforms {
        var time: Float
        var density: Float
        var turbulenceScale: Float
        var edgeDissipation: Float
        var resolution: SIMD2<Float>
        var smokeColor: SIMD4<Float>
        var pulseScale: Float
    }

    init?(metalView: MTKView) {
        guard
            let device = metalView.device,
            let commandQueue = device.makeCommandQueue()
        else { return nil }

        self.device = device
        self.commandQueue = commandQueue
        self.startTime = CACurrentMediaTime()

        // Uniform buffer (one frame's worth)
        let uniformBufferSize = (MemoryLayout<Uniforms>.size + 0xFF) & ~0xFF
        guard let buffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeShared) else {
            return nil
        }
        self.uniformBuffer = buffer

        // Build pipeline — compile shader at runtime for SPM compatibility
        let fragmentFunction: MTLFunction
        if let library = device.makeDefaultLibrary(),
           let fn = library.makeFunction(name: "smokeRibbonFragment") {
            fragmentFunction = fn
        } else if let fn = Self.compileShader(from: device) {
            fragmentFunction = fn
        } else {
            print("[SmokeRibbon] Failed to load Metal shader")
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("[SmokeRibbon] Pipeline creation failed: \(error)")
            return nil
        }

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        // Update uniforms
        let elapsed = Float(CACurrentMediaTime() - startTime)
        let resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))

        let uniforms = Uniforms(
            time: elapsed,
            density: density,
            turbulenceScale: turbulenceScale,
            edgeDissipation: edgeDissipation,
            resolution: resolution,
            smokeColor: smokeColor,
            pulseScale: pulseScale
        )

        let uniformPtr = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformPtr.pointee = uniforms

        // Render
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Runtime shader compilation (SPM fallback)

    private static func compileShader(from device: MTLDevice) -> MTLFunction? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float time;
            float density;
            float turbulenceScale;
            float edgeDissipation;
            float2 resolution;
            float4 smokeColor;
            float pulseScale;
        };

        float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float4 permute(float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
        float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

        float snoise(float3 v) {
            const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
            const float4 D = float4(0.0, 0.5, 1.0, 2.0);
            float3 i = floor(v + dot(v, C.yyy));
            float3 x0 = v - i + dot(i, C.xxx);
            float3 g = step(x0.yzx, x0.xyz);
            float3 l = 1.0 - g;
            float3 i1 = min(g.xyz, l.zxy);
            float3 i2 = max(g.xyz, l.zxy);
            float3 x1 = x0 - i1 + C.xxx;
            float3 x2 = x0 - i2 + C.yyy;
            float3 x3 = x0 - D.yyy;
            i = mod289(i);
            float4 p = permute(permute(permute(
                i.z + float4(0.0, i1.z, i2.z, 1.0))
              + i.y + float4(0.0, i1.y, i2.y, 1.0))
              + i.x + float4(0.0, i1.x, i2.x, 1.0));
            float n_ = 0.142857142857;
            float3 ns = n_ * D.wyz - D.xzx;
            float4 j = p - 49.0 * floor(p * ns.z * ns.z);
            float4 x_ = floor(j * ns.z);
            float4 y_ = floor(j - 7.0 * x_);
            float4 x = x_ * ns.x + ns.yyyy;
            float4 y = y_ * ns.x + ns.yyyy;
            float4 h = 1.0 - abs(x) - abs(y);
            float4 b0 = float4(x.xy, y.xy);
            float4 b1 = float4(x.zw, y.zw);
            float4 s0 = floor(b0) * 2.0 + 1.0;
            float4 s1 = floor(b1) * 2.0 + 1.0;
            float4 sh = -step(h, float4(0.0));
            float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
            float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
            float3 p0 = float3(a0.xy, h.x);
            float3 p1 = float3(a0.zw, h.y);
            float3 p2 = float3(a1.xy, h.z);
            float3 p3 = float3(a1.zw, h.w);
            float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
            p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
            float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
            m = m * m;
            return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
        }

        float fbm(float3 p, int octaves, float lacunarity, float gain) {
            float sum = 0.0;
            float amp = 0.5;
            float freq = 1.0;
            for (int i = 0; i < octaves; i++) {
                sum += amp * snoise(p * freq);
                freq *= lacunarity;
                amp *= gain;
            }
            return sum;
        }

        fragment float4 smokeRibbonFragment(
            float4 position [[position]],
            constant Uniforms& u [[buffer(0)]]
        ) {
            float2 uv = position.xy / u.resolution;
            float2 aspect = float2(u.resolution.x / u.resolution.y, 1.0);
            float2 p = (uv - 0.5) * aspect * u.pulseScale;

            float timeBase = u.time * 0.15;
            float timeOffset = sin(u.time * 0.07) * 1.3;
            float flowY = p.y + timeBase + timeOffset;

            float swirlFreq = u.turbulenceScale * 0.6;
            float swirl = snoise(float3(p.x * swirlFreq + timeBase * 0.3, flowY * 0.8, u.time * 0.05));
            float2 swirlUV = float2(p.x + swirl * 0.15, flowY);

            float3 fbmCoord = float3(swirlUV * u.turbulenceScale * 2.0, u.time * 0.08);

            float n1 = fbm(fbmCoord, 6, 2.0, 0.5);
            float n2 = fbm(fbmCoord + float3(5.2, 1.3, sin(u.time * 0.11) * 0.7), 5, 2.1, 0.48);
            float n3 = fbm(fbmCoord + float3(n1 * 0.5, n2 * 0.5, u.time * 0.13), 4, 2.2, 0.45);

            float turbulence = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

            float warpStrength = 0.35 * u.turbulenceScale;
            float2 warp = float2(
                fbm(fbmCoord + float3(1.7, 9.2, u.time * 0.09), 4, 2.0, 0.5),
                fbm(fbmCoord + float3(8.3, 2.8, u.time * 0.12), 4, 2.0, 0.5)
            );

            float3 warpedCoord = float3(swirlUV * u.turbulenceScale * 2.0 + warp * warpStrength, u.time * 0.1);
            float detail = fbm(warpedCoord, 5, 2.1, 0.47);

            float smoke = turbulence * 0.55 + detail * 0.45;
            smoke = smoke * 0.5 + 0.5;
            smoke = pow(smoke, 1.5 / u.density);

            float edgeFade = 1.0 - smoothstep(0.0, u.edgeDissipation, uv.x);
            edgeFade = pow(edgeFade, 0.8);

            float vCenter = abs(uv.y - 0.5) * 2.0;
            float vFade = 1.0 - smoothstep(0.3, 1.0, vCenter);
            vFade = smoothstep(0.0, 0.15, vFade);

            float alpha = smoke * edgeFade * vFade;
            alpha = clamp(alpha, 0.0, 1.0);

            float edgeGlow = edgeFade * 0.3 + 0.7;
            float3 color = u.smokeColor.rgb * edgeGlow;

            return float4(color, alpha * u.smokeColor.a);
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            return library.makeFunction(name: "smokeRibbonFragment")
        } catch {
            print("[SmokeRibbon] Runtime shader compilation failed: \(error)")
            return nil
        }
    }
}
