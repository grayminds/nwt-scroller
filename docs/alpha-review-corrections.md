# Alpha review corrections -- work order

Date:  2026-07-14.  Source:  full alpha-release review (code-reviewer sweep of `lib/` plus the vendored `flutter_overlay_window` plugin, and a UI/UX design review of both surfaces).  This document is self-contained; the implementing session needs no prior conversation context.

## Implementation status (2026-07-14)

All 36 items (Groups 1 through 5) are code-complete and checked off below.  `flutter analyze` is clean against the pre-existing baseline (the only remaining analyzer output is vendored-plugin example noise that predates this work), and `flutter test` is green at 22 passing.  Two decision-required items were resolved per the review's own recommendation:  2.1 removed the unreachable swipe gesture, and 2.2 cut the overlay history popup for v1 (history stays in the config app).

On-device verification is still pending and cannot be done off-device:  the Group 1 ten-cold-launch check and all native Java changes (Groups 1 and 3) need a build on the Samsung S24 Ultra.  Two seams to watch on device:  the `screenSize` rotation message routes over `WindowSetup.messenger` (2.5) and may need to move to the overlay-engine channel if it does not arrive, and the `ready` handshake (1.6) relies on the 3.1 broadcast-controller fix delivering overlay-to-main messages.

## Context

nwt-scroller is a Flutter Android overlay app (floating compass-rose Bible navigator that deep-links into JW Library).  The reported release blocker:  the app must be launched 2-3 times before the overlay appears on screen.  The review traced that to a stack of four converging bugs (Group 1 below) and produced a broader corrections list, ordered by priority.

## Ground rules for the implementing session

- Read `CLAUDE.md` and `REQUIREMENTS.md` at the repo root first.  `REQUIREMENTS.md` is authoritative for sizing, drag, and collapse math; do not re-derive it.
- The plugins in `plugins/` are intentionally patched local copies.  Edit them in place; never swap for pub.dev versions.
- Overlay behavior only exists on Android.  `flutter analyze` and `flutter test` must be clean before any commit; on-device verification needs a real device (primary:  Samsung S24 Ultra, Android 16).
- Widgets must not call `FlutterOverlayWindow` directly; go through `lib/services/overlay_service.dart`.
- All prose (comments, docs, commit messages):  two spaces between sentences, Oxford comma, active voice, no em dashes, no emoji.
- Work the groups in order.  Group 1 alone should make launch deterministic; verify on device before moving on.

## Group 1 -- launch reliability (critical, do first)

- [x] **1.1  Remove the `stopSelf()` self-destruct in `onStartCommand`.**
  `plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java:148-153`.
  A second `startService` enters the `windowManager != null` branch:  `removeView` + `stopSelf()`, then falls through and builds a new view anyway.  `stopSelf()` schedules teardown when `onStartCommand` returns, so `onDestroy` removes the view that was just added.  The overlay flashes and vanishes.  Fix:  delete the `stopSelf()` call.  Clean up the prior view, null the fields, and continue building the new one.

- [x] **1.2  Guard against the double-start race in the main app.**
  `lib/main.dart`.  `_initAndAutoStart()` (from `initState`, line 81) and `_checkPermissionAndStart()` (from `didChangeAppLifecycleState(resumed)`, line 105) both call `_startOverlay()` with no mutex, producing the double `startService` that triggers 1.1.  The Grant Permission button path (lines 271-276) is a third entrant.  Fix:  add a `bool _startingOverlay` guard so a second entrant returns early; clear it when the start completes or fails.

- [x] **1.3  Fix the dp/px unit bug on first render.**
  `OverlayService.java:196-197`.  `WindowSetup.width`/`height` arrive in dp from Dart but go into `WindowManager.LayoutParams` as raw pixels.  On a ~3.5x density device the initial window is a 30-70 physical-pixel sliver.  Fix:  `WindowSetup.width == -1999 ? -1 : dpToPx(WindowSetup.width)`, and the same for height, minding `MATCH_PARENT` (-1).

- [x] **1.4  Fix the double-scaled fallback y position.**
  `OverlayService.java:194, 213`.  `dy = -statusBarHeightPx()` is already pixels, but `moveOverlay(dx, dy, null)` applies `dpToPx` again, parking the fallback position off-screen top.  Fix:  divide by density before passing, or add a raw-pixel overload for internal callers.

