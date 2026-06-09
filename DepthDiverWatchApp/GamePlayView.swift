import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject private var engine: GameEngine

    /// Bound to the Digital Crown. 0 = far left, 1 = far right.
    @State private var crown: Double = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                engine.targetXFrac = CGFloat(crown)
                engine.advance(to: timeline.date, size: size)
                DepthRenderer.draw(engine: engine, context: &context, size: size)
            }
        }
        .background(Color.black)
        .focusable(true)
        .digitalCrownRotation(
            $crown,
            from: 0, through: 1, by: 0.01,
            sensitivity: .high,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .contentShape(Rectangle())
        .onTapGesture { engine.dash() }
        .ignoresSafeArea()
    }
}
