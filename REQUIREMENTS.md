# NWT Scroller — Requirements

## Overview

NWT Scroller is an Android overlay application built with Flutter that provides quick Bible book/chapter/verse navigation via a floating compass rose UI. The overlay runs as a system overlay (`TYPE_APPLICATION_OVERLAY`) above all other apps, allowing users to jump to any Bible reference in the JW Library app without leaving their current screen.

---

## Functional Requirements

### FR-1: Overlay Lifecycle

- Launching the app auto-starts the overlay in its collapsed state. There is no manual "Start Overlay" button.
- The overlay requires `SYSTEM_ALERT_WINDOW` permission; the app requests it on launch and auto-starts the overlay once granted.
- The overlay runs in a separate Flutter engine entry point (`overlayMain()`), independent of the main app's lifecycle.
- The main app shows a "Close App" button; closing the app does NOT stop the overlay — it continues running.
- The main app serves as the configuration page, opened by tapping the right compass knob in the expanded overlay.

### FR-2: Collapsed State (Compass Rose)

- When collapsed, the overlay displays a full compass rose SVG icon.
- The collapsed size is derived from the formula: `(fontSize × 1.1 × 3.0 × overlayScale)`, clamped to `[36, 96]` pixels.
- The collapsed overlay is draggable via the OS-level drag flag (`enableDrag: true`).
- Tapping the collapsed compass expands it into the navigation bar.
- A tap-vs-drag disambiguator prevents accidental expansion when the user drags and releases in roughly the same spot.

### FR-3: Expanded State (Navigation Bar)

- When expanded, the overlay becomes a horizontal bar with:
  - **Left handle**: left half of the compass rose SVG.
  - **Center tube**: three scroll-wheel pickers (Book, Chapter:Verse).
  - **Right handle**: right half of the compass rose SVG.
- The expanded bar height must be `5/3 × collapsedSize` to show approximately 5 picker rows above and below the selected item.
- The expanded bar width is computed dynamically based on font size, overlay scale, name length setting, and screen width (capped at 90% of screen width).
- OS-level drag is disabled when expanded; custom drag via the left handle replaces it.

### FR-4: Scroll Wheel Pickers

- **Book picker**: scrolls through all 66 Bible books. Displays short (3-char), medium (7-char), or long (full name) labels based on the Name Length setting.
- **Chapter picker**: shows chapters 1–N for the selected book. Resets to chapter 1 when the book changes.
- **Verse picker**: shows verses 1–N for the selected book+chapter. Resets to verse 1 when the book or chapter changes.
- Pickers use `CupertinoPicker` with `diameterRatio: 1.8` and `squeeze: 0.9` to show multiple items above and below the selection.
- A fade gradient (shader mask) makes edge items progressively transparent, with the center selection fully opaque.
- **Only the center selection row** has a visible background highlight. The rows above and below the selection must have no background — they show text only (faded) over transparency.
- Each picker provides haptic feedback on scroll and a distinct haptic on tap.
- Tapping a picker item launches the corresponding reference:
  - Book tap → opens the book's landing page.
  - Chapter tap → opens that chapter.
  - Verse tap → opens the specific verse and saves it to history.

### FR-5: Collapse Behavior

- Tapping the left handle collapses the bar back to the compass rose.
- On collapse, the compass must appear at the **left handle's position** (not a saved pre-expansion position). Specifically: the collapsed compass's left edge aligns with the expanded bar's left edge, and it is vertically centered relative to the expanded bar's height.
- The collapse sequence is: fade-out animation → move to target position → resize to collapsed size. This prevents a visible frame of the small compass at the wrong location.

### FR-6: Expand Positioning

- When expanding, the bar position is determined by which third of the screen the collapsed compass occupies:
  - Left third: bar's left edge aligns with compass's left edge.
  - Center third: bar is centered on the compass's center.
  - Right third: bar's right edge aligns with compass's right edge.
- The bar is clamped to stay fully within screen bounds.

### FR-7: Drag (Expanded State)

- The left handle supports drag-to-move when the overlay is expanded.
- Drag uses raw `Listener` (not `GestureDetector`) to avoid gesture arena delays.
- Drag must compensate for the overlay coordinate system shift: as the overlay window moves, pointer event positions shift in the opposite direction. The implementation tracks accumulated displacement and adds it back to pointer deltas to produce stable screen-space movement.
- An 8-pixel activation threshold distinguishes drag from tap.
- Move calls are throttled (fire-and-queue) to prevent flooding the platform channel.
- Swipe up on the left handle toggles the history popup.

### FR-8: History

- Each successful verse-level launch is recorded with a timestamp.
- History entries are persisted to local storage via `HistoryRepository`.
- A popup, triggered by swiping up on the left handle, shows recent entries.
- Tapping a history entry re-launches that reference.

