// Murmuration Render — the Metal flock renderer (MU-P2.1).
//
// Draws, in order: the dusk sky gradient, three hill silhouette layers,
// feeding fields, roosts with their claim fills, the fading leader trace,
// and the birds (instanced oriented quads, GPU-interpolated between ticks,
// with falcons drawn through the same pipeline).
//
// The game model calls `update(_:)` once per 30 Hz tick and MetalKit calls
// `draw(in:)` per display frame; positions blend between the last two ticks
// so bird motion stays smooth at 60/120 fps.

import Foundation
import Metal
import MetalKit
import QuartzCore
import MUCore
import MUContent

/// Shader mirror of `BirdInstance` in Shaders.metal (stride 32).
struct BirdInstance {
    var prevX: Float = 0
    var prevY: Float = 0
    var curX: Float = 0
    var curY: Float = 0
    var velX: Float = 0
    var velY: Float = 0
    var size: Float = 0
    var colorIdx: Float = 0
    /// Wingbeat phase (radians at the scene's tick; the shader advances it
    /// through the frame's interpolation fraction). Zero for falcons.
    var phase: Float = 0
    /// Layout pad: Metal rounds a struct containing float2 to 8-byte
    /// alignment (sizeof 40); mirror it so the buffers line up.
    var metalPad: Float = 0
}

/// Shader mirror of `DiskInstance` in Shaders.metal (stride 32).
struct DiskInstance {
    var centerX: Float = 0
    var centerY: Float = 0
    var radius: Float = 0
    var pad: Float = 0
    var color: SIMD4<Float> = .zero
}

/// Shader mirror of `TraceVertex` in Shaders.metal (stride 16).
struct TraceVertex {
    var pos: SIMD2<Float> = .zero
    var age: Float = 0
}

/// Shader mirror of `HillVertex` in Shaders.metal (stride 32).
struct HillVertex: Equatable {
    var pos: SIMD2<Float> = .zero
    var color: SIMD4<Float> = .zero
}

/// The palette-derived colors the draw loop needs.
private struct PaletteData {
    var skyStops: [SIMD4<Float>]
    var birdColors: [SIMD4<Float>]
    var fieldOchre: SIMD4<Float>
    var fieldGreen: SIMD4<Float>
    var claimPlayer: SIMD4<Float>
    var claimRival: SIMD4<Float>
}

/// One render pipeline's configuration, so `pipeline` stays within the
/// five-parameter lint limit.
private struct PipelineSpec {
    var vertex: String
    var fragment: String
    var blend: Bool
}

/// The Metal renderer for a Murmuration day.
public final class FlockRenderer: NSObject, MTKViewDelegate {
    /// World extent this renderer maps to the view (letterboxed).
    public let worldSize: SIMD2<Float>
    /// Seconds one simulation tick represents (interpolation window).
    public let tickInterval: Double

    private let commandQueue: MTLCommandQueue
    private let skyPipeline: MTLRenderPipelineState
    private let hillPipeline: MTLRenderPipelineState
    private let diskPipeline: MTLRenderPipelineState
    private let birdPipeline: MTLRenderPipelineState
    private let tracePipeline: MTLRenderPipelineState

    private let unitDisk: MTLBuffer
    private let hillBuffer: MTLBuffer
    private var hillRanges: [(offset: Int, count: Int)] = []
    private let birdBuffer: MTLBuffer
    private let birdCapacity: Int

    private var paletteData: PaletteData

    private var birdInstanceCount = 0
    private var diskInstances: [DiskInstance] = []
    private var traceVertices: [TraceVertex] = []
    private var pendingVertices: [TraceVertex] = []
    private var duskBlend: Float = 0

    private var lastTickTime: Double = 0
    private var sawTick = false
    private var instantNextDraw = false

    /// Player flock body size in world units.
    private let birdSize: Float = 6.0
    /// Falcon body size in world units.
    private let falconSize: Float = 26.0

