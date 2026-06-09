import SwiftUI

/// The whole simulation. Coarse UI state (`phase`, scores) is `@Published`;
/// per-frame state is plain `private(set)` storage mutated inside `advance`,
/// which is driven once per display refresh by the `TimelineView` in
/// `GamePlayView`. Keeping the hot fields un-published avoids 60 Hz SwiftUI
/// invalidations — the `TimelineView` already forces the redraw.
@MainActor
final class GameEngine: ObservableObject {

    // MARK: Published (rarely changes — safe to drive views)
    @Published private(set) var phase: GamePhase = .menu
    @Published private(set) var lastScore: Int = 0
    @Published private(set) var bestScore: Int = 0

    // MARK: Tunables
    let playerRadius: CGFloat = 11
    let playerYFrac: CGFloat = 0.30
    private let pxPerMeter: CGFloat = 9
    private let bossInterval: CGFloat = 1000

    // MARK: Per-frame state (read by the renderer)
    private(set) var depth: CGFloat = 0
    private(set) var oxygen: CGFloat = 100
    private(set) var pearls: Int = 0
    private(set) var playerXFrac: CGFloat = 0.5
    var targetXFrac: CGFloat = 0.5            // written by the Digital Crown
    private(set) var descentSpeed: CGFloat = 6
    private(set) var obstacles: [Obstacle] = []
    private(set) var pickups: [Pickup] = []
    private(set) var particles: [Particle] = []
    private(set) var boss: Boss?
    private(set) var bossesDefeated = 0
    private(set) var invuln: CGFloat = 0
    private(set) var dashTime: CGFloat = 0
    private(set) var dashCooldown: CGFloat = 0
    private(set) var damageFlash: CGFloat = 0
    private(set) var shake: CGFloat = 0
    private(set) var elapsed: CGFloat = 0
    private(set) var hintTime: CGFloat = 0

    // MARK: Private bookkeeping
    private var nextBossDepth: CGFloat = 1000
    private var spawnAccum: CGFloat = 0
    private var pickupAccum: CGFloat = 0
    private var particleAccum: CGFloat = 0
    private var lastDate: Date?
    private var dying = false
    private let bestKey = "DepthDiver.bestScore"

    var scrollSpeed: CGFloat { descentSpeed * pxPerMeter }
    var score: Int { Int(depth) + pearls * 25 }

    init() {
        bestScore = UserDefaults.standard.integer(forKey: bestKey)
    }

    // MARK: Lifecycle

    func start() {
        phase = .playing
        dying = false
        depth = 0; oxygen = 100; pearls = 0
        playerXFrac = 0.5; targetXFrac = 0.5
        descentSpeed = 6
        obstacles.removeAll(); pickups.removeAll(); particles.removeAll()
        boss = nil; bossesDefeated = 0
        nextBossDepth = bossInterval
        spawnAccum = 0.8; pickupAccum = 1.4; particleAccum = 0
        invuln = 1.0; dashTime = 0; dashCooldown = 0
        damageFlash = 0; shake = 0; elapsed = 0; hintTime = 4.0
        lastDate = nil
    }

    func backToMenu() { phase = .menu }

    /// Tap-to-dash: a downward dolphin-kick that briefly accelerates the
    /// descent and grants i-frames — the only way to damage a boss.
    func dash() {
        guard phase == .playing, dashCooldown <= 0 else { return }
        dashTime = 0.55
        dashCooldown = 0.75
        invuln = max(invuln, 0.55)
        oxygen = max(0, oxygen - 3)
        addShake(4)
        Haptic.dash()
    }

    // MARK: Geometry

    func playerPos(in size: CGSize) -> CGPoint {
        let margin = playerRadius + 6
        let x = margin + playerXFrac * (size.width - margin * 2)
        return CGPoint(x: x, y: size.height * playerYFrac)
    }

    // MARK: Main step

    func advance(to date: Date, size: CGSize) {
        guard phase == .playing else { lastDate = date; return }
        let dt = min(CGFloat(date.timeIntervalSince(lastDate ?? date)), 1.0 / 20.0)
        lastDate = date
        guard dt > 0 else { return }
        elapsed += dt

        // timers
        invuln = max(0, invuln - dt)
        dashTime = max(0, dashTime - dt)
        dashCooldown = max(0, dashCooldown - dt)
        damageFlash = max(0, damageFlash - dt * 2.5)
        shake = max(0, shake - dt * 36)
        hintTime = max(0, hintTime - dt)

        // descent & depth
        let boost: CGFloat = dashTime > 0 ? 1.9 : 1.0
        descentSpeed = clamp(6 + depth * 0.0016, 6, 46)
        depth += descentSpeed * boost * dt
        let dy = scrollSpeed * boost * dt

        // oxygen
        let drain = (2.0 + depth * 0.0009) * (dashTime > 0 ? 1.6 : 1.0)
        oxygen = max(0, oxygen - drain * dt)
        if oxygen <= 0 { die(); return }

        moveEntities(dy: dy, dt: dt)
        updateSpawns(dt: dt, size: size)
        updateBoss(dt: dt, dy: dy, size: size)

        // steer toward the crown target
        playerXFrac += (targetXFrac - playerXFrac) * clamp(dt * 12, 0, 1)
        playerXFrac = clamp(playerXFrac, 0, 1)

        handleCollisions(size: size)
        emitParticles(dt: dt, size: size)
    }