- [x] **1.5  Complete the Dart result in `closeOverlay` when the service is not running.**
  `plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/FlutterOverlayWindowPlugin.java:132-138`.
  When `isRunning` is false the handler returns without calling `result.*`, so the awaited Dart future hangs forever.  `_closeApp` in `lib/main.dart:188-193` awaits it before `SystemNavigator.pop()`, so the app can fail to close.  Fix:  `result.success(false)` before the early return.

- [x] **1.6  Replace the 500 ms delayed config push with a ready handshake.**
  `lib/main.dart:184-186` pushes config on a fixed `Future.delayed`.  `showOverlay` also resolves before the window exists (`FlutterOverlayWindowPlugin.java:110-111`), so the `setDefaultPosition` call in `_startOverlay` can silently no-op against a null service instance.  Fix:  pass the initial position via the `startPosition` parameter of `FlutterOverlayWindow.showOverlay` instead of a post-hoc move, and have `_ScrollOverlayState._init` (`lib/widgets/scroll_overlay.dart:84-113`) send `{type: 'ready'}` over `shareData` when it finishes loading; `main.dart` pushes config on receipt of that message (keep a generous timeout fallback).

Verification for Group 1:  cold-launch the app 10 times in a row on device (kill the app and service between runs).  The overlay must appear at the expected default position, at the correct size, all 10 times.

## Group 2 -- overlay correctness (high)

- [x] **2.1  Fix or remove the unreachable swipe-up history gesture.**
  `lib/widgets/left_handle.dart:43-49`.  The outer guard requires total displacement `dist < 15`, but the swipe branch requires `dy < -30`; since `dist >= |dy|`, the swipe branch can never execute.  FR-8's history popup is unreachable, and nothing else calls `_toggleHistory`.
  Decision required with 2.2:  fix the gesture (check `dy < -30 && dx.abs() < 20` before the dist guard, treat `dist < 15` as tap) or remove the gesture and the overlay popup path deliberately, keeping history in the config app only.

- [x] **2.2  Resolve the history popup window clipping.**
  `lib/widgets/expanded_scroll.dart:257-267` positions a 220 x up-to-300 px popup above a bar whose Android window is only about 83 px tall at defaults.  Flutter cannot draw outside the OS window; the popup would clip as soon as 2.1 is fixed.  Either resize the overlay window when the popup opens (and restore on close), or cut the popup and rely on the config app History tab.  Recommendation from the review:  cut it for v1.

- [x] **2.3  Raise the opacity floor.**
  `lib/services/config_service.dart` clamps `overlayOpacity` to `[0.1, 1.0]`, and the selection-row background multiplies theme background by it (`lib/widgets/expanded_scroll.dart:363`).  At 10 percent the selected verse is unreadable over light apps.  Fix:  raise the floor to 0.4 in `config_service.dart` (both the clamp in `load`/setter and `applyFromMap`) and in the slider min at `lib/main.dart:517`, or exempt the selection-row background from the slider.

- [x] **2.4  Clamp config values in `applyFromMap`.**
  `lib/services/config_service.dart:112-119`.  `load()` clamps `overlayScale`, `fontSize`, `widthScale`, `heightScale`, and `selectionBarHeight`; the map-based apply does not, so a stale or corrupted push can render the overlay with unbounded sizes.  Apply the same `.clamp()` ranges.

- [x] **2.5  Push screen size from native on rotation.**
  The overlay keeps stale screen dimensions if the device rotates while the config app is closed.  `OverlayService.onConfigurationChanged` already refreshes `szWindow`; send `{type: 'screenSize', w, h}` over `WindowSetup.messenger`, and on the overlay Dart side apply it to `_config.screenWidth`/`Height` and re-run `_resizeExpanded` if expanded.

## Group 3 -- plugin hardening (high)

- [x] **3.1  `StreamController.broadcast()` and one-time handler registration.**
  `plugins/flutter_overlay_window/lib/src/overlay_window.dart:11, 104-110`.  The controller is single-subscription (a second `listen` throws), and every `overlayListener` access re-registers the message handler.  Fix:  broadcast controller, register the handler once behind a bool guard.

- [x] **3.2  Dedicated `pendingPermissionResult`.**
  `FlutterOverlayWindowPlugin.java:65, 194-198`.  `pendingResult = result` runs for every method call, so any channel traffic between the permission dialog opening and `onActivityResult` strands the earlier result.  Fix:  a dedicated field set only in the `requestPermission` branch, null-checked in `onActivityResult`.