    // MARK: Accessibility render options (MU-P8.1)

    /// Reduce Motion: render every Nth bird (1 = all birds). Deterministic
    /// stride over the instance order, so a stride of k draws birds
    /// 0, k, 2k, … — a stable subset, not a flickering random sample.
    /// The engine keeps the full flock; only the draw decimates.
    public var birdStride: Int = 1
    /// Reduce Motion, flutter leg: snap every frame to the settled tick
    /// position instead of blending between ticks (whole-flock glide is
    /// the vestibular trigger; per-bird wingbeat scale is not).
    public var reducesFlutter: Bool = false
    /// High-contrast rival patterning: when true, the rival's birds render
    /// in a strongly separated magenta against the ink player flock (and
    /// the leader traces tint to match), so the two flocks are distinguishable
    /// at a glance and under color-vision deficiency.
    public var highContrastRival: Bool = false {
        didSet {
            if highContrastRival != oldValue {
                paletteData = Self.paletteData(Self.activePalette(base, highContrastRival))
            }
        }
    }
    /// The palette the options derive from (kept so high-contrast can
    /// re-derive when toggled).
    private var base: RegionPalette

    /// Creates the renderer for `mtkView`. Throws when Metal is unavailable
    /// or the shader library fails to build.
    public init(
        mtkView: MTKView,
        palette: RegionPalette,
        worldSize: SIMD2<Float>,
        tickInterval: Double = 1.0 / 30.0,
        hillSeed: UInt64 = 1
    ) throws {
        guard let device = mtkView.device else {
            throw RenderError.missingDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RenderError.missingCommandQueue
        }
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: ShaderSource.metal, options: nil)
        } catch {
            throw RenderError.shaderLibrary(error)
        }

        self.worldSize = worldSize
        self.tickInterval = tickInterval
        self.commandQueue = queue
        self.base = palette
        paletteData = Self.paletteData(Self.activePalette(palette, highContrastRival))

        self.skyPipeline = try Self.pipeline(
            device: device, library: library, view: mtkView,
            spec: PipelineSpec(vertex: "skyVertex", fragment: "skyFragment", blend: false)
        )
        self.hillPipeline = try Self.pipeline(
            device: device, library: library, view: mtkView,
            spec: PipelineSpec(vertex: "hillVertex", fragment: "solidFragment", blend: false)
        )
        self.diskPipeline = try Self.pipeline(
            device: device, library: library, view: mtkView,
            spec: PipelineSpec(vertex: "diskVertex", fragment: "diskFragment", blend: true)
        )
        self.birdPipeline = try Self.pipeline(
            device: device, library: library, view: mtkView,
            spec: PipelineSpec(vertex: "birdVertex", fragment: "birdFragment", blend: false)
        )
        self.tracePipeline = try Self.pipeline(
            device: device, library: library, view: mtkView,
            spec: PipelineSpec(vertex: "traceVertex", fragment: "traceFragment", blend: true)
        )

        // Unit disk as explicit triangles: 32 segments, 96 vertices.
        var disk: [SIMD2<Float>] = []
        disk.reserveCapacity(96)
        for i in 0..<32 {
            let a0 = Float(i) / 32 * 2 * Float.pi
            let a1 = Float(i + 1) / 32 * 2 * Float.pi
            disk.append(.zero)
            disk.append(SIMD2(cos(a0), sin(a0)))
            disk.append(SIMD2(cos(a1), sin(a1)))
        }
        guard let unitDiskBuffer = device.makeBuffer(
            bytes: disk,
            length: MemoryLayout<SIMD2<Float>>.stride * disk.count,
            options: .storageModeShared
        ) else {
            throw RenderError.bufferAllocation
        }
        self.unitDisk = unitDiskBuffer

        let hills = Self.hillLayers(palette: palette, worldSize: worldSize, seed: hillSeed)
        guard let hillVerts = device.makeBuffer(
            bytes: hills.vertices,
            length: MemoryLayout<HillVertex>.stride * hills.vertices.count,
            options: .storageModeShared
        ) else {
            throw RenderError.bufferAllocation
        }
        self.hillBuffer = hillVerts
        self.hillRanges = hills.ranges

        self.birdCapacity = 6400
        guard let birdBuf = device.makeBuffer(
            length: MemoryLayout<BirdInstance>.stride * birdCapacity,
            options: .storageModeShared
        ) else {
            throw RenderError.bufferAllocation
        }
        self.birdBuffer = birdBuf
        super.init()
    }

    /// Install a region palette (sky stops, hill colors, bird colors).
    public func setPalette(_ palette: RegionPalette) {
        base = palette
        paletteData = Self.paletteData(Self.activePalette(palette, highContrastRival))
    }

    /// The palette the renderer actually draws with: the region's palette,
    /// or the high-contrast variant (MU-P8.1) — the rival's sepia moves to a
    /// saturated magenta (large ΔE from both the ink player color and the
    /// ochre/green landscape), the falcon to near-black crimson, and the
    /// claim traces separate cleanly.
    static func activePalette(_ base: RegionPalette, _ highContrast: Bool) -> RegionPalette {
        guard highContrast else { return base }
        var p = base
        p.rival = RGBAColor(r: 0.871, g: 0.180, b: 0.612)  // saturated magenta
        p.falcon = RGBAColor(r: 0.400, g: 0.020, b: 0.060)  // dark crimson
        p.birdHighlight = RGBAColor(r: 0.960, g: 0.960, b: 0.960)  // white edge
        return p
    }

    private static func paletteData(_ palette: RegionPalette) -> PaletteData {
        func c(_ color: RGBAColor) -> SIMD4<Float> {
            SIMD4(color.r, color.g, color.b, color.a)
        }
        return PaletteData(
            skyStops: [
                c(palette.skyTop), c(palette.skyHigh), c(palette.skyLow), c(palette.skyBottom),
            ],
            birdColors: [
                c(palette.birdInk), c(palette.rival), c(palette.falcon), c(palette.birdHighlight),
            ],
            fieldOchre: c(palette.fieldOchre),
            fieldGreen: c(palette.fieldGreen),
            claimPlayer: c(palette.birdHighlight),
            claimRival: c(palette.rival)
        )
    }

    /// Called once per simulation tick with everything to draw. `instant`
    /// skips interpolation for the next frame (fast-forward jumps).
    public func update(_ scene: RenderScene, instant: Bool = false) {
        duskBlend = min(max(scene.duskBlend, 0), 1)
        buildBirdInstances(scene)
        buildDiskInstances(scene)
        buildTraceVertices(scene)
        lastTickTime = CACurrentMediaTime()
        sawTick = true
        // Reduce Motion (MU-P8.1): `reducesFlutter` snaps every draw to the
        // settled tick position (no between-tick blend), so the flock moves
        // in discrete 30 Hz steps instead of gliding — the motion-reduced
        // read for vestibular sensitivity. Wingbeat breathing stays (it is
        // per-bird scale, not whole-flock translation).
        instantNextDraw = instant || reducesFlutter
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor else { return }
        let size = SIMD2(Int(view.drawableSize.width), Int(view.drawableSize.height))
        guard let buffer = commandQueue.makeCommandBuffer() else { return }
        render(to: pass, size: size, commandBuffer: buffer)
        if let drawable = view.currentDrawable {
            buffer.present(drawable)
        }
        buffer.commit()
    }

    /// Encode one frame into `pass`. Split out of `draw(in:)` so tests can
    /// render offscreen into a texture.
    public func render(
        to pass: MTLRenderPassDescriptor, size: SIMD2<Int>, commandBuffer: MTLCommandBuffer
    ) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }
        let params = Self.transformParams(
            worldSize: worldSize,
            viewSize: SIMD2(Float(size.x), Float(size.y))
        )
        let alpha = Float(interpolationAlpha())

        // 1. Sky.
        encoder.setRenderPipelineState(skyPipeline)
        encoder.setFragmentBytes(
            paletteData.skyStops, length: MemoryLayout<SIMD4<Float>>.stride * 4, index: 0
        )
        var dusk: [Float] = [duskBlend]
        encoder.setFragmentBytes(&dusk, length: MemoryLayout<Float>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // 2. Hills.
        encoder.setRenderPipelineState(hillPipeline)
        encoder.setVertexBuffer(hillBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(params, length: MemoryLayout<Float>.stride * 4, index: 1)
        var hillDusk: [Float] = [duskBlend]
        encoder.setVertexBytes(&hillDusk, length: MemoryLayout<Float>.stride, index: 2)
        for range in hillRanges {
            encoder.drawPrimitives(
                type: .triangleStrip, vertexStart: range.offset, vertexCount: range.count
            )
        }

        // 3. Fields and roosts.
        encoder.setRenderPipelineState(diskPipeline)
        encoder.setVertexBuffer(unitDisk, offset: 0, index: 0)
        encoder.setVertexBytes(params, length: MemoryLayout<Float>.stride * 4, index: 2)
        if !diskInstances.isEmpty {
            encoder.setVertexBytes(
                diskInstances,
                length: MemoryLayout<DiskInstance>.stride * diskInstances.count,
                index: 1
            )
            encoder.drawPrimitives(
                type: .triangle, vertexStart: 0, vertexCount: 96, instanceCount: diskInstances.count
            )
        }

        // 4. Leader trace.
        if traceVertices.count >= 2 {
            encoder.setRenderPipelineState(tracePipeline)
            encoder.setVertexBytes(
                traceVertices,
                length: MemoryLayout<TraceVertex>.stride * traceVertices.count,
                index: 0
            )
            encoder.setVertexBytes(params, length: MemoryLayout<Float>.stride * 4, index: 1)
            let traceColor = paletteData.claimPlayer
            var traceColorData: [Float] = [
                traceColor.x, traceColor.y, traceColor.z, 0.55,
            ]
            encoder.setFragmentBytes(
                &traceColorData, length: MemoryLayout<Float>.stride * 4, index: 0
            )
            encoder.drawPrimitives(
                type: .lineStrip, vertexStart: 0, vertexCount: traceVertices.count
            )
        }

        // 4b. Pending-path hover preview (MU-P7.2): brighter, thinner alpha
        // than the committed trace so it reads as "about to draw".
        if pendingVertices.count >= 2 {
            encoder.setRenderPipelineState(tracePipeline)
            encoder.setVertexBytes(
                pendingVertices,
                length: MemoryLayout<TraceVertex>.stride * pendingVertices.count,
                index: 0
            )
            encoder.setVertexBytes(params, length: MemoryLayout<Float>.stride * 4, index: 1)
            let traceColor = paletteData.claimPlayer
            var previewColorData: [Float] = [
                traceColor.x, traceColor.y, traceColor.z, 0.85,
            ]
            encoder.setFragmentBytes(
                &previewColorData, length: MemoryLayout<Float>.stride * 4, index: 0
            )
            encoder.drawPrimitives(
                type: .lineStrip, vertexStart: 0, vertexCount: pendingVertices.count
            )
        }

        // 5. Birds and falcons.
        if birdInstanceCount > 0 {
            encoder.setRenderPipelineState(birdPipeline)
            encoder.setVertexBuffer(birdBuffer, offset: 0, index: 0)
            var birdParams = params + [alpha]
            encoder.setVertexBytes(
                &birdParams, length: MemoryLayout<Float>.stride * birdParams.count, index: 1
            )
            encoder.setFragmentBytes(
                paletteData.birdColors,
                length: MemoryLayout<SIMD4<Float>>.stride * paletteData.birdColors.count,
                index: 0
            )
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4,
                instanceCount: birdInstanceCount
            )
        }

        encoder.endEncoding()
    }

    // MARK: - Frame math

    /// Interpolation progress between the last two ticks, clamped to [0, 1].
    private func interpolationAlpha() -> Double {
        if instantNextDraw {
            instantNextDraw = false
            return 1
        }
        guard sawTick, tickInterval > 0 else { return 1 }
        let elapsed = CACurrentMediaTime() - lastTickTime
        return min(max(elapsed / tickInterval, 0), 1)
    }

    // MARK: - Per-tick rebuilds

    private func buildBirdInstances(_ scene: RenderScene) {
        let cur = scene.birds
        let prev = scene.previousBirds
        let prevCount = prev.count
        // When the count shrank (deaths rebuild the arrays), index identity
        // breaks: snap this frame instead of blending mismatched birds.
        let snapAll = cur.count <= prevCount

        birdInstanceCount = 0
        let total = cur.count + scene.falconCur.count
        guard total <= birdCapacity else { return }
        let ptr = birdBuffer.contents().bindMemory(
            to: BirdInstance.self, capacity: birdCapacity
        )
        var written = 0
        // Reduce Motion (MU-P8.1): every Nth bird. The stride is
        // deterministic in instance order, so the drawn subset is stable
        // frame to frame (no flicker) and a stride of 1 draws everything.
        // The stride-1 path iterates the range directly: allocating a
        // 3,000-element index array every frame is measurable per-frame
        // cost for zero benefit (G8 perf gate).
        let stride = max(birdStride, 1)
        let ctx = BirdWriteContext(
            cur: cur, prev: prev, prevCount: prevCount,
            snapAll: snapAll, tick: scene.tick, size: birdSize
        )
        if stride == 1 {
            for i in 0..<cur.count {
                writeBird(&ptr[written], index: i, ctx: ctx)
                written += 1
            }
        } else {
            for i in Swift.stride(from: 0, to: cur.count, by: stride) {
                writeBird(&ptr[written], index: i, ctx: ctx)
                written += 1
            }
        }
        for i in 0..<scene.falconCur.count {
            let curPos = scene.falconCur[i]
            let prevPos = i < scene.falconPrev.count ? scene.falconPrev[i] : curPos
            var instance = BirdInstance()
            instance.prevX = prevPos.x
            instance.prevY = prevPos.y
            instance.curX = curPos.x
            instance.curY = curPos.y
            instance.velX = curPos.x - prevPos.x
            instance.velY = curPos.y - prevPos.y
            instance.size = falconSize
            instance.colorIdx = 2
            ptr[written] = instance
            written += 1
        }
        birdInstanceCount = written
    }

    private func buildDiskInstances(_ scene: RenderScene) {
        diskInstances.removeAll(keepingCapacity: true)
        for field in scene.fields {
            let maxDepletion = max(field.maxDepletion, 1)
            let food = 1 - Float(field.currentDepletion) / Float(maxDepletion)
            diskInstances.append(DiskInstance(
                centerX: Float(field.centerX),
                centerY: Float(field.centerY),
                radius: Float(field.radius),
                pad: 0,
                color: SIMD4(
                    paletteData.fieldOchre.x,
                    paletteData.fieldOchre.y,
                    paletteData.fieldOchre.z,
                    0.16 + 0.30 * food
                )
            ))
            diskInstances.append(DiskInstance(
                centerX: Float(field.centerX),
                centerY: Float(field.centerY),
                radius: Float(field.radius) * 0.62,
                pad: 0,
                color: SIMD4(
                    paletteData.fieldGreen.x,
                    paletteData.fieldGreen.y,
                    paletteData.fieldGreen.z,
                    0.10 + 0.30 * food
                )
            ))
        }
        for roost in scene.roosts {
            // The roost (MU-P6.1): a soft dark knot of trees on the
            // skyline — layered rim rather than a flat black hole.
            diskInstances.append(DiskInstance(
                centerX: Float(roost.centerX),
                centerY: Float(roost.centerY),
                radius: Float(roost.radius),
                pad: 0,
                color: SIMD4(0.11, 0.10, 0.15, 0.92)
            ))
            diskInstances.append(DiskInstance(
                centerX: Float(roost.centerX),
                centerY: Float(roost.centerY),
                radius: Float(roost.radius) * 0.72,
                pad: 0,
                color: SIMD4(0.06, 0.06, 0.09, 0.96)
            ))
            // Claim fill: the majority flock's share of accrued points, with
            // exact ties (R-12 accrues nothing) left unfilled.
            let total = roost.claims.reduce(0, +)
            if total > 0 {
                let best = roost.claims.max() ?? 0
                let leaders = roost.claims.filter { $0 == best }.count
                if leaders == 1, let leaderIdx = roost.claims.firstIndex(of: best) {
                    let share = Float(best) / Float(total)
                    let fill = leaderIdx == 0
                        ? paletteData.claimPlayer
                        : paletteData.claimRival
                    diskInstances.append(DiskInstance(
                        centerX: Float(roost.centerX),
                        centerY: Float(roost.centerY),
                        radius: Float(roost.radius) * sqrt(share),
                        pad: 0,
                        color: SIMD4(fill.x, fill.y, fill.z, 0.9)
                    ))
                }
            }
        }
    }

    private func buildTraceVertices(_ scene: RenderScene) {
        traceVertices.removeAll(keepingCapacity: true)
        for point in scene.trace {
            traceVertices.append(TraceVertex(
                pos: SIMD2(point.x, point.y), age: min(max(point.age, 0), 1)
            ))
        }
        pendingVertices = scene.pendingPath.map {
            TraceVertex(pos: SIMD2($0.x, $0.y), age: 0)
        }
    }

}

