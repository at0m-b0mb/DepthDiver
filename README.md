# Depth Diver 🌊

An arcade descent game for **Apple Watch** (built for the Watch Ultra, runs on
watchOS 10+). Steer a diver down an endless ocean trench with the **Digital
Crown**, **tap to dash**, manage your oxygen, dodge the deep, and fight the
anglerfish that ambushes you at every 1000 m.

Written entirely in **SwiftUI** — the whole scene is drawn in a `Canvas`, driven
by a `TimelineView` game loop, with Taptic Engine haptics throughout. No
external assets, no SpriteKit, no companion iPhone app required.

---

## Controls

| Input | Action |
|-------|--------|
| **Digital Crown** | Steer left / right |
| **Tap screen** | Dash — a downward kick that briefly speeds you up, grants i-frames, and is the **only way to damage a boss** |

## How it plays

- **Descend** forever. Your depth in metres is your score; it climbs faster the
  deeper you get.
- **Oxygen** constantly drains (faster the deeper you are, and while dashing).
  Grab **cyan O₂ bubbles** to refill. Hit **0 = game over**.
- **Hazards** rise toward you: rocks, swaying jellyfish, coral, and spiked sea
  mines. A hit costs a big chunk of oxygen + knocks you back (brief i-frames).
- **Pearls** ◆ are worth bonus points.
- **Boss fight** every 1000 m: an anglerfish blocks the trench. **Dash into it**
  three times to drive it off for a big oxygen + pearl reward. Touch it without
  dashing and it bites you. It retreats after ~16 s either way.
- Difficulty scales continuously with depth: faster scroll, denser hazards,
  nastier enemy mix, and the water darkens so your head-lamp does real work.

Best score is saved between sessions.

---

## Build & run

Requires **Xcode 16+** (developed on Xcode 26.5 / watchOS 26.5 SDK).

```bash
open "DepthDiver/DepthDiver.xcodeproj"
```

1. Select the **Depth Diver Watch App** scheme.
2. Pick a destination:
   - **Simulator:** choose any Apple Watch simulator. If none appear, install a
     watchOS Simulator runtime via *Xcode ▸ Settings ▸ Components* (it's a
     multi-GB download Apple doesn't bundle by default).
   - **Your Apple Watch Ultra:** select your watch. Sideloading to a physical
     watch needs a paid **Apple Developer Program** membership; set your Team
     under *Signing & Capabilities* first. A free Apple ID covers the simulator.
3. Press **Run** (⌘R).

### Command-line build check

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DepthDiver/DepthDiver.xcodeproj \
  -scheme "Depth Diver Watch App" \
  -sdk watchsimulator26.5 -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

---

## Project layout

```
DepthDiver/
├─ DepthDiver.xcodeproj
└─ DepthDiverWatchApp/
   ├─ DepthDiverApp.swift     # @main entry, owns the GameEngine
   ├─ ContentView.swift       # phase router (menu / play / game over) + backdrop
   ├─ MenuView.swift          # title screen + best score + DIVE button
   ├─ GamePlayView.swift      # Canvas host: game loop + Crown + tap-to-dash
   ├─ GameOverView.swift      # result screen, replay / home
   ├─ GameEngine.swift        # the whole simulation (movement, spawns, oxygen,
   │                          #   collisions, boss, scoring, persistence)
   ├─ DepthRenderer.swift     # stateless drawing of every frame into the Canvas
   ├─ Models.swift            # entity structs + small math helpers
   ├─ Haptics.swift           # Taptic Engine wrapper (feedback by intent)
   └─ Assets.xcassets         # app icon + accent color
```

## Tuning

Almost every knob lives at the top of **`GameEngine.swift`** (player size,
descent curve, oxygen drain, boss interval) and in `spawnObstacle` /
`obstacleKind` (hazard sizes, depth thresholds for new enemy types). The look —
colours, the diver, creatures, HUD — is all in **`DepthRenderer.swift`**.

## Notes on the Ultra's Action Button

watchOS doesn't expose the Action Button as a general in-game button to
third-party apps, so it isn't a gameplay control here. You *can* assign it to
**launch Depth Diver** from anywhere via *Settings ▸ Action Button ▸ Shortcut*,
which makes for a great one-press "start diving."
