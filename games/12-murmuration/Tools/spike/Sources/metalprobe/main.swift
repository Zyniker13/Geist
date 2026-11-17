// MU-P0.1 spike: Metal instanced rendering probe on Mac.
//
// Creates a small borderless window with an MTKView, draws 4,000 instanced quads,
// counts frames for ~2 seconds, and prints the measured frame rate.

import AppKit
import MetalKit

private let instanceCount = 4000

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VOut {
    float4 position [[position]];
    uint iid [[user(locn0)]];
};

vertex VOut quadVertex(uint vid [[vertex_id]],
                       uint iid [[instance_id]],
                       constant float2 *centers [[buffer(0)]],
                       constant float2 &scale [[buffer(1)]]) {
    float2 corners[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
    float2 corner = corners[vid & 3];
    float2 p = centers[iid] + corner * scale;
    VOut out;
    out.position = float4(p, 0.0, 1.0);
    out.iid = iid;
    return out;
}

fragment float4 quadFragment(VOut in [[stage_in]]) {
    float tint = float(in.iid % 64u) / 64.0;
    return float4(0.11 + tint * 0.08, 0.10, 0.13, 1.0);
}
"""

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let centers: MTLBuffer
    var frameCount = 0

    init?(mtkView: MTKView) {
        guard let device = mtkView.device else {
            print("metalprobe: view has no device")
            return nil
        }
        guard let queue = device.makeCommandQueue() else {
            print("metalprobe: no command queue")
            return nil
        }
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("metalprobe: shader compile failed: \(error)")
            return nil
        }
        guard let vertex = library.makeFunction(name: "quadVertex"),
              let fragment = library.makeFunction(name: "quadFragment") else {
            print("metalprobe: entry points missing")
            return nil
        }
        self.device = device
        self.commandQueue = queue
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            print("metalprobe: pipeline creation failed")
            return nil
        }
        self.pipeline = pipeline

        var centersData: [Float] = []
        centersData.reserveCapacity(instanceCount * 2)
        var state: UInt64 = 0x9E3779B97F4A7C15
        func nextFloat() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 33) & 0xFFFFFF) / Float(0xFFFFFF) * 2.0 - 1.0
        }
        for _ in 0..<instanceCount {
            centersData.append(nextFloat() * 0.9)
            centersData.append(nextFloat() * 0.9)
        }
        self.centers = device.makeBuffer(bytes: centersData, length: MemoryLayout<Float>.stride * centersData.count, options: .storageModeShared)!
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(centers, offset: 0, index: 0)
        var scale: [Float] = [6.0 / Float(view.drawableSize.width) * 2.0, 6.0 / Float(view.drawableSize.height) * 2.0]
        encoder.setVertexBytes(&scale, length: MemoryLayout<Float>.stride * 2, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        frameCount += 1
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard let device = MTLCreateSystemDefaultDevice() else {
    print("metalprobe: no Metal device available")
    exit(1)
}

let frame = NSRect(x: 0, y: 0, width: 16, height: 16)
let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
let view = MTKView(frame: frame, device: device)
view.preferredFramesPerSecond = 120
view.enableSetNeedsDisplay = false
view.isPaused = false
window.contentView = view
window.orderFrontRegardless()

guard let renderer = Renderer(mtkView: view) else {
    print("metalprobe: renderer init failed")
    exit(1)
}
view.delegate = renderer

let runSeconds = 2.0
let deadline = Date().addingTimeInterval(runSeconds)
while Date() < deadline {
    // NSApplication has no run-until API on this SDK; pump the run loop in
    // 50 ms slices so MTKView's display link drives the draw calls.
    RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
let elapsed = runSeconds
let fps = Double(renderer.frameCount) / elapsed
print(String(format: "metalprobe: instances=%d frames=%d elapsed=%.2fs fps=%.1f", instanceCount, renderer.frameCount, elapsed, fps))
exit(0)