/// Static geometry, transform math, and pipeline setup.
extension FlockRenderer {
    /// World-to-NDC parameters: {sx, sy, cx, cy}. The world is letterboxed
    /// into the view: `scale` is pixels per world unit (the smaller ratio so
    /// the world fits), so sx = 2·scale / viewWidth.
    static func transformParams(worldSize: SIMD2<Float>, viewSize: SIMD2<Float>) -> [Float] {
        let scale = min(viewSize.x / worldSize.x, viewSize.y / worldSize.y)
        let sx = 2 * scale / viewSize.x
        let sy = 2 * scale / viewSize.y
        return [sx, sy, worldSize.x / 2, worldSize.y / 2]
    }

    /// Inverse of the render transform: a view-space point (y down, in
    /// drawable pixels) to world units. Gesture input uses this to build
    /// leader paths in world space.
    public static func worldPoint(
        viewPoint: SIMD2<Float>, viewSize: SIMD2<Float>, worldSize: SIMD2<Float>
    ) -> SIMD2<Float> {
        let scale = min(viewSize.x / worldSize.x, viewSize.y / worldSize.y)
        let sx = 2 * scale / viewSize.x
        let sy = 2 * scale / viewSize.y
        let nx = viewPoint.x / viewSize.x * 2 - 1
        let ny = 1 - viewPoint.y / viewSize.y * 2
        return SIMD2(nx / sx + worldSize.x / 2, worldSize.y / 2 - ny / sy)
    }

