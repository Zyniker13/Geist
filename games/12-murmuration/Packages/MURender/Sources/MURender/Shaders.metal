// Murmuration Render — Metal shaders (MU-P2.1).
//
// Five pipelines: the four-stop dusk sky gradient, three hill silhouette
// layers, instanced disks (fields and roost claims), instanced oriented bird
// quads with tick interpolation, and the fading leader-path trace.
//
// All world-space geometry shares one transform: params = {sx, sy, cx, cy},
// where (sx, sy) maps world units to NDC and (cx, cy) is the world center.
// The world's y axis points down (screen-like), so NDC y is flipped.

#include <metal_stdlib>
using namespace metal;

float2 toNDC(float2 p, constant float *params) {
    return float2((p.x - params[2]) * params[0], (params[3] - p.y) * params[1]);
}

// MARK: - Sky

struct FullOut {
    float4 position [[position]];
    float2 uv;
};

// One oversized triangle covers the viewport.
vertex FullOut skyVertex(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    FullOut out;
    out.position = float4(pos[vid], 0.0, 1.0);
    out.uv = pos[vid] * 0.5 + 0.5;
    return out;
}

// stops = four palette stops from the zenith down; params[0] = dusk blend.
fragment float4 skyFragment(FullOut in [[stage_in]],
                            constant float4 *stops [[buffer(0)]],
                            constant float *params [[buffer(1)]]) {
    float t = saturate(1.0 - in.uv.y) * 3.0;
    int i = int(min(floor(t), 2.0));
    float f = t - float(i);
    float4 c = mix(stops[i], stops[i + 1], f);
    c.rgb *= (1.0 - 0.35 * params[0]);
    return c;
}

// MARK: - Hills (and any solid per-vertex-colored triangles)

struct HillVertex {
    float2 pos;
    float4 color;
};

struct SolidOut {
    float4 position [[position]];
    float4 color;
};

vertex SolidOut hillVertex(uint vid [[vertex_id]],
                           constant HillVertex *verts [[buffer(0)]],
                           constant float *params [[buffer(1)]]) {
    HillVertex v = verts[vid];
    SolidOut out;
    out.position = float4(toNDC(v.pos, params), 0.0, 1.0);
    out.color = v.color;
    return out;
}

fragment float4 solidFragment(SolidOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Disks (fields, roosts, roost claim fills)

// Swift mirror: SIMD2<Float>, Float, pad, SIMD4<Float> (stride 32).
struct DiskInstance {
    float2 center;
    float radius;
    float pad;
    float4 color;
};

struct DiskOut {
    float4 position [[position]];
    float4 color;
};

vertex DiskOut diskVertex(uint vid [[vertex_id]],
                          uint iid [[instance_id]],
                          constant float2 *unit [[buffer(0)]],
                          constant DiskInstance *instances [[buffer(1)]],
                          constant float *params [[buffer(2)]]) {
    DiskInstance d = instances[iid];
    float2 radii = float2(d.radius * params[0], d.radius * params[1]);
    DiskOut out;
    out.position = float4(toNDC(d.center, params) + unit[vid] * radii, 0.0, 1.0);
    out.color = d.color;
    return out;
}

fragment float4 diskFragment(DiskOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Birds (instanced oriented quads, interpolated)

// Swift mirror: six Floats, size, colorIdx (stride 32). Positions and
// velocity are world units; the quad is oriented along the velocity.
struct BirdInstance {
    float2 prev;
    float2 cur;
    float2 vel;
    float size;
    float colorIdx;
};

struct BirdOut {
    float4 position [[position]];
    float shade;
    float colorIdx;
    float edge;
};

vertex BirdOut birdVertex(uint vid [[vertex_id]],
                          uint iid [[instance_id]],
                          constant BirdInstance *instances [[buffer(0)]],
                          constant float *params [[buffer(1)]]) {
    // params = {sx, sy, cx, cy, alpha}
    BirdInstance b = instances[iid];
    float2 corners[4] = {
        float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0)
    };
    float2 corner = corners[vid & 3];
    float vlen = length(b.vel);
    float2 dir = vlen > 0.0001 ? b.vel / vlen : float2(1.0, 0.0);
    float2 side = float2(-dir.y, dir.x);
    float2 p = mix(b.prev, b.cur, params[4]);
    float2 offset = dir * (corner.x * b.size * 0.5)
                  + side * (corner.y * b.size * 0.30);
    BirdOut out;
    out.position = float4(toNDC(p + offset, params), 0.0, 1.0);
    uint h = (iid * 2654435761u) >> 24;
    out.shade = 0.90 + float(h & 0xFFu) / 255.0 * 0.18;
    out.colorIdx = b.colorIdx;
    out.edge = corner.y;
    return out;
}

// colors = {player ink, rival sepia, falcon, highlight}.
fragment float4 birdFragment(BirdOut in [[stage_in]],
                             constant float4 *colors [[buffer(0)]]) {
    int idx = int(in.colorIdx + 0.5);
    float4 base = colors[idx];
    base.rgb *= in.shade;
    float hl = saturate(in.edge) * 0.35;
    base.rgb = mix(base.rgb, colors[3].rgb, hl);
    return base;
}

// MARK: - Leader trace (fading line strip)

// Swift mirror: SIMD2<Float>, Float (stride 12).
struct TraceVertex {
    float2 pos;
    float age;
};

struct TraceOut {
    float4 position [[position]];
    float age;
};

vertex TraceOut traceVertex(uint vid [[vertex_id]],
                            constant TraceVertex *verts [[buffer(0)]],
                            constant float *params [[buffer(1)]]) {
    TraceVertex v = verts[vid];
    TraceOut out;
    out.position = float4(toNDC(v.pos, params), 0.0, 1.0);
    out.age = v.age;
    return out;
}

// trace = {r, g, b, alphaScale}.
fragment float4 traceFragment(TraceOut in [[stage_in]],
                              constant float *trace [[buffer(0)]]) {
    float a = (1.0 - saturate(in.age)) * trace[3];
    return float4(trace[0], trace[1], trace[2], a);
}