### FR-9: Right Knob — Open Configuration

- Tapping the right handle in the expanded overlay opens the main app's configuration page (brings the app to the foreground via `openMainApp` platform channel).
- The main app provides the full settings UI: name length, overlay scale, font size, haptic feedback, haptic intensity, and theme.
- Settings changes apply immediately and are pushed to the overlay via `shareData`.

### FR-10: Configuration Propagation

- The main app has a full settings UI with additional controls (overlay scale slider, font size slider).
- Config is saved to `SharedPreferences` and pushed to the overlay via `FlutterOverlayWindow.shareData()`.
- The overlay listens for config messages and applies changes live (theme, haptics, sizing).

### FR-11: Bible Reference Launching

- `LauncherService` constructs JW Library deep-link URLs and launches them via `url_launcher`.
- Three levels: book, chapter, verse — each with a different URL pattern.
- Launch failures are handled gracefully (no crash).

---

## Non-Functional Requirements

### NFR-1: Overlay Positioning Reliability

- The overlay must always appear on-screen when first shown.
- `ScreenService.getScreenSize()` is unreliable in the overlay engine context (returns the overlay window size instead of device screen size). Therefore, initial positioning must be performed from the main app side, where the Display API returns correct values.
- Bounds validation: positions must be clamped so the overlay is never placed off-screen.

### NFR-2: Sizing Consistency

- The overlay size must be driven exclusively by the `compassSize()` formula and remain consistent across collapsed → expanded → re-collapsed transitions.
- The formula `(fontSize × 1.1 × 3.0 × overlayScale).round().clamp(36, 96)` is the single source of truth.
- Handle width = `compassSize / 2` (each half-SVG is exactly half the compass).

### NFR-3: Smooth Drag (No Jitter or Amplification)

- Custom drag in the expanded state must not jitter, oscillate, or amplify movement.
- The coordinate feedback loop (overlay moves → pointer coordinates shift → computed delta is wrong) is solved by re-anchoring `_dragStartOverlay` to the completed move position after each move, while keeping the pointer start position frozen. This avoids both jitter (from the original approach) and amplification (from displacement compensation).
- The overlay must NEVER exit the visible screen area during drag. Positions are clamped to `[0, screenWidth - overlayWidth]` horizontally and `[0, screenHeight - overlayHeight]` vertically.
- On screen rotation, the overlay must adjust to stay within the new screen bounds.
- Screen dimensions are passed from the main app to the overlay via config, since `ScreenService` is unreliable in the overlay engine.

### NFR-4: Visual Design — Compass Rose SVG

- The compass rose has a 48×48 viewBox with center at (24, 24).
- Cardinal point tips extend to r=22 from center.
- Ordinal point tips extend to approximately r=15.6 from center.
- **Outer circle ring** is positioned at r=19 (75% of the distance from the center boss at r=3.5 to the viewBox edge at r=24). The ring must not touch or intersect the compass point tips.
- Inner circle at r=8.
- Center boss at r=3.5 with a specular highlight.
- 3D appearance via split lit/shadow faces on each compass point with linear gradients simulating a top-left light source.
- 8 tick marks straddle the outer ring at cardinal and ordinal positions.
- The compass is split into left and right halves via `clipPath` for the expanded bar handles.

### NFR-5: Theming

- Two themes: **Parchment** (warm, light) and **Silver** (cool, dark).
- Themes define: background, text primary/secondary, divider, picker highlight, and knob tint colors.
- Theme changes apply instantly without overlay restart.

### NFR-6: Haptic Feedback

- Uses a custom `nwt_vibration` plugin wrapping Android's `VibrationEffect` API.
- Three intensity levels: light (20ms/40amp), medium (35ms/120amp), heavy (50ms/200amp).
- Tick feedback on scroll, selection click on tap.
- Can be fully disabled via settings.

### NFR-7: Performance

- The overlay must be lightweight — minimal memory and CPU usage since it runs persistently.
- Animation controller uses 350ms ease-out-cubic for expand, 250ms ease-in-cubic for collapse.
- Move calls during drag are throttled to prevent platform channel congestion.

---

## Technical Constraints

- **Platform**: Android only (uses `flutter_overlay_window` which is Android-specific).
- **Min SDK**: Android API 26+ (required for `TYPE_APPLICATION_OVERLAY`).
- **Flutter**: Uses separate engine entry points — `main()` for the app, `overlayMain()` for the overlay.
- **State isolation**: The overlay engine has no shared memory with the main app; all communication is via `FlutterOverlayWindow.shareData()` / `overlayListener`.
- **Coordinate system**: In the overlay engine, `PlatformDispatcher.instance.views.first` returns the overlay window dimensions, not the device screen. The `displays` API may also be unreliable. Screen-dependent calculations must use values passed from the main app.
