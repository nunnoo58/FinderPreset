# FinderPreset

[한국어](README.md) | **English**

> This app was built with Claude, an AI assistant by Anthropic. Coding, building, and documentation were done together with Claude.

A macOS app that saves Finder folder view settings as presets and applies them straight from Finder's right-click menu. Settings are stored per folder, so applying a preset to one folder does not affect others.

- Requires macOS 15 or later, with the macOS language set to Korean.
- Tested on: MacBook Pro 14 (M5, macOS 27.2)
- The app is not notarized by Apple, so a warning appears on first launch. See [First launch](#2-first-launch).

## Latest version: v1.0

- First public release
- Apply a preset to a folder from right-click → View Presets
- Apply to subfolders (applied once to the subfolders that exist at that moment)
- Save the current view as a preset
- Add, edit, delete, and reorder presets in the app window

See [CHANGELOG.en.md](CHANGELOG.en.md) for the change history, and get the app from the [latest release](https://github.com/nunnoo58/FinderPreset/releases/latest).

## Why I made this

(To be written)

## Who it's for

(To be written)

## What a preset contains

| Group | Settings |
| --- | --- |
| General | View style (icon, list, column, gallery), sort by |
| Icon view | Icon size, text size, label position, item info, icon preview |
| List view | Icon size, text size, relative dates, calculate all sizes, icon preview |
| Column view | Text size, icons, icon preview, preview column |

Sort by can be None, Snap to Grid, Name, Kind, Date Last Opened, Date Added, Date Modified, Date Created, Size, or Tags. None and Snap to Grid apply only in icon view.

## Installation

### 1. Download the app

1. Download `FinderPresets-v<version>.zip` from [Releases](../../releases) and unzip it.
2. Move `FinderPresets.app` to the Applications folder.

### 2. First launch

This app is not signed with a paid Apple Developer certificate or notarized by Apple; it is signed with a certificate the author created. When you first open it after downloading, macOS blocks it and shows a warning similar to this:

```
"FinderPresets" Not Opened
Apple could not verify "FinderPresets" is free of malware that may harm your Mac or compromise your privacy.
```

Since macOS 15, right-click → Open no longer bypasses this warning. Allow it once as follows, and it will open without a warning afterward.

1. Double-click the app and click **Done** in the warning. Do not click **Move to Trash**.
2. Open System Settings → Privacy & Security and scroll down to the Security section.
3. Next to the message that "FinderPresets" was blocked, click **Open Anyway** and confirm with your password or Touch ID.
4. Click **Open** in the dialog that appears.

If **Open Anyway** is not shown, try launching the app again and check once more. The button appears only for about an hour after a launch attempt.

If you are comfortable with Terminal, you can instead remove the download flag (quarantine attribute):

```
xattr -dr com.apple.quarantine /Applications/FinderPresets.app
```

Download the app only from this repository's [Releases](../../releases). Files from elsewhere may have been tampered with, even if they have the same name.

### 3. Turn on the Finder extension

If the app window shows a notice that the Finder extension is off, click the button next to it and turn on "Finder 프리셋". Once the notice disappears, **View Presets** appears in Finder's right-click menu.

### 4. Allow permissions

A prompt appears the first time you apply a preset. Allow all of them. The app and the Finder extension each ask separately, so you will see prompts once when applying from the app and once when applying from the right-click menu.

- **Automation**: "Finder 프리셋" wants to control Finder and System Events → Allow
- **Accessibility**: Turn on "Finder 프리셋" in System Settings → Privacy & Security → Accessibility.

### Notes

- **Updating**: Replace `FinderPresets.app` in the Applications folder with the new version. Your presets are kept.
- **If no prompt appears or you denied it by mistake**: Reset the permissions in Terminal with the commands below, then apply again.
  ```
  tccutil reset AppleEvents com.nunnoo.FinderPresets
  tccutil reset AppleEvents com.nunnoo.FinderPresets.FinderSync
  tccutil reset Accessibility com.nunnoo.FinderPresets
  tccutil reset Accessibility com.nunnoo.FinderPresets.FinderSync
  ```
- **Uninstalling**: Move the app to the Trash and delete the preset folder `~/Library/Application Support/FinderPresets/`. View settings already applied to folders stay as they are.

## Usage

| Action | How |
| --- | --- |
| Apply to the folder you are viewing | Right-click empty space in the window → View Presets → choose a preset |
| Apply to a specific folder | Right-click the folder → View Presets → choose a preset |
| Apply to subfolders too | Right-click → View Presets → Apply to subfolders → choose a preset |
| Save the current view | Right-click → View Presets → Save current view as preset… |
| Edit presets | Right-click → View Presets → Edit presets…, or open the app |

- Right-clicking a file applies the preset to the folder that contains it.
- Applying to subfolders copies the settings once to the subfolders that exist at that moment. Folders created later and later changes to the parent are not followed. If there are more than 20 targets, a confirmation appears first.
- In the app, "Apply to current window", "Import from current window", and "New preset from current Finder window" work on the frontmost Finder window.

The menu items are shown in Korean in the app.

## How it works

- Recent versions of Finder do not reflect sorting, list column visibility, or background color changed through AppleScript. The app therefore combines two methods.
  - AppleScript: view style, icon and text size, label position, previews, and other settings that are reflected
  - UI scripting (System Events): clicks View → Sort By to sort, and turns on "Always open in … view" in View Options
- Finder does not remember the view style and sorting of a folder unless "Always open in … view" is on; it follows the last view used instead. Turning this option on is what makes settings stick per folder.
- A closed folder is opened briefly, configured, and closed. For a folder handled for the first time, or one whose view style changes, Finder does not save the first round of values, so the preset is applied once more.
- Presets are stored in `~/Library/Application Support/FinderPresets/presets.json`, shared by the app and the Finder extension.

## Known limitations

- The app finds Finder menus by their Korean names ("보기", "다음으로 정렬", "보기 옵션"), so sorting and per-folder saving do not work when the macOS language is not Korean.
- While applying, the target folder window comes to the front and the View Options window appears briefly. Using Finder during this time may apply settings to a different window.
- Each folder takes 3–6 seconds. Many subfolders take correspondingly longer.
- Sort direction follows Finder's default: dates and sizes from largest, names in alphabetical order.
- List view column visibility and background color are not supported.

## Testing

Results checked on a MacBook Pro 14 (M5, macOS 27.2, v1.0). Applying and reading settings were checked by running the same code as the app from the command line.

### Done

- [x] After applying 6 different presets to closed folders and open windows, view style, sorting, and icon/list/column view options are kept when the folder is reopened
- [x] Applying to one folder leaves other folders' settings unchanged
- [x] All values are saved for folders handled for the first time and when the view style changes
- [x] Sort by Date Modified, Date Added, Date Last Opened, Size, Kind, and Snap to Grid are kept after closing and reopening the folder
- [x] Sorting by Date Modified in list view shows newest first in Finder
- [x] Applying the same preset several times in a row neither closes the window nor reverts the settings
- [x] Specifying a file applies the preset to its containing folder
- [x] Apply to subfolders: applied to every folder in a newly created tree (4 folders including 3 subfolders)
- [x] Reading a folder's current view creates a preset named after the folder

### Not yet tested

- [ ] Name prompt for "Save current view as preset…" in the right-click menu
- [ ] Confirmation when there are more than 20 subfolders
- [ ] "New preset from current Finder window" button in the app

## License and disclaimer

This project is distributed under [CC BY-ND 4.0](LICENSE). You may copy and redistribute it unmodified, including for commercial purposes, as long as you give credit (the author NUNNOO58 and this repository). You may not distribute modified versions.

This is an unofficial personal project and is not affiliated with Apple. macOS and Finder are trademarks of Apple Inc. and are used in this repository only to describe the supported environment and features.

This software is provided "as is," without warranty of any kind. The author is not responsible for any problems arising from the use of this app, including changes to folder settings. Please use it at your own discretion. The English text of the [LICENSE](LICENSE) file is legally authoritative.

## Contributing

This repository does not accept pull requests. Please report bugs or send suggestions via [Issues](../../issues).
