# Changelog

[한국어](CHANGELOG.md) | **English**

The app for each version is available on the [Releases](https://github.com/nunnoo58/FinderPreset/releases) page.

## v1.1.1 (2026-11-17)

- Fixed the app window briefly appearing or staying open when applying or saving from the right-click menu while the app is closed
- Fixed "Edit Presets…" in the right-click menu not opening the app window
- Reopening the app from the Dock or "Edit Presets…" while it is handling a request now shows the window, and the app no longer quits when done
- Removed the icon in front of "View Presets" in the right-click menu

## v1.1 (2026-11-16)

- Added support for English macOS
- Added an app language setting (Settings → Language: System Default, 한국어, English)
- Finder is now controlled by the app itself. Only the app needs permissions; the Finder extension needs none
- When saving the current view from the right-click menu, the name prompt comes to the front so you can type right away, and the saved preset appears in the app's list immediately
- When a permission is missing, the app tells you which setting to turn on (including "Device Control and Data Access" on macOS 27)

## v1.0.1 (2026-11-12)

- Changed the app's notices, dialogs, and error messages to polite Korean

## v1.0 (2026-11-12)

- First public release
- Apply a preset to a folder from right-click → View Presets
- Apply to subfolders (applied once to the subfolders that exist at that moment)
- Save the current view as a preset
- Add, edit, delete, and reorder presets in the app window
