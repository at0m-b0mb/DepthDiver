import SwiftUI

/// Stateless drawing layer. Reads the engine's current frame and paints it
/// into a `Canvas` `GraphicsContext`. Kept separate from the simulation so
/// gameplay and rendering can evolve independently.
///
/// Marked `@MainActor`: the `Canvas` renderer runs on the main thread and the
/// SDK isolates its closure to the main actor, so the whole drawing layer must
/// match to legally read the `@MainActor` `GameEngine` state.
@MainActor
enum DepthRenderer {

    // MARK: Entry point

    static func draw(engine: GameEngine, context: inout GraphicsContext, size: CGSize) {
        let df = Double(clamp(engine.depth / 2500, 0, 1))   // 0 = surface, 1 = abyss

        // Stable copy taken *before* screen-shake — HUD/flash ride on this so
        // they never jitter with the world.
        var hud = context

        if engine.shake > 0 {
            let s = engine.shake
            context.translateBy(x: .random(in: -s...s) * 0.5,
                                y: .random(in: -s...s) * 0.5)
        }

        background(&context, size: size, df: df)
        drawParticles(engine, &context)
        for pk in engine.pickups { drawPickup(pk, &context) }
        for o in engine.obstacles { drawObstacle(o, &context) }
        if let b = engine.boss { drawBoss(b, &context) }
        drawPlayer(engine, &context, size: size, df: df)

        if engine.damageFlash > 0 {
            hud.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(col(0.9, 0.1, 0.1, Double(engine.damageFlash) * 0.45)))
        }
        drawHUD(&hud, engine: engine, size: size)
    }

    // MARK: Background

    private static func background(_ ctx: inout GraphicsContext, size: CGSize, df: Double) {
        let top = mix((0.06, 0.42, 0.52), (0.00, 0.03, 0.07), df)
        let bot = mix((0.00, 0.14, 0.24), (0.00, 0.00, 0.00), df)
        // overscan a little so screen-shake never reveals black edges
        let r = CGRect(x: -16, y: -16, width: size.width + 32, height: size.height + 32)
        ctx.fill(Path(r), with: .linearGradient(
            Gradient(colors: [top, bot]),
            startPoint: CGPoint(x: 0, y: -16),
            endPoint: CGPoint(x: 0, y: size.height + 16)))

        // shaft of light from the surface, fades as you descend
        if df < 1 {
            let g = Gradient(colors: [col(0.5, 0.8, 0.85, 0.32 * (1 - df)),
                                      col(0.5, 0.8, 0.85, 0)])
            ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.1, y: -size.height * 0.35,
                                            width: size.width * 0.8, height: size.height * 0.8)),
                     with: .radialGradient(g, center: CGPoint(x: size.width / 2, y: 0),
                                           startRadius: 1, endRadius: size.height * 0.65))
        }
    }

    // MARK: Particles

    private static func drawParticles(_ engine: GameEngine, _ ctx: inout GraphicsContext) {
        for p in engine.particles {
            let a = Double(max(0, p.life / p.maxLife))
            let color: Color
            switch p.color {
            case .snow: color = col(1, 1, 1, a * 0.5)
            case .cyan: color = col(0.3, 0.9, 1.0, a)
            case .pink: color = col(1.0, 0.6, 0.8, a)
            case .gold: color = col(1.0, 0.85, 0.3, a)
            }
            ctx.fill(circle(p.pos, p.radius), with: .color(color))
        }
    }

    // MARK: Pickups

    private static func drawPickup(_ pk: Pickup, _ ctx: inout GraphicsContext) {
        let bob = CGFloat(sin(Double(pk.bob) * 3)) * 2
        let c = CGPoint(x: pk.pos.x, y: pk.pos.y + bob)
        let r = pk.radius
        switch pk.kind {
        case .pearl:
            ctx.fill(circle(c, r * 2.4), with: .radialGradient(
                Gradient(colors: [col(1, 0.7, 0.85, 0.45), col(1, 0.7, 0.85, 0)]),
                center: c, startRadius: 1, endRadius: r * 2.4))
            ctx.fill(circle(c, r), with: .radialGradient(
                Gradient(colors: [col(1, 1, 1), col(1, 0.78, 0.86)]),
                center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3),
                startRadius: 1, endRadius: r * 1.5))
            ctx.fill(circle(CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35), r * 0.3),
                     with: .color(col(1, 1, 1, 0.9)))
        case .oxygen:
            ctx.fill(circle(c, r * 2.2), with: .radialGradient(
                Gradient(colors: [col(0.3, 0.9, 1, 0.4), col(0.3, 0.9, 1, 0)]),
                center: c, startRadius: 1, endRadius: r * 2.2))
            ctx.fill(circle(c, r), with: .color(col(0.3, 0.85, 1, 0.28)))
            ctx.stroke(circle(c, r), with: .color(col(0.6, 0.95, 1, 0.95)), lineWidth: 1.5)
            ctx.fill(circle(CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35), r * 0.28),
                     with: .color(col(1, 1, 1, 0.9)))
        }
    }

    // MARK: Obstacles

    private static func drawObstacle(_ o: Obstacle, _ ctx: inout GraphicsContext) {
        switch o.kind {
        case .rock:      drawRock(o, &ctx)
        case .jellyfish: drawJelly(o, &ctx)
        case .coral:     drawCoral(o, &ctx)
        case .mine:      drawMine(o, &ctx)
        }
    }

    private static func drawRock(_ o: Obstacle, _ ctx: inout GraphicsContext) {
        let rect = CGRect(x: o.pos.x - o.size.width / 2, y: o.pos.y - o.size.height / 2,
                          width: o.size.width, height: o.size.height)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [col(0.22, 0.24, 0.28), col(0.05, 0.06, 0.08)]),
            center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.3),
            startRadius: 1, endRadius: rect.width))
        ctx.fill(Path(ellipseIn: CGRect(x: rect.minX + rect.width * 0.12, y: rect.midY - rect.height * 0.05,
                                        width: rect.width * 0.45, height: rect.height * 0.4)),
                 with: .color(col(0.13, 0.14, 0.17)))
        ctx.stroke(Path(ellipseIn: rect), with: .color(col(0.45, 0.55, 0.6, 0.22)), lineWidth: 1)
    }

    private static func drawJelly(_ o: Obstacle, _ ctx: inout GraphicsContext) {
        let w = o.size.width, h = o.size.height
        let c = o.pos
        let glow = CGRect(x: c.x - w * 0.7, y: c.y - h * 0.6, width: w * 1.4, height: h * 1.2)
        ctx.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [col(0.7, 0.5, 0.95, 0.3), col(0.7, 0.5, 0.95, 0)]),
            center: c, startRadius: 1, endRadius: w))
        // tentacles
        for k in 0..<4 {
            let tx = c.x - w * 0.3 + w * 0.2 * CGFloat(k)
            let sway = CGFloat(sin(Double(o.sway) * 3 + Double(k))) * 4
            var t = Path()
            t.move(to: CGPoint(x: tx, y: c.y))
            t.addQuadCurve(to: CGPoint(x: tx + sway, y: c.y + h * 0.7),
                           control: CGPoint(x: tx + sway * 1.5, y: c.y + h * 0.35))
            ctx.stroke(t, with: .color(col(0.8, 0.6, 1.0, 0.6)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        // bell
        let bell = CGRect(x: c.x - w / 2, y: c.y - h * 0.5, width: w, height: h * 0.7)
        ctx.fill(Path(ellipseIn: bell), with: .radialGradient(
            Gradient(colors: [col(0.85, 0.65, 1.0, 0.85), col(0.5, 0.35, 0.85, 0.55)]),
            center: CGPoint(x: bell.midX, y: bell.minY + bell.height * 0.4),
            startRadius: 1, endRadius: w * 0.7))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - w * 0.22, y: c.y - h * 0.42,
                                        width: w * 0.2, height: h * 0.2)),
                 with: .color(col(1, 1, 1, 0.6)))
    }

    private static func drawCoral(_ o: Obstacle, _ ctx: inout GraphicsContext) {
        let c = o.pos, h = o.size.height, w = o.size.width
        let base = CGPoint(x: c.x, y: c.y + h / 2)
        func branch(_ dx: CGFloat, _ topY: CGFloat, _ color: Color) {
            var p = Path()
            p.move(to: base)
            p.addQuadCurve(to: CGPoint(x: c.x + dx, y: topY),
                           control: CGPoint(x: c.x + dx * 0.3, y: (base.y + topY) / 2))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        branch(0, c.y - h / 2, col(0.95, 0.4, 0.45))
        branch(-w * 0.6, c.y - h * 0.15, col(0.9, 0.55, 0.3))
        branch(w * 0.6, c.y - h * 0.2, col(0.9, 0.5, 0.55))
        // nubs
        for (nx, ny) in [(0.0, -0.5), (-0.6, -0.15), (0.6, -0.2)] {
            ctx.fill(circle(CGPoint(x: c.x + CGFloat(nx) * w, y: c.y + CGFloat(ny) * h), 3.5),
                     with: .color(col(1, 0.7, 0.7, 0.9)))
        }
    }

    private static func drawMine(_ o: Obstacle, _ ctx: inout GraphicsContext) {
        let c = o.pos, rad = o.size.width / 2
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi + Double(o.sway) * 0.5
            let ox = CGFloat(cos(a)), oy = CGFloat(sin(a))
            var sp = Path()
            sp.move(to: CGPoint(x: c.x + ox * rad * 0.8, y: c.y + oy * rad * 0.8))
            sp.addLine(to: CGPoint(x: c.x + ox * rad * 1.45, y: c.y + oy * rad * 1.45))
            ctx.stroke(sp, with: .color(col(0.3, 0.32, 0.34)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        ctx.fill(circle(c, rad), with: .radialGradient(
            Gradient(colors: [col(0.2, 0.22, 0.25), col(0.03, 0.04, 0.05)]),
            center: CGPoint(x: c.x - rad * 0.3, y: c.y - rad * 0.3),
            startRadius: 1, endRadius: rad * 1.4))
        ctx.stroke(circle(c, rad * 0.62), with: .color(col(0.35, 0.37, 0.4, 0.6)), lineWidth: 1)
        let on = sin(Double(o.sway) * 6) > 0
        ctx.fill(circle(CGPoint(x: c.x, y: c.y - rad * 0.5), 2.6),
                 with: .color(on ? col(1, 0.25, 0.2) : col(0.4, 0.1, 0.1)))
    }

    // MARK: Boss — anglerfish

    private static func drawBoss(_ b: Boss, _ ctx: inout GraphicsContext) {
        let c = b.pos, w = b.size.width, h = b.size.height
        let body = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)

        ctx.fill(Path(ellipseIn: body.insetBy(dx: -12, dy: -12)), with: .radialGradient(
            Gradient(colors: [col(0.25, 0.1, 0.35, 0.4), col(0.25, 0.1, 0.35, 0)]),
            center: c, startRadius: 1, endRadius: w * 0.6))
        ctx.fill(Path(ellipseIn: body), with: .radialGradient(
            Gradient(colors: [col(0.16, 0.12, 0.2), col(0.03, 0.02, 0.05)]),
            center: CGPoint(x: c.x, y: c.y + h * 0.1), startRadius: 2, endRadius: w * 0.6))

        // mouth gap + teeth along the top edge (facing the diver above)
        let mouthY = c.y - h * 0.16
        let mouthW = w * 0.66
        ctx.fill(Path(CGRect(x: c.x - mouthW / 2, y: mouthY - 2, width: mouthW, height: 5)),
                 with: .color(.black))
        let teeth = 7
        for k in 0..<teeth {
            let tx = c.x - mouthW / 2 + mouthW * (CGFloat(k) + 0.5) / CGFloat(teeth)
            var t = Path()
            t.move(to: CGPoint(x: tx - 3, y: mouthY))
            t.addLine(to: CGPoint(x: tx, y: mouthY - 7))
            t.addLine(to: CGPoint(x: tx + 3, y: mouthY))
            t.closeSubpath()
            ctx.fill(t, with: .color(col(0.95, 0.95, 0.95)))
        }

        // eye
        let eye = CGPoint(x: c.x - w * 0.16, y: c.y + h * 0.02)
        ctx.fill(circle(eye, 6), with: .color(col(0.95, 0.95, 0.9)))
        ctx.fill(circle(CGPoint(x: eye.x + 1, y: eye.y), 3), with: .color(.black))

        // bioluminescent lure dangling toward the diver
        let pulse = CGFloat(0.6 + 0.4 * sin(Double(b.phase) * 4))
        let lureBase = CGPoint(x: c.x + w * 0.08, y: c.y - h * 0.45)
        let lureTip = CGPoint(x: c.x + w * 0.14, y: c.y - h * 0.95)
        var rod = Path()
        rod.move(to: lureBase)
        rod.addQuadCurve(to: lureTip, control: CGPoint(x: c.x + w * 0.32, y: c.y - h * 0.75))
        ctx.stroke(rod, with: .color(col(0.1, 0.1, 0.12)), lineWidth: 2)
        ctx.fill(circle(lureTip, 11 * pulse), with: .radialGradient(
            Gradient(colors: [col(1, 0.95, 0.5, Double(pulse) * 0.9), col(1, 0.8, 0.2, 0)]),
            center: lureTip, startRadius: 1, endRadius: 11))
        ctx.fill(circle(lureTip, 3), with: .color(col(1, 1, 0.75)))

        if b.hitFlash > 0 {
            ctx.fill(Path(ellipseIn: body), with: .color(col(1, 1, 1, Double(b.hitFlash) * 0.7)))
        }
    }

    // MARK: Player — helmeted diver with head-lamp

    private static func drawPlayer(_ engine: GameEngine, _ ctx: inout GraphicsContext,
                                   size: CGSize, df: Double) {
        let p = engine.playerPos(in: size)
        let r = engine.playerRadius
        let blink: Double = engine.invuln > 0
            ? (sin(Double(engine.elapsed) * 30) > 0 ? 0.4 : 1.0) : 1.0

        // head-lamp cone (points down into the dark; brighter the deeper you are)
        ctx.drawLayer { l in
            l.blendMode = .plusLighter
            let len = 70 + 70 * CGFloat(df)
            let half: CGFloat = 26
            var cone = Path()
            cone.move(to: CGPoint(x: p.x, y: p.y + r * 0.2))
            cone.addLine(to: CGPoint(x: p.x - half, y: p.y + len))
            cone.addLine(to: CGPoint(x: p.x + half, y: p.y + len))
            cone.closeSubpath()
            l.fill(cone, with: .linearGradient(
                Gradient(colors: [col(0.8, 0.95, 1.0, 0.45 * (0.4 + 0.6 * df)),
                                  col(0.2, 0.6, 0.8, 0)]),
                startPoint: CGPoint(x: p.x, y: p.y),
                endPoint: CGPoint(x: p.x, y: p.y + len)))
        }

        // air bubbles trailing up
        for k in 0..<3 {
            let t = Double(engine.elapsed) * 2 + Double(k) * 1.3
            let by = p.y - r - CGFloat((t.truncatingRemainder(dividingBy: 2)) * 14)
            let bx = p.x + CGFloat(sin(t * 3)) * 3 + r * 0.4
            ctx.fill(circle(CGPoint(x: bx, y: by), 1.6), with: .color(col(0.8, 0.95, 1, 0.4)))
        }

        // suit
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.7, y: p.y - r * 0.1,
                                        width: r * 1.4, height: r * 1.8)),
                 with: .color(col(0.06, 0.2, 0.24, blink)))
        // fins
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.9, y: p.y - r * 0.2,
                                        width: r * 0.5, height: r * 0.9)),
                 with: .color(col(0.04, 0.14, 0.18, blink)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x + r * 0.4, y: p.y - r * 0.2,
                                        width: r * 0.5, height: r * 0.9)),
                 with: .color(col(0.04, 0.14, 0.18, blink)))
        // helmet
        ctx.fill(circle(p, r), with: .radialGradient(
            Gradient(colors: [col(0.55, 0.85, 0.95, blink), col(0.1, 0.4, 0.5, blink)]),
            center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.3),
            startRadius: 1, endRadius: r * 1.7))
        // faceplate
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.5,
                                        width: r * 1.1, height: r)),
                 with: .color(col(0.02, 0.08, 0.12, blink)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.4, y: p.y - r * 0.45,
                                        width: r * 0.45, height: r * 0.3)),
                 with: .color(col(0.8, 0.95, 1.0, 0.55 * blink)))
    }

    // MARK: HUD

    private static func drawHUD(_ ctx: inout GraphicsContext, engine: GameEngine, size: CGSize) {
        let bx: CGFloat = 8, by: CGFloat = 8
        let barW = size.width * 0.42, barH: CGFloat = 6
        let o2 = Double(clamp(engine.oxygen / 100, 0, 1))

        ctx.fill(Path(roundedRect: CGRect(x: bx, y: by, width: barW, height: barH), cornerRadius: 3),
                 with: .color(col(1, 1, 1, 0.16)))
        ctx.fill(Path(roundedRect: CGRect(x: bx, y: by, width: barW * CGFloat(o2), height: barH),
                      cornerRadius: 3),
                 with: .color(mix((0.95, 0.25, 0.2), (0.2, 0.85, 0.95), o2)))

        ctx.draw(Text("O₂").font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85)),
                 at: CGPoint(x: bx, y: by + barH + 2), anchor: .topLeading)
        ctx.draw(Text("◆ \(engine.pearls)").font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(col(1, 0.65, 0.8)),
                 at: CGPoint(x: bx + 24, y: by + barH + 1), anchor: .topLeading)
        ctx.draw(Text("\(Int(engine.depth)) m").font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white),
                 at: CGPoint(x: size.width - 8, y: by - 2), anchor: .topTrailing)

        if let b = engine.boss, b.health > 0, b.timeLeft > 0 {
            let cx = size.width / 2, y = size.height * 0.2
            for k in 0..<3 {
                let on = k < b.health
                let px = cx + CGFloat(k - 1) * 12
                ctx.fill(circle(CGPoint(x: px, y: y), 4),
                         with: .color(on ? col(1, 0.3, 0.3) : col(1, 1, 1, 0.2)))
            }
            ctx.draw(Text("DASH INTO IT!").font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(col(1, 0.8, 0.3)),
                     at: CGPoint(x: cx, y: y + 9), anchor: .top)
        }

        let ready = engine.dashCooldown <= 0
        ctx.fill(circle(CGPoint(x: size.width / 2, y: size.height - 9), 3),
                 with: .color(ready ? col(0.2, 0.85, 0.95) : col(1, 1, 1, 0.22)))

        if engine.hintTime > 0 {
            let a = Double(min(1, engine.hintTime / 1.2))
            ctx.draw(Text("TAP TO DASH").font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55 * a)),
                     at: CGPoint(x: size.width / 2, y: size.height - 24), anchor: .center)
        }
    }

    // MARK: Helpers

    private static func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private static func mix(_ a: (Double, Double, Double),
                            _ b: (Double, Double, Double), _ t: Double) -> Color {
        let u = min(max(t, 0), 1)
        return Color(.sRGB,
                     red: a.0 + (b.0 - a.0) * u,
                     green: a.1 + (b.1 - a.1) * u,
                     blue: a.2 + (b.2 - a.2) * u,
                     opacity: 1)
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
