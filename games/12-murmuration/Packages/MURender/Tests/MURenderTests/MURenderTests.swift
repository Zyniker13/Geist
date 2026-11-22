import XCTest
import Metal
import MetalKit
import MUCore
import MUContent
@testable import MURender

/// FlockRenderer tests (P2.1). Layout, transform, and geometry tests run
/// everywhere; the offscreen render smoke test skips gracefully when no
/// Metal device exists (e.g. a virtualized CI runner without a GPU).
final class MURenderTests: XCTestCase {
    private func makePalette() -> RegionPalette {
        .standard
    }

    // MARK: - Layout (must match the shaders' struct layouts)

    func testBirdInstanceLayoutMatchesShader() {
        XCTAssertEqual(MemoryLayout<BirdInstance>.stride, 40)
        XCTAssertEqual(MemoryLayout<BirdInstance>.size, 40)
    }

    func testDiskInstanceLayoutMatchesShader() {
        XCTAssertEqual(MemoryLayout<DiskInstance>.stride, 32)
        // The color must sit at offset 16 so the shader's float4 reads it.
        var d = DiskInstance()
        d.color = SIMD4(1, 2, 3, 4)
        let r = withUnsafeBytes(of: &d) { $0.load(fromByteOffset: 16, as: Float.self) }
        let g = withUnsafeBytes(of: &d) { $0.load(fromByteOffset: 20, as: Float.self) }
        XCTAssertEqual(r, 1, "color.r at offset 16")
        XCTAssertEqual(g, 2, "color.g at offset 20")
    }

    func testTraceVertexLayoutMatchesShader() {
        // float2 + float: size 12, 8-byte aligned, so stride 16 (matches
        // the Metal struct's alignment).
        XCTAssertEqual(MemoryLayout<TraceVertex>.stride, 16)
    }

    func testHillVertexLayoutMatchesShader() {
        // float2 + float4: the float4 forces 16-byte alignment, so stride 32.
        XCTAssertEqual(MemoryLayout<HillVertex>.stride, 32)
    }

    // MARK: - Transform

    /// A 4:3 world in a 4:3 view fills it exactly: the world corners map to
    /// the NDC corners.
    func testTransformParamsFillsMatchingAspect() {
        let params = FlockRenderer.transformParams(
            worldSize: SIMD2(2048, 1536), viewSize: SIMD2(1024, 768)
        )
        // Corner (0, 0) -> NDC (-1, +1); (2048, 1536) -> (+1, -1).
        let x0 = (0 - params[2]) * params[0]
        let y0 = (params[3] - 0) * params[1]
        XCTAssertEqual(x0, -1, accuracy: 0.0001)
        XCTAssertEqual(y0, 1, accuracy: 0.0001)
        let x1 = (2048 - params[2]) * params[0]
        let y1 = (params[3] - 1536) * params[1]
        XCTAssertEqual(x1, 1, accuracy: 0.0001)
        XCTAssertEqual(y1, -1, accuracy: 0.0001)
    }

    /// A square view letterboxes the world: the horizontal extent fills and
    /// the vertical bands.
    func testTransformParamsLetterboxes() {
        let params = FlockRenderer.transformParams(
            worldSize: SIMD2(2048, 1536), viewSize: SIMD2(1536, 1536)
        )
        let x0 = (0 - params[2]) * params[0]
        XCTAssertEqual(x0, -1, accuracy: 0.0001, "wider view: horizontal fills")
        let y0 = (params[3] - 0) * params[1]
        XCTAssertEqual(y0, 0.75, accuracy: 0.0001, "vertical letterboxes")
    }

    /// `worldPoint` is the exact inverse of `transformParams`.
    func testWorldPointRoundTripsThroughTransform() {
        let world = SIMD2<Float>(2048, 1536)
        let view = SIMD2<Float>(1536, 1536)
        let params = FlockRenderer.transformParams(worldSize: world, viewSize: view)
        for probe in [SIMD2<Float>(100, 100), SIMD2<Float>(1024, 768), SIMD2<Float>(1900, 1400)] {
            let ndcX = (probe.x - params[2]) * params[0]
            let ndcY = (params[3] - probe.y) * params[1]
            let viewPoint = SIMD2(
                (ndcX + 1) / 2 * view.x, (1 - ndcY) / 2 * view.y
            )
            let roundTripped = FlockRenderer.worldPoint(
                viewPoint: viewPoint, viewSize: view, worldSize: world
            )
            XCTAssertEqual(roundTripped.x, probe.x, accuracy: 0.5)
            XCTAssertEqual(roundTripped.y, probe.y, accuracy: 0.5)
        }
    }

    // MARK: - Hills

    func testHillLayersAreDeterministic() {
        let a = FlockRenderer.hillLayers(
            palette: makePalette(), worldSize: SIMD2(2048, 1536), seed: 11
        )
        let b = FlockRenderer.hillLayers(
            palette: makePalette(), worldSize: SIMD2(2048, 1536), seed: 11
        )
        XCTAssertEqual(a.vertices, b.vertices)
        XCTAssertEqual(a.ranges.count, 3, "three hill layers")
    }

    func testHillLayersCoverTheWorld() {
        let hills = FlockRenderer.hillLayers(
            palette: makePalette(), worldSize: SIMD2(2048, 1536), seed: 11
        )
        // Each layer is a triangle strip: 2 vertices per sample column.
        let perLayer = (Int(2048 / 64) + 1) * 2
        for range in hills.ranges {
            XCTAssertEqual(range.count, perLayer)
        }
        XCTAssertEqual(
            hills.ranges.reduce(0) { $0 + $1.count }, hills.vertices.count
        )
    }