    // MARK: Movement / culling

    private func moveEntities(dy: CGFloat, dt: CGFloat) {
        for i in obstacles.indices {
            obstacles[i].pos.y -= dy
            obstacles[i].pos.x += obstacles[i].drift * dt
            obstacles[i].sway += dt
        }
        obstacles.removeAll { $0.pos.y < -50 }

        for i in pickups.indices {
            pickups[i].pos.y -= dy
            pickups[i].bob += dt
        }
        pickups.removeAll { $0.pos.y < -30 }

        for i in particles.indices {
            particles[i].pos.y -= dy * 0.6
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 || $0.pos.y < -12 }
    }

    // MARK: Spawning

    private func updateSpawns(dt: CGFloat, size: CGSize) {
        guard boss == nil else {
            pickupAccum -= dt
            if pickupAccum <= 0 { spawnPickup(size: size); pickupAccum = .random(in: 2.0...3.5) }
            return
        }
        let interval = clamp(1.5 - depth * 0.0009, 0.45, 1.5)
        spawnAccum -= dt
        if spawnAccum <= 0 {
            spawnObstacle(size: size)
            spawnAccum = interval * .random(in: 0.7...1.25)
        }
        pickupAccum -= dt
        if pickupAccum <= 0 {
            spawnPickup(size: size)
            pickupAccum = .random(in: 1.4...2.6)
        }
    }

    private func obstacleKind() -> ObstacleKind {
        var pool: [ObstacleKind] = [.rock, .rock, .coral]
        if depth > 250  { pool += [.jellyfish, .jellyfish] }
        if depth > 600  { pool += [.mine] }
        if depth > 1200 { pool += [.mine, .jellyfish] }
        return pool.randomElement() ?? .rock
    }

    private func spawnObstacle(size: CGSize) {
        let x = CGFloat.random(in: 24...(size.width - 24))
        let y = size.height + 50
        switch obstacleKind() {
        case .rock:
            let s = CGFloat.random(in: 26...44)
            obstacles.append(Obstacle(kind: .rock, pos: CGPoint(x: x, y: y),
                                      size: CGSize(width: s, height: s * 0.82),
                                      drift: .random(in: -6...6)))
        case .jellyfish:
            let s = CGFloat.random(in: 22...32)
            obstacles.append(Obstacle(kind: .jellyfish, pos: CGPoint(x: x, y: y),
                                      size: CGSize(width: s, height: s * 1.2),
                                      drift: .random(in: -24...24)))
        case .coral:
            let s = CGFloat.random(in: 30...46)
            obstacles.append(Obstacle(kind: .coral, pos: CGPoint(x: x, y: y),
                                      size: CGSize(width: s * 0.8, height: s * 1.5),
                                      drift: 0))
        case .mine:
            let s = CGFloat.random(in: 24...30)
            obstacles.append(Obstacle(kind: .mine, pos: CGPoint(x: x, y: y),
                                      size: CGSize(width: s, height: s),
                                      drift: .random(in: -10...10)))
        }
    }

    private func spawnPickup(size: CGSize) {
        let wantOxygen = Double.random(in: 0...1) < (oxygen < 45 ? 0.55 : 0.30)
        let kind: PickupKind = wantOxygen ? .oxygen : .pearl
        let x = CGFloat.random(in: 22...(size.width - 22))
        pickups.append(Pickup(kind: kind,
                              pos: CGPoint(x: x, y: size.height + 30),
                              radius: kind == .oxygen ? 11 : 8))
    }

    // MARK: Boss

    private func spawnBoss(size: CGSize) {
        boss = Boss(pos: CGPoint(x: size.width / 2, y: size.height + 80),
                    size: CGSize(width: size.width * 0.8, height: 70),
                    health: 3,
                    dir: Bool.random() ? 1 : -1,
                    timeLeft: 16)
        obstacles.removeAll()       // clear the arena for a clean fight
        Haptic.bossAppear()
    }

    private func updateBoss(dt: CGFloat, dy: CGFloat, size: CGSize) {
        if boss == nil && depth >= nextBossDepth {
            spawnBoss(size: size)
        }
        guard var b = boss else { return }
        b.phase += dt
        b.hitFlash = max(0, b.hitFlash - dt * 3)

        let leaving = (b.health <= 0 || b.timeLeft <= 0)
        if leaving {
            b.pos.y -= 240 * dt
        } else {
            b.timeLeft -= dt
            let hoverY = size.height * 0.46
            if b.pos.y > hoverY {
                b.pos.y = max(hoverY, b.pos.y - max(220 * dt, dy))
            } else {
                b.pos.x += b.dir * 30 * dt
                let margin = b.size.width * 0.35
                if b.pos.x < margin { b.pos.x = margin; b.dir = 1 }
                if b.pos.x > size.width - margin { b.pos.x = size.width - margin; b.dir = -1 }
            }
        }
        boss = b

        if b.pos.y < -150 {
            if b.health <= 0 { onBossDefeated(at: CGPoint(x: size.width / 2, y: size.height * 0.4)) }
            boss = nil
            nextBossDepth += bossInterval
        }
    }

