# SwiftUI vs UIKit Performance Stress Feed - Spec

This spec defines a single-screen app with a highly layered, animation-heavy feed. The UI must be pixel-identical between UIKit and SwiftUI. All values below are required unless explicitly marked as optional.

## Goals
- Stress scroll and rendering performance with heavy imagery, animated GIFs, and continuous per-cell animations.
- Ensure UIKit and SwiftUI implementations look and behave identically.
- Keep data fully deterministic so both apps can render the same layout from the same inputs.

## Non-goals
- No navigation beyond the feed screen.
- No persistence beyond in-memory state for the current run.
- No remote networking; pagination is simulated.

## Assets
- Wallpapers live in `/wallpapers` and are bundled in the app.
- GIFs live in `/gifs` and are bundled in the app.
- At runtime, enumerate wallpaper files and gif files from the app bundle, then sort by numeric filename (ascending). Example: `1.jpg`, `2.png`, `3.jpg` sorts as 1, 2, 3.
- Wallpaper index and GIF index refer to this sorted order (1-based).

## Deterministic randomization
All "random" values must be deterministic and derived from the item id so UIKit and SwiftUI render identical results.

Use this 32-bit LCG:
```
seed = (itemID * 1664525 + 1013904223) & 0xFFFFFFFF
func nextFloat() -> Float {
  seed = (1664525 * seed + 1013904223) & 0xFFFFFFFF
  return Float(seed % 10000) / 10000.0
}
```

## Data model
All data is hard-coded and generated at launch.

```
struct FeedItem {
  id: Int
  wallpaperIndex: Int
  title: String            // "Wallpaper 0001"
  subtitle: String         // "ID 0001 • 3 stickers • 198pt"
  height: CGFloat          // 150-250, deterministic
  badges: [String]         // ["FEED", "LIVE"]
  stats: (cpu: Int, gpu: Int) // 0-100, deterministic
  stickers: [Sticker]
}

struct Sticker {
  id: Int
  gifIndex: Int
  centerUnit: CGPoint      // normalized 0-1 in the "sticker safe rect"
  baseSize: CGSize         // pt, before interactive scaling
  rotation: CGFloat        // degrees
  scale: CGFloat           // 0.75-1.35
}
```

### FeedItem generation rules
- Total items: 1000.
- `wallpaperIndex = ((id - 1) % wallpaperCount) + 1`.
- Height formula: `height = 150 + ((id * 37) % 101)` (range 150-250).
- `title = "Wallpaper " + id formatted to 4 digits`.
- Sticker count: `count = 3 + Int(nextFloat() * 4)` (3-6).
- `stats.cpu = Int(nextFloat() * 101)`; `stats.gpu = Int(nextFloat() * 101)`.
- `badges` always `["FEED", "LIVE"]`.

### Sticker generation rules
For each sticker `i` in `0..<count`:
- `gifIndex = Int(nextFloat() * Float(gifCount)) + 1` (allow duplicates).
- `baseSize = 44 + nextFloat() * 86` for width; height = width.
- `rotation = (nextFloat() * 24) - 12` (degrees).
- `scale = 0.75 + nextFloat() * 0.60`.
- `centerUnit.x = 0.10 + nextFloat() * 0.80`.
- `centerUnit.y = 0.10 + nextFloat() * 0.80`.

## Fake pagination
- Page size: 30.
- Prefetch threshold: when the user scrolls within 8 items of the end, load the next page.
- Simulated delay: 300 ms before append.
- Stop after 1000 items (no wrapping).

## Screen layout (global)
- Single screen with a vertically scrolling feed.
- Background: vertical gradient from `#0B0B0B` (top) to `#141414` (bottom).
- The feed uses automatic safe-area/nav-bar inset adjustment so the first item starts below the nav bar.
- Content insets: top 12, bottom 24, left 8, right 8 (in addition to system insets).
- Inter-item spacing: 12.
- Scroll indicators: visible.

## Navigation bar (global)
- Use a standard `UINavigationBar` (not a custom overlay).
- Large title style that collapses to a compact title on scroll.
- Title: "UIKitPerformance".
- Transparent background; no solid fill.
- Add a top-to-bottom black gradient behind the bar:
  - Top color: `#000000` alpha 0.60.
  - Bottom color: `#000000` alpha 0.00.
  - Gradient height = status bar + nav bar height.
- Title text: system semibold 17, `#FFFFFF` alpha 0.95.
- Large title text: system bold 34, `#FFFFFF` alpha 0.95.

## Global stats toolbar
- Floating pill at the bottom-center.
- Size: 220x44, corner radius 22.
- Background: `#000000` alpha 0.55.
- Border: 1 pt `#FFFFFF` alpha 0.12.
- Text: "CPU 42%" and "GPU 68%" (from the top-most visible item).
- Font: monospaced semibold 12, `#FFFFFF` alpha 0.95.
- Bottom offset: 16 from bottom edge.

## Cell layout
Each cell is full width minus horizontal insets, variable height (150-250).

