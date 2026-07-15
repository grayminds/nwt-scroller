# Next session -- nwt-scroller

> Protocol:  at session open, move the block below into an `## Archive` section at the
> bottom of this file (or `docs/session-history.md` once it exists), dated.  Do the work.
> Rewrite the block with your own Goal / Constraints / Acceptance criteria.  Commit the
> handoff with the session's changes.

## Goal

Final hands-on validation and low-priority cleanup.  Everything through the 2026-07-14
alpha review, plus three follow-up features, is implemented, built on the Samsung S24
Ultra, and pushed to both remotes.  What remains is Michael's real-finger validation and
any tuning it surfaces, then the deferred low-priority polish.

Validation checklist (real device, real apps over the top):

1. **Drag-to-dismiss feel (FR-12).**  Drag the collapsed compass;  confirm the X target
   fades in at bottom center, enlarges and turns red when the finger is over it, closes
   the overlay on release over it, and snaps back to the edge when released elsewhere.
   Tuning knobs if it feels off, all in `OverlayService.showCloseZone`:  64 dp circle,
   96 dp bottom margin, 1.8x magnet radius.  This session verified it structurally (a
   simulated drag onto the zone added the close-zone window and tore down the service),
   not by hand.
2. **Group 1 launch reliability, visually.**  Ten cold launches;  the overlay must appear
   at the right size and position every time.  Structurally verified this session:  ten
   launches produced exactly ten clean overlay starts, no flash-and-vanish, window at
   112x112 (not the old sliver).
3. **Full interaction regression.**  Expand, collapse, drag expanded, rotate (watch the
   2.5 screenSize reflow and the 1.6 ready handshake), switch all three themes, launch a
   verse into JW Library, and Close App from the config page (1.5 closeOverlay fix).
4. **Config screen.**  Confirm the segmented rows, section headers, and brown selected
   state read well.  Optionally apply the deferred "Bible: NWT reads as a disabled input"
   fix (proposed this session, not selected -- restyle it as a static label).

Then work the **deferred low-priority list** at the bottom of
`docs/alpha-review-corrections.md` (tabular figures in the pickers, unify drag thresholds
to FR-7's 8 px, `HapticService.tick` int math, scheme allowlist in
`NwtVibrationPlugin.launchUrl`, `onDetachedFromEngine` messenger null-out, config page
following the overlay theme, collapse-on-outside-tap, `_cachePosition` staleness) as time
allows.

## Constraints

- Native Java is only compile-checked by a device build;  `flutter analyze` is Dart only.
  Rebuild the APK after any plugin change before trusting it.
- Vendored plugins in `plugins/` are patched local copies.  Edit in place;  never swap for
  pub.dev versions.
- Release signing (5.5) reads a gitignored `android/key.properties`.  A signed build needs
  the keystore created first;  the `keytool` + `key.properties` steps are in the
  2026-07-14 alpha-corrections archive entry below.  Debug builds run without it.
- `IMPORTANCE_LOW` (3.6) only applies to a freshly created notification channel;  test the
  quiet notification on a clean install or after clear-data, not an upgrade.

## Acceptance criteria

- Drag-to-dismiss validated by hand:  X arms and closes correctly, snap-back works, no
  accidental closes on a normal reposition drag.
- Ten-cold-launch visual pass clean, and the full interaction regression clean, or any new
  defect written up with a repro.
- Handoff block rewritten and committed at session close;  `last-active` in
  `D:\brain\50_projects\nwt-scroller\index.md` refreshed.
- Push state stated explicitly.

## Archive

### 2026-07-14c (device verification + three follow-up features -- PUSHED to Gitea + GitHub)

Picked up the alpha-corrections work (below), then verified it on the S24 Ultra and shipped
three follow-up features Michael requested from live testing.

Device verification of the alpha corrections:  the full APK builds (first real compile of
the Group 1 and 3 native Java -- clean), the overlay auto-appears on cold launch at 112x112
(no sliver, no crash), and ten scripted cold launches produced exactly ten clean overlay
starts with no flash-and-vanish.  The config screen rendered correctly (screenshots).

Three follow-up features, each built, installed, and verified on device:

- **Single-line config option rows (commit f5073e5).**  The 4.2 ChoiceChip-in-Wrap change
  wrapped the Book names, Theme, Intensity, and Interaction rows onto a second line.
  Replaced with a shared `_buildSegmentedRow` helper:  label above a full-width Material 3
  `SegmentedButton`, so the control never wraps and carries proper selected semantics.
- **Config design pass (commit 77ec3a6).**  Grouped the flat settings list into LANGUAGE /
  APPEARANCE / BEHAVIOR sections, and pinned the SegmentedButton selected state to the
  parchment brown (white on brown) instead of the auto-generated M3 secondaryContainer,
  which read pink and off brand.
- **Drag-to-dismiss (FR-12, commit 1b18677).**  Dragging the collapsed compass now reveals
  a circular X target at bottom center;  dropping the overlay onto it stops the service.
  Implemented natively in `OverlayService` as a second lightweight, non-touchable window;
  hit-testing uses the drag pointer in screen coordinates (no extra Flutter engine).
  Verified via a simulated drag onto the zone:  the close-zone window was added and the
  overlay service torn down cleanly.  Added FR-12 to `REQUIREMENTS.md` and corrected FR-7
  and FR-8, which still described the removed swipe-up history popup.

Decisions carried forward from the alpha review (still Michael's to overturn):  2.1 removed
the unreachable swipe gesture, and 2.2 cut the overlay history popup for v1 (history is
config-app only).

Carried:  the by-hand validation checklist in the Goal above, the optional Bible-NWT label
restyle (proposed, not selected), and the deferred low-priority polish list in
`docs/alpha-review-corrections.md`.

### 2026-07-14b (alpha-review corrections implemented -- commit c6b3cbd)

Executed `docs/alpha-review-corrections.md` end to end.  Fanned out four parallel subagents
partitioned by file ownership (not by group, because files like `OverlayService.java` and
`main.dart` span several groups and would have collided):  Agent A owned the vendored native
plugin (Group 1 native plus all of Group 3), Agent B the app shell and overlay glue, Agent C
the overlay widgets and services, and Agent D the themes and Android build.  An integration
pass implemented item 4.8 (the theme/interactionStyle enum seam crossing agent boundaries)
and ran central verification.

All 36 items (Groups 1 through 5) landed.  `flutter analyze` clean against the pre-existing
baseline, `flutter test` green at 22 (added a start-guard test and an applyFromMap-clamping
test;  fixed a stale URI assertion predating the multi-language `wtlocale` param).  Committed
as `c6b3cbd` on `main`.

Release-signing setup (5.5), for whoever cuts the first signed build:

```
keytool -genkey -v -keystore $HOME\nwt-scroller-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored) with `storePassword`, `keyPassword`,
`keyAlias=upload`, and `storeFile=` set to the absolute path of the `.jks` (forward slashes).
`flutter build apk --release` then signs with it;  without the file, the release build falls
back to debug keys.

### 2026-07-14a (superseded)

Goal was to orient on current state and pick up the v0.2+ thread after the 2026-07-02 v0.2
ship (History tab, Interaction Style 2, multi-language, rotation handling, Blue theme,
JW.org fallback) and the 2026-07-07 Claude Code bootstrap kit.  Superseded by the 2026-07-14
alpha review, which produced `docs/alpha-review-corrections.md` and drove the corrections
session above.