- [x] **3.3  Lazy engine creation.**
  `FlutterOverlayWindowPlugin.java:154-161`.  The overlay engine spins up on every activity attach, before permission is granted, costing cold-start latency, roughly 15-25 MB, and battery.  Fix:  create the engine on first `showOverlay` when the cache is empty.  Note the interaction with `OverlayService.onCreate`'s fallback engine creation; keep that fallback.

- [x] **3.4  `stopForeground` in `onDestroy`.**
  `OverlayService.java:87-101`.  Call `stopForeground(STOP_FOREGROUND_REMOVE)` before (or instead of) `NotificationManager.cancel` to avoid zombie elevated processes and FGS ANRs.

- [x] **3.5  Cancel tray animation timers.**
  `OverlayService.java:66, 72-73, 450-452, 506-545`.  Each `ACTION_UP` schedules a new `Timer` without cancelling the in-flight one, and nothing cancels in `onDestroy`.  Fix:  cancel before scheduling, and cancel again in `onDestroy`.

- [x] **3.6  Notification channel importance `IMPORTANCE_LOW`.**
  `OverlayService.java:386`.  `IMPORTANCE_DEFAULT` pings audibly and shows a heads-up card for a persistent overlay notification.  Also add `.setOnlyAlertOnce(true)` on the builder.

- [x] **3.7  Fix the tautological `resizeOverlay` height gate.**
  `OverlayService.java:281`.  `(height != 1999 || height != -1)` is always true, and `-1` (MATCH_PARENT) gets converted through `dpToPx`.  Fix:  `params.height = (height == -1999 || height == -1) ? height : dpToPx(height);`, matching the width line.

- [x] **3.8  Null-guard the engine in `onStartCommand`.**
  `OverlayService.java:156-157`.  If the engine cache is empty and the `onCreate` fallback failed, `engine.getLifecycleChannel()` NPEs.  Fix:  null-guard, log, `stopSelf()`, return `START_NOT_STICKY`.

- [x] **3.9  Null-guard unboxed channel args.**
  `FlutterOverlayWindowPlugin.java:88, 119-120, 125-127` and `OverlayService.java:169-176`.  Autounboxed `call.argument(...)` values NPE on null.  Guard or default each.

- [x] **3.10  Remove dead code.**
  Duplicate `isOverlayActive` branch (`FlutterOverlayWindowPlugin.java:115-117`), unused `showWhenLocked` shim (`WindowSetup.java:50-61`).

- [x] **3.11  `volatile` on custom-drag statics.**
  `OverlayService.java:76-77`.  Written from the binder thread, read from the UI thread with no visibility guarantee.  Mark `volatile`.

- [x] **3.12  `requestPermission` null-activity guard.**
  `FlutterOverlayWindowPlugin.java:69-72`.  `result.error("NO_ACTIVITY", ...)` when `mActivity == null`.

## Group 4 -- config app pass (medium)

- [x] **4.1  Debounce slider persistence.**
  `lib/main.dart:204-208`.  `_updateConfig` writes SharedPreferences and pushes config on every slider tick (20-60 per second).  Fix:  keep `setState` and the live overlay push in `onChanged` if desired, but move `_config.save()` to `onChangeEnd` or a 250 ms trailing debounce.  Both reviews flagged this independently.

- [x] **4.2  Replace chip `GestureDetector`s with `ChoiceChip`.**
  `lib/main.dart` theme, name length, haptic intensity, and interaction style rows (lines 462, 539, 697, 728 vicinity).  One change fixes 48 dp touch targets, press feedback, and TalkBack role and selection semantics.

- [x] **4.3  Consume the Material 3 `ColorScheme`.**
  `lib/main.dart:46` defines `ColorScheme.fromSeed(0xFF8B4513)` and never uses it; the same five hex literals repeat 20-plus times.  Seed the scheme from the parchment palette and consume `Theme.of(context)`, removing the passed-around `brown`/`brownLight` parameters.

- [x] **4.4  Rename "Style 1 / Style 2".**
  `lib/main.dart:530-566`.  Give the interaction styles descriptive names (for example "Full wheel" and "Minimal fade") and a one-line description.

- [x] **4.5  Rename ambiguous sliders.**
  "Width scale," "Height scale," and "Bar height" toward "Bar width," "Wheel height," and "Selection row height."

