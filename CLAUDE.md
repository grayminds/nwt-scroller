# CLAUDE.md -- nwt-scroller project instructions

## What this is

Android Flutter overlay app for quick Bible book/chapter/verse navigation via a floating compass-rose UI.  The overlay runs above other apps (`SYSTEM_ALERT_WINDOW`) and deep-links references into JW Library, with a JW.org web fallback.

## Tech stack and running it

- Flutter (Dart SDK ^3.7.0), Android-first with a web scaffold added 2026-07-02.
- Two Flutter engines from one binary:  `main()` (config app) and `overlayMain()` (the overlay, `@pragma("vm:entry-point")` in `lib/main.dart`).
- Vendored local plugins in `plugins/`:  `flutter_overlay_window` (patched) and `nwt_vibration` (custom haptics).  Path dependencies in `pubspec.yaml`; do not swap them for pub.dev versions.

Commands (standard Flutter CLI; there is no package.json or Makefile):

- `flutter pub get` -- install dependencies.
- `flutter run` -- run on a connected Android device (overlay behavior needs a real device or emulator, not web).
- `flutter test` -- run tests (`test/bible_data_test.dart`).
- `flutter analyze` -- lint (flutter_lints, `analysis_options.yaml`).
- `flutter build apk` -- release build.
- `.\scripts\publish.ps1` -- coupled push:  Gitea full history + GitHub clean mirror.  Supports `-WhatIf`.  Publishing is Michael's call; never run the real push unprompted.

## Layout and conventions

- `lib/` splits by role:  `data/` (repositories), `models/`, `services/` (config, haptics, launcher, overlay, screen), `widgets/` (overlay UI), `theme/` (blue, parchment, scroll, silver).
- Overlay <-> main app communication goes through platform channels wrapped in `services/`; do not call `FlutterOverlayWindow` directly from widgets.
- `REQUIREMENTS.md` is the spec (FR-1 through NFR-7).  Check it before changing overlay sizing, drag, or collapse behavior; the pixel math there is deliberate.
- Secrets for publish live in gitignored `.env.local` (GITHUB_PAT, GITEA_TOKEN).  Never commit them.

## Prose rules

All prose (comments, docs, commit messages) follows `D:/brain/_identity/voice-core.md`:  two spaces between sentences, Oxford comma, active voice, no em dashes, no emoji, no AI-ese.

## Session handoff

`docs/next-session.md` carries the rolling handoff block.  Read it at session open, archive the prior block, and rewrite it at session close.

## Vault registry

Canonical project metadata:  `D:\brain\50_projects\nwt-scroller\index.md`.  Update `last-active` there when a work session lands.