### Cell container
- Corner radius: 18.
- Clip content to bounds: yes.
- Outer shadow (on wrapper view, not clipped):
  - Color: `#000000`, alpha 0.35
  - Blur radius: 12
  - Offset: (0, 6)

### Background image
- Use `wallpaperIndex` image.
- Content mode: aspect fill.
- Center-crop (no letterboxing).

### Vignette overlays
- Top gradient: `#000000` alpha 0.25 at y=0 to alpha 0.0 at y=0.25*height.
- Bottom gradient: fixed 140 pt height pinned to bottom.
  - Start at top of the gradient: `#000000` alpha 0.0.
  - End at bottom: `#000000` alpha 0.75.

### Inner border
- 1 pt stroke, inset by 1 pt from the cell edge.
- Color: `#FFFFFF`, alpha 0.10.

### Badges (top-left)
- Two pill badges: "FEED", "LIVE".
- Badge height: 24.
- Horizontal padding: 10.
- Corner radius: 12.
- Background: `#000000`, alpha 0.35.
- Border: 1 pt `#FFFFFF`, alpha 0.18.
- Font: system semibold 11.
- Text color: `#FFFFFF`, alpha 0.95.
- Placement: top-left, inset 12 from top and left; gap 6 between pills.

### Title block (bottom-left)
- Title: `title` (e.g., "Wallpaper 0001").
  - Font: system semibold 18.
  - Color: `#FFFFFF`, alpha 1.0.
- Subtitle: `subtitle` (e.g., "ID 0001 • 3 stickers • 198pt").
  - Font: system regular 12.
  - Color: `#FFFFFF`, alpha 0.80.
- Vertical spacing: 4.
- Placement: bottom-left, inset 12 from left and 12 from bottom.

### Animated glow (perimeter)
Two trailing gradient lines animate clockwise along the inside edge, offset by 180 degrees (no dot heads).
- Path: rounded rect inset by 3 pt from the cell edge, same 18 pt radius.
- Tail: 52 pt long, 6 pt wide gradient fading to transparent.
  - Head color: palette color, alpha 0.45.
  - Tail color: palette color, alpha 0.0.
- Duration: 6.0 seconds per loop.
- Timing: linear, infinite.
- Color palette: pick a single color per cell from a fixed palette (deterministic by item id).
- Palette order:
  - systemRed, systemOrange, systemYellow, systemGreen, systemMint, systemTeal,
    systemCyan, systemBlue, systemIndigo, systemPurple, systemPink, systemBrown,
    #FF6B6B, #FFD93D, #6BCB77, #4D96FF, #845EC2, #F9A826, #00C9A7, #2C73D2,
    #FF9671, #C34A36, #00A8CC, #9BDEAC.
- Z order: above image and gradients, below stickers and text.

## Sticker GIFs
Sticker GIFs autoplay, loop, and are interactive.

### Placement and sizing
- Sticker safe rect: cell bounds inset by 16 on left/right, 52 from top, 72 from bottom.
- Convert `centerUnit` into a point inside the safe rect.
- Use `baseSize` as the initial size, then apply `scale` and `rotation`.
- Stickers render above the background/gradients and above the glow, but below text.

### Sticker styling
- Optional container drop shadow:
  - Color: `#000000`, alpha 0.25
  - Blur radius: 8
  - Offset: (0, 4)
- Optional 1 pt border: `#FFFFFF`, alpha 0.15.

### Sticker interaction (all enabled)
- Pan (1 finger): translate the sticker.
- Pinch (2 fingers): scale.
- Rotation (2 fingers): rotate.
- Gestures can be simultaneous.
- On gesture begin: bring the sticker to front within its cell.
- On gesture end: write updated `centerUnit`, `scale`, and `rotation` back to the model.
- While a sticker gesture is active, the feed scroll gesture must yield (sticker gestures take precedence).

## Deletion zone
Deleting a sticker is done by dragging it into the bottom-right "trash" corner.

- Zone frame: 72x72, anchored to bottom-right of the cell.
- Default state: hidden (alpha 0.0).
- When any sticker is being dragged:
  - Show a red gradient wedge from bottom-right corner:
    - Color: `#FF2D2D`, alpha 0.85 at the corner.
    - Fade to transparent at a 72 pt diagonal.
- When a sticker's center enters the zone:
  - Zone fill brightens to alpha 1.0.
  - Sticker scales to 0.9 and reduces alpha to 0.8.
- On release inside zone: delete the sticker from the model.

## State and observation
- Use `@Observable` view model for both UIKit and SwiftUI.
- All sticker transforms are stored in the model (not ephemeral UI state).
- When a sticker moves, the model updates and the cell re-renders from the model.

## Reuse and lifecycle
- Start GIF playback and glow animation when a cell becomes visible.
- Pause/stop playback and glow when a cell leaves the screen or is reused.
- Apply the model state on reuse (no reset to defaults).

## Parity rules
- Use the exact same constants and deterministic generator in both projects.
- Use the same asset ordering rules in both projects.
- No platform-specific visual tweaks.
- All measurements are in points; do not apply platform-specific scaling hacks.