    // MARK: - Static geometry

    /// Three hill silhouette layers as triangle strips, deterministic in the
    /// seed so a region always renders the same skyline.
    static func hillLayers(
        palette: RegionPalette, worldSize: SIMD2<Float>, seed: UInt64
    ) -> (vertices: [HillVertex], ranges: [(offset: Int, count: Int)]) {
        var rng = SeededRNG(seed: seed &+ 0x51_11_5)
        var vertices: [HillVertex] = []
        var ranges: [(offset: Int, count: Int)] = []
        let layers: [(color: RGBAColor, base: Float, amplitude: Float)] = [
            (palette.hillFar, worldSize.y * 0.52, 130),
            (palette.hillMid, worldSize.y * 0.68, 160),
            (palette.hillNear, worldSize.y * 0.86, 190),
        ]
        let step: Float = 64
        let count = Int(worldSize.x / step) + 1
        for layer in layers {
            var heights: [Float] = []
            heights.reserveCapacity(count)
            for _ in 0..<count {
                heights.append(Float(rng.next(upperBound: 1000)) / 1000)
            }
            let start = vertices.count
            for i in 0..<count {
                let smoothed = (heights[max(i - 1, 0)] + heights[i] * 2
                    + heights[min(i + 1, count - 1)]) / 4
                let x = Float(i) * step
                let y = layer.base - layer.amplitude * smoothed
                vertices.append(HillVertex(pos: SIMD2(x, y), color: Self.color(layer.color)))
                vertices.append(HillVertex(
                    pos: SIMD2(x, worldSize.y), color: Self.color(layer.color)
                ))
            }
            ranges.append((start, vertices.count - start))
        }
        return (vertices, ranges)
    }