    // MARK: - Scene construction

    func testMakeSceneDuskBlend() {
        let state = GameState(
            birdCount: 10, worldWidth: 2048, worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [10], fieldRadius: [128],
            fieldCenterX: [1024], fieldCenterY: [768],
            roostCount: 1, roostCenterX: [1024], roostCenterY: [768],
            roostRadius: [128], falconCount: 0, hasRival: false,
            windSeedOffset: 0, seed: 1
        )
        var dusk = state
        dusk.tick = 0
        XCTAssertEqual(makeScene(state: dusk, previousBirds: dusk.birds, falconPrev: [], trace: []).duskBlend, 0)
        dusk.tick = GameState.duskStart
        XCTAssertEqual(makeScene(state: dusk, previousBirds: dusk.birds, falconPrev: [], trace: []).duskBlend, 0)
        dusk.tick = GameState.dayTicks
        XCTAssertEqual(
            makeScene(state: dusk, previousBirds: dusk.birds, falconPrev: [], trace: []).duskBlend, 1,
            accuracy: 0.0001
        )
    }

    // MARK: - Offscreen render smoke test

    /// Renders one frame offscreen and checks two pixels: the sky gradient
    /// at the top and an ink bird at the center.
    func testOffscreenRenderSmoke() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("no Metal device available in this environment")
        }
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 8, height: 8), device: device)
        let renderer = try FlockRenderer(
            mtkView: view,
            palette: makePalette(),
            worldSize: SIMD2(2048, 1536),
            hillSeed: 11
        )

        // One bird at the world center, one falcon nearby.
        var state = GameState(
            birdCount: 1, worldWidth: 2048, worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [10], fieldRadius: [128],
            fieldCenterX: [1024], fieldCenterY: [768],
            roostCount: 1, roostCenterX: [1024], roostCenterY: [768],
            roostRadius: [128], falconCount: 1, hasRival: false,
            windSeedOffset: 0, seed: 1
        )
        state.birds.posX[0] = 1024
        state.birds.posY[0] = 768
        state.falcons[0].currentX = 1124
        state.falcons[0].currentY = 768
        let scene = makeScene(
            state: state, previousBirds: state.birds, falconPrev: [], trace: []
        )
        renderer.update(scene)

        // Offscreen target matching the world aspect (fills exactly).
        let width = 512
        let height = 384
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: view.colorPixelFormat, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 1, alpha: 1)

        guard let queue = device.makeCommandQueue(),
            let buffer = queue.makeCommandBuffer() else {
            return XCTFail("no command queue/buffer")
        }
        renderer.render(to: pass, size: SIMD2(width, height), commandBuffer: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()

        // Read back and check: sky at the top, ink bird at the center.
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(
            &pixels, bytesPerRow: width * 4,
            from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0
        )
        func pixel(_ x: Int, _ y: Int) -> (Float, Float, Float) {
            let o = (y * width + x) * 4
            // bgra8Unorm
            return (
                Float(pixels[o + 2]) / 255, Float(pixels[o + 1]) / 255, Float(pixels[o]) / 255
            )
        }
        let skyTop = pixel(256, 2)
        XCTAssertEqual(skyTop.0, 0.18, accuracy: 0.06, "sky top should be dusk indigo")
        XCTAssertGreaterThan(skyTop.2, skyTop.0, "indigo is bluer than red")

        let birdPixel = pixel(256, 192)
        XCTAssertLessThan(birdPixel.0, 0.30, "the bird at the center is ink-dark")
        XCTAssertLessThan(birdPixel.1, 0.30)
    }

    /// A 3,000-bird scene renders end to end without crashing.
    func testThreeThousandBirdSceneRenders() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("no Metal device available in this environment")
        }
        let device = MTLCreateSystemDefaultDevice()!
        let view = MTKView(frame: CGRect(x: 0, y: 0, width: 8, height: 8), device: device)
        let renderer = try FlockRenderer(
            mtkView: view, palette: makePalette(), worldSize: SIMD2(2048, 1536)
        )
        var state = GameState(
            birdCount: 3000, worldWidth: 2048, worldHeight: 1536,
            boidsParams: BoidsParams(),
            fieldRichness: [60], fieldRadius: [128],
            fieldCenterX: [1024], fieldCenterY: [768],
            roostCount: 1, roostCenterX: [1024], roostCenterY: [768],
            roostRadius: [128], falconCount: 1, hasRival: false,
            windSeedOffset: 0, seed: 1
        )
        var rng = SeededRNG(seed: 1)
        var trace: [TracePoint] = []
        for _ in 0..<30 {
            let (next, _) = applyTick(to: state, rng: &rng)
            trace.append(TracePoint(
                x: Float(state.leaderPaths[0].currentX),
                y: Float(state.leaderPaths[0].currentY),
                age: 0.5
            ))
            state = next
            let scene = makeScene(
                state: state, previousBirds: state.birds, falconPrev: [], trace: trace
            )
            renderer.update(scene)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: view.colorPixelFormat, width: 256, height: 192, mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 1, alpha: 1)
        guard let queue = device.makeCommandQueue(),
            let buffer = queue.makeCommandBuffer() else {
            return XCTFail("no command queue/buffer")
        }
        renderer.render(to: pass, size: SIMD2(256, 192), commandBuffer: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        XCTAssertEqual(buffer.status, .completed)
    }
}
