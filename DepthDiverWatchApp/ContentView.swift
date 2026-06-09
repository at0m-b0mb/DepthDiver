import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        ZStack {
            switch engine.phase {
            case .menu:     MenuView()
            case .playing:  GamePlayView()
            case .gameOver: GameOverView()
            }
        }
        .ignoresSafeArea()
    }
}

/// Shared calm-water gradient used by the menu and game-over screens:
/// dark teal up top fading to black, with a soft shaft of light from above.
struct OceanBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 0.02, green: 0.18, blue: 0.28, opacity: 1),
                    Color(.sRGB, red: 0.0,  green: 0.05, blue: 0.12, opacity: 1),
                    .black
                ],
                startPoint: .top, endPoint: .bottom)

            Ellipse()
                .fill(Color(.sRGB, red: 0.15, green: 0.55, blue: 0.65, opacity: 0.4))
                .frame(width: 240, height: 130)
                .blur(radius: 45)
                .offset(y: -70)
        }
        .ignoresSafeArea()
    }
}
