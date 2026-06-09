import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var engine: GameEngine

    private var isBest: Bool { engine.lastScore > 0 && engine.lastScore >= engine.bestScore }

    var body: some View {
        ZStack {
            OceanBackdrop()

            VStack(spacing: 2) {
                Text(isBest ? "NEW BEST!" : "SURFACED")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(isBest
                        ? Color(.sRGB, red: 1.0, green: 0.84, blue: 0.2, opacity: 1)
                        : .white)

                Text("\(engine.lastScore)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("BEST \(engine.bestScore)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                HStack(spacing: 8) {
                    Button {
                        Haptic.uiTap(); engine.backToMenu()
                    } label: {
                        Image(systemName: "house.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Haptic.uiTap(); engine.start()
                    } label: {
                        Image(systemName: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(.sRGB, red: 0.0, green: 0.62, blue: 0.78, opacity: 1))
                }
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
        }
    }
}