- [x] **4.6  Reduce redundant `SharedPreferences.reload()`.**
  `lib/services/config_service.dart:46` and `lib/data/history_repository.dart:13` force a full disk re-read on every load.  Reload once per engine cold start; keep an explicit reload only where cross-engine synchronization genuinely requires it.

- [x] **4.7  Fix `FixedExtentScrollController` dispose-recreate.**
  `lib/widgets/expanded_scroll.dart:124-152`.  Disposing mid-scroll drops ballistic physics and can snap visibly.  Prefer `jumpToItem(0)`, or defer recreation to a post-frame callback.

- [x] **4.8  Enum-ify `theme` and `interactionStyle`.**
  `lib/services/config_service.dart` and `lib/widgets/scroll_overlay.dart:127-135`.  Parse to enums on load, serialize `.name`, and make `_resolveTheme` loud on unknown values.

## Group 5 -- theme and interaction polish (medium)

- [x] **5.1  Contrast fixes for `textSecondary`.**
  Parchment #8B6F47 measures 3.4-3.8:1 (fails AA); darken toward #75552E.  Blue #D0DFEF measures 3.84:1; lighten toward #E2ECF7.  Silver passes as-is.  Files:  `lib/theme/parchment_theme.dart`, `lib/theme/blue_theme.dart`.

- [x] **5.2  Differentiate the right handle.**
  `lib/widgets/right_handle.dart`.  Left and right handles are identical mirror halves but do opposite things (collapse vs launch the config app).  Accent-tint the right knob or overlay a faint gear glyph at low alpha.

- [x] **5.3  Widen handle hit areas and raise the collapsed floor.**
  Transparent padding inside the existing `Listener` regions in `left_handle.dart` and `right_handle.dart`; raise the collapsed size floor from 24 to 36 in `lib/services/overlay_service.dart:20`.

- [x] **5.4  Loosen or drop the tap time gates.**
  `left_handle.dart:43` and the three pickers (`book_picker.dart:48` and siblings) reject taps slower than 350-400 ms.  Loosen to about 500 ms or rely on the distance threshold alone.

- [x] **5.5  Release signing config.**
  `android/app/build.gradle.kts:33-39` still signs release with debug keys (existing TODO).  Define a release signing config; keep the keystore out of the repo (extend `.gitignore` if needed).

## Deferred (low, note and move on)

- Tabular figures (`FontFeature.tabularFigures()`) in chapter and verse pickers.
- History delete undo via `SnackBar`; raise 11 px timestamps to 12 px; 44 dp close target in `history_popup.dart`.
- Remove or use the dead `pickerHighlight` token in all three themes.
- Unify drag thresholds to one constant matching FR-7's 8 px (plugin currently uses squared 25 and 64).
- `HapticService.tick` allocation (use `millisecondsSinceEpoch` int math).
- Scheme allowlist in `NwtVibrationPlugin.launchUrl` (jwlibrary, http, https).
- `onDetachedFromEngine` does not null `WindowSetup.messenger` (latent leak on repeated attach cycles).
- Extract the duplicated tap-vs-scroll `Listener` logic in the three pickers into a shared wrapper.
- Config page does not follow the selected overlay theme; either restyle from `ScrollTheme` or mark the theme control as overlay-only.
- Collapse-on-outside-tap if the patched plugin can expose outside-touch events.
- `_cachePosition` staleness in `collapsed_scroll.dart:24-55` (tap-vs-drag guard uses init-time position).

## Testing expectations

- Add a widget or unit test around the `_startOverlay` guard (1.2):  two rapid triggers must produce at most one start.
- Add tests for `ConfigService.applyFromMap` clamping (2.4).
- `flutter analyze` clean and `flutter test` green before every commit.
- On-device pass after Group 1 (the 10-cold-launch check) and again after Groups 2-3:  expand, collapse, drag, rotate, theme switch, verse launch into JW Library, and close-app from the config page.

## Explicitly not problems (do not "fix")

- The compass sizing formula and `collapsedDisplaySize` math (spec-mandated, NFR-2).
- Fade-to-transparent unselected rows (FR-4).
- The 350/250 ms expand/collapse animation timings.
- Raw `Listener` instead of `GestureDetector` for drag paths.
- Whole-column picker tap surfaces despite small row heights.
