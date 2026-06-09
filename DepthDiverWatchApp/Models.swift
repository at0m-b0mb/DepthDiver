import CoreGraphics

// MARK: - Game phase

enum GamePhase {
    case menu
    case playing
    case gameOver
}

// MARK: - Entities
//
// All positions are in Canvas point coordinates (origin top-left, +y down).
// The world scrolls *up* (decreasing y) to sell the sensation of descending:
// entities spawn below the screen and rise past the diver.

enum ObstacleKind: CaseIterable {
    case rock       // solid, drifts slowly
    case jellyfish  // translucent, sways, bobs sideways
    case coral      // tall cluster, stationary drift
    case mine       // spiked sea-mine, the nastiest
}

struct Obstacle {
    var kind: ObstacleKind
    var pos: CGPoint
    var size: CGSize
    var drift: CGFloat          // horizontal velocity (pts/sec)
    var sway: CGFloat = 0       // animation accumulator
}

enum PickupKind {
    case pearl      // score
    case oxygen     // refills the air supply
}

struct Pickup {
    var kind: PickupKind
    var pos: CGPoint
    var radius: CGFloat
    var bob: CGFloat = 0        // animation accumulator
}

enum ParticleColor {
    case snow       // ambient marine snow
    case cyan       // oxygen pop / dash bubbles
    case pink       // pearl pop
    case gold       // boss-defeat burst
}

/// Marine snow + bubble trail. Pure eye-candy that also sells motion/speed.
struct Particle {
    var pos: CGPoint
    var vel: CGVector
    var radius: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var color: ParticleColor = .snow
}

/// The anglerfish that ambushes the diver at depth milestones.
struct Boss {
    var pos: CGPoint
    var size: CGSize
    var health: Int
    var dir: CGFloat            // +1 / -1 horizontal sweep direction
    var phase: CGFloat = 0      // animation accumulator (mouth + lure glow)
    var timeLeft: CGFloat       // auto-retreats when this hits 0
    var hitFlash: CGFloat = 0   // brief white flash when damaged
}

// MARK: - Small helpers

@inline(__always)
func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

@inline(__always)
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}
