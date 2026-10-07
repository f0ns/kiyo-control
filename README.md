# Kiyo Control

Camera settings for the **Razer Kiyo Pro Ultra** on macOS — the controls Razer Synapse offers on Windows but not on Mac.

Not affiliated with or endorsed by Razer. "Razer" and "Kiyo" are trademarks of Razer Inc.

## Features

- Live preview while you adjust; nothing is stored in a profile until you press **Save** (⌘S).
- **Revert** to the last saved settings, **Reset All Settings** to factory defaults.
- Automatic backups: the camera's state is saved when it connects and before every reset or restore
  (`~/Library/Application Support/KiyoControl/backups`, last 20 kept). Restore from the `…` menu.
- Profiles, re-applied when the camera is plugged in and after the Mac wakes from sleep.
- Runs from the menu bar, optionally at login, so profiles apply without opening the window.
- Zoom presets 1–5 per profile, with system-wide shortcuts ⌃⌥1–5.
- Works while other apps (Zoom, Meet, OBS…) use the camera.

| Status | Settings |
|---|---|
| Working | Zoom, pan, tilt, auto/manual focus, auto exposure, white balance, brightness, contrast, saturation, sharpness, anti-flicker, backlight compensation |
| Working (Razer commands) | ISO, shutter speed, metering, exposure compensation, AF mode (Standard/Face), AF tracking, AF lighting, mirror, 2D/3D noise reduction |
| Working (app) | Field of view presets Wide/Medium/Narrow (set the zoom; FOV in degrees is calculated from it) |
| Not yet | HDR (command unknown), lens distortion compensation (needs a camera restart to apply) |

## Install

Download the zip from Releases, unzip, and move the app to Applications. The app isn't notarized
by Apple, so the first time right-click it and choose **Open** (or run
`xattr -d com.apple.quarantine /Applications/KiyoControl.app`).

It lives in the menu bar: close the window and it keeps applying your profile whenever the camera
connects. Turn on **Launch at Login** in its menu bar menu to have that after every restart.

## Build

Requires macOS 15+ and Xcode.

```sh
scripts/build-app.sh
open build/KiyoControl.app
```

## Tests

```sh
swift test             # unit tests for KiyoKit (uses a fake camera, no hardware needed)
scripts/smoke.sh 4 25  # launches the app 4x25s with a self-test; fails on any crash (camera plugged in)
```

`scripts/release.sh` builds a release zip (and signs/notarizes when `DEVELOPER_ID` and
`NOTARY_PROFILE` are set). The icon is drawn in code: `swift scripts/make-icon.swift Resources/AppIcon.icns`.

## Command line

```sh
swift build --product kiyoctl
.build/debug/kiyoctl list               # every control with value and range
.build/debug/kiyoctl set zoom 200       # 2.0x
.build/debug/kiyoctl backup
.build/debug/kiyoctl restore <backup.json>
```

## How it works

The camera is a standard UVC device. Settings are UVC control requests sent over the USB default pipe
via IOKit, without claiming the device. `tools/uvc-dump.c` and `tools/uvc-probe.c` are read-only
helpers that list the camera's descriptors and vendor extension unit controls.

Razer-specific features are 8-byte commands sent to extension unit 6
(`23e49ed0-1178-4f31-ae52-d2fb8a8d3b48`, selector 1); the camera answers on selector 2. The command
layouts come from USB captures of Synapse documented by the
[cameractrls](https://github.com/soyersoyer/cameractrls/issues/19) project. Thanks!
`scripts/hardware-test.sh` checks them on a real camera by comparing frames before and after each change.
Never send guessed commands to that unit, and the app never sends the save-to-camera command.

## License

MIT
