import WatchKit

/// Thin wrapper over the Taptic Engine so gameplay code requests feedback
/// by *intent* rather than by raw `WKHapticType`. Tuning the feel of the
/// whole game then happens in one place.
enum Haptic {
    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    static func pearl()      { play(.click) }
    static func oxygen()     { play(.success) }
    static func hit()        { play(.failure) }
    static func dash()       { play(.start) }
    static func bossAppear() { play(.notification) }
    static func bossDown()   { play(.success) }
    static func gameOver()   { play(.failure) }
    static func uiTap()      { play(.click) }
}
