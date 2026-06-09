import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        ZStack {
            OceanBackdrop()

            VStack(spacing: 3) {
                Text("DEPTH")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("D I V E R")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Color(.sRGB, red: 0.2, green: 0.85, blue: 0.95, opacity: 1))

                if engine.bestScore > 0 {
                    Text("BEST \(engine.bestScore)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 4)
                }

                Button {
                    Haptic.uiTap()
                    engine.start()
                } label: {
                    Text("DIVE")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.sRGB, red: 0.0, green: 0.62, blue: 0.78, opacity: 1))
                .padding(.top, 8)

                Text("Crown to steer · Tap to dash")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
        }
    }
}