    private func onBossDefeated(at point: CGPoint) {
        bossesDefeated += 1
        pearls += 5
        oxygen = min(100, oxygen + 35)
        popParticles(at: point, color: .gold, count: 26, speed: 90)
        Haptic.bossDown()
    }

    // MARK: Collisions

    private func handleCollisions(size: CGSize) {
        let p = playerPos(in: size)
        let r = playerRadius

        pickups.removeAll { pk in
            guard p.distance(to: pk.pos) < r + pk.radius else { return false }
            switch pk.kind {
            case .pearl:
                pearls += 1
                popParticles(at: pk.pos, color: .pink, count: 8, speed: 55)
                Haptic.pearl()
            case .oxygen:
                oxygen = min(100, oxygen + 26)
                popParticles(at: pk.pos, color: .cyan, count: 10, speed: 60)
                Haptic.oxygen()
            }
            return true
        }

        if var b = boss, b.health > 0, b.timeLeft > 0 {
            let inset = b.size.width * 0.12
            let rect = CGRect(x: b.pos.x - b.size.width / 2 + inset,
                              y: b.pos.y - b.size.height / 2 + 6,
                              width: b.size.width - inset * 2,
                              height: b.size.height - 12)
            if circleHitsRect(center: p, r: r, rect: rect) {
                if dashTime > 0 {
                    b.health -= 1
                    b.hitFlash = 1
                    dashTime = 0
                    invuln = max(invuln, 0.6)
                    addShake(9)
                    popParticles(at: p, color: .gold, count: 10, speed: 70)
                    playerXFrac = clamp(playerXFrac + (p.x < b.pos.x ? -0.2 : 0.2), 0, 1)
                    Haptic.hit()
                    boss = b
                } else if invuln <= 0 {
                    boss = b
                    damage(at: p)
                } else {
                    boss = b
                }
            } else {
                boss = b
            }
        }

        if invuln <= 0 {
            let rr = r * 0.85
            for o in obstacles {
                let rect = CGRect(x: o.pos.x - o.size.width * 0.4,
                                  y: o.pos.y - o.size.height * 0.4,
                                  width: o.size.width * 0.8,
                                  height: o.size.height * 0.8)
                if circleHitsRect(center: p, r: rr, rect: rect) {
                    damage(at: p)
                    break
                }
            }
        }
    }

    private func circleHitsRect(center c: CGPoint, r: CGFloat, rect: CGRect) -> Bool {
        let nx = clamp(c.x, rect.minX, rect.maxX)
        let ny = clamp(c.y, rect.minY, rect.maxY)
        return hypot(c.x - nx, c.y - ny) < r
    }

    private func damage(at p: CGPoint) {
        oxygen = max(0, oxygen - 24)
        invuln = 1.1
        damageFlash = 1
        addShake(13)
        popParticles(at: p, color: .cyan, count: 12, speed: 80)
        Haptic.hit()
        if oxygen <= 0 { die() }
    }

    // MARK: Particles

    private func emitParticles(dt: CGFloat, size: CGSize) {
        particleAccum -= dt
        while particleAccum <= 0 {
            particleAccum += 0.045
            guard particles.count < 170 else { break }
            particles.append(Particle(
                pos: CGPoint(x: .random(in: 0...size.width), y: size.height + 6),
                vel: CGVector(dx: .random(in: -4...4), dy: .random(in: -6 ... -2)),
                radius: .random(in: 0.6...2.2),
                life: .random(in: 3...6), maxLife: 6, color: .snow))
        }
        if dashTime > 0 {
            let p = playerPos(in: size)
            for _ in 0..<2 {
                particles.append(Particle(
                    pos: CGPoint(x: p.x + .random(in: -6...6), y: p.y + 8),
                    vel: CGVector(dx: .random(in: -10...10), dy: .random(in: 20...46)),
                    radius: .random(in: 1...3), life: 0.5, maxLife: 0.5, color: .cyan))
            }
        }
    }

    private func popParticles(at point: CGPoint, color: ParticleColor, count: Int, speed: CGFloat) {
        for _ in 0..<count {
            let a = CGFloat.random(in: 0...(.pi * 2))
            let s = CGFloat.random(in: speed * 0.4...speed)
            particles.append(Particle(
                pos: point,
                vel: CGVector(dx: cos(a) * s, dy: sin(a) * s),
                radius: .random(in: 1...3), life: 0.5, maxLife: 0.5, color: color))
        }
    }

    private func addShake(_ m: CGFloat) { shake = max(shake, m) }

    // MARK: Death

    private func die() {
        guard !dying else { return }
        dying = true
        lastScore = score
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: bestKey)
        }
        Haptic.gameOver()
        DispatchQueue.main.async { [weak self] in self?.phase = .gameOver }
    }
}