    // MARK: - Helpers

    private static func pipeline(
        device: MTLDevice,
        library: MTLLibrary,
        view: MTKView,
        spec: PipelineSpec
    ) throws -> MTLRenderPipelineState {
        guard let vertexFn = library.makeFunction(name: spec.vertex),
            let fragmentFn = library.makeFunction(name: spec.fragment) else {
            throw RenderError.missingFunction("\(spec.vertex)/\(spec.fragment)")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        if spec.blend {
            if let attachment = descriptor.colorAttachments[0] {
                attachment.isBlendingEnabled = true
                attachment.rgbBlendOperation = .add
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw RenderError.pipeline(error)
        }
    }

    private static func color(_ c: RGBAColor) -> SIMD4<Float> {
        SIMD4(c.r, c.g, c.b, c.a)
    }
}

/// Renderer setup failures.
public enum RenderError: Error {
    case missingDevice
    case missingCommandQueue
    case shaderLibrary(Error)
    case missingFunction(String)
    case pipeline(Error)
    case bufferAllocation
}

/// The per-frame bird-write inputs: captures what the build loop needs
/// once so the per-bird helper stays at two parameters.
private struct BirdWriteContext {
    let cur: BirdSoA
    let prev: BirdSoA
    let prevCount: Int
    let snapAll: Bool
    let tick: Int
    let size: Float
}

/// Writes one bird's instance into the shared buffer slot: blend against
/// the previous tick's position when index identity is intact, else snap;
/// Q16.16 velocity passes through unscaled (the shader only needs
/// direction); the wingbeat clock is deterministic in (tick, i).
private func writeBird(_ slot: inout BirdInstance, index i: Int, ctx: BirdWriteContext) {
    var instance = BirdInstance()
    let canBlend = !ctx.snapAll && i < ctx.prevCount
    instance.prevX = canBlend ? Float(ctx.prev.posX[i]) : Float(ctx.cur.posX[i])
    instance.prevY = canBlend ? Float(ctx.prev.posY[i]) : Float(ctx.cur.posY[i])
    instance.curX = Float(ctx.cur.posX[i])
    instance.curY = Float(ctx.cur.posY[i])
    instance.velX = Float(ctx.cur.velX[i])
    instance.velY = Float(ctx.cur.velY[i])
    instance.size = ctx.size
    instance.colorIdx = Float(ctx.cur.subFlock[i] == 0 ? 0 : 1)
    instance.phase = Float((ctx.tick * 13 + i * 41) % 24) / 24.0 * 6.2831853
    slot = instance
}
