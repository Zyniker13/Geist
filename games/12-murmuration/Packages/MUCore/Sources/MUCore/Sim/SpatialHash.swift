/// Uniform spatial hash over the world grid (R-7).
///
/// Counting-sort layout: `cellStart` holds `cols * rows + 1` prefix offsets into
/// `birdIndex`. Rebuilding appends bird indices in ascending bird-ID order, so every
/// cell's slice is ID-ascending and queries iterate in a deterministic order
/// (cells row-major from the top-left of the 3x3 neighborhood, IDs ascending within
/// a cell) — required for cross-device determinism (INV-3).
public struct SpatialHash: Sendable {
    public let cellSize: Int32
    public let cols: Int32
    public let rows: Int32

    private var cellStart: [Int32]
    private var birdIndex: [Int32]

    public init(width: Int32, height: Int32, cellSize: Int32) {
        self.cellSize = cellSize
        self.cols = (width + cellSize - 1) / cellSize
        self.rows = (height + cellSize - 1) / cellSize
        self.cellStart = [Int32](repeating: 0, count: Int(cols * rows) + 1)
        self.birdIndex = []
        self.birdIndex.reserveCapacity(4096)
    }

    /// Cell coordinates for a world position (positions are always in-bounds).
    @inline(__always)
    public func cellOf(x: Int32, y: Int32) -> (cx: Int32, cy: Int32) {
        (min(x / cellSize, cols - 1), min(y / cellSize, rows - 1))
    }

    /// Slice of `birdIndex` holding the IDs in one cell.
    @inline(__always)
    public func range(cx: Int32, cy: Int32) -> Range<Int> {
        let cell = Int(cy * cols + cx)
        return Int(cellStart[cell])..<Int(cellStart[cell + 1])
    }

    /// Number of birds in one cell.
    @inline(__always)
    public func count(cx: Int32, cy: Int32) -> Int {
        range(cx: cx, cy: cy).count
    }

    /// Bird ID at `offset` inside a cell range previously returned by `range(cx:cy:)`.
    @inline(__always)
    public func birdID(at index: Int) -> Int32 {
        birdIndex[index]
    }

    /// Rebuild the grid from current positions (O(N + cells)).
    /// `posX`/`posY` are indexed by bird ID; iteration order fixes per-cell ordering.
    public mutating func rebuild(posX: [Int32], posY: [Int32], count: Int) {
        let cellCount = Int(cols * rows)
        for i in 0...cellCount { cellStart[i] = 0 }
        // Pass 1: count.
        for i in 0..<count {
            let c = cellOf(x: posX[i], y: posY[i])
            cellStart[Int(c.cy * cols + c.cx) + 1] += 1
        }
        // Prefix sum.
        for c in 1...cellCount { cellStart[c] += cellStart[c - 1] }
        // Pass 2: place (ascending ID within each cell).
        birdIndex.replaceSubrange(0..<birdIndex.count, with: [Int32](repeating: 0, count: count))
        var cursor = [Int32](repeating: 0, count: cellCount)
        for i in 0..<count {
            let c = cellOf(x: posX[i], y: posY[i])
            let cell = Int(c.cy * cols + c.cx)
            birdIndex[Int(cellStart[cell] + cursor[cell])] = Int32(i)
            cursor[cell] += 1
        }
    }
}
