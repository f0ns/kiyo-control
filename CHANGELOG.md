# Changelog

## 0.5.0

- Kiyo Pro Ultra: the ⋯ menu shows the camera's firmware version and links to Razer's firmware updater (Windows
  only). Kiyo Control itself does not update firmware: too risky, a failed flash can brick the camera. `kiyoctl info` prints model, USB link and firmware version.

## 0.4.0

- Kiyo V2 Pro (1532:0E0A) support for standard UVC controls; Razer-only settings are hidden.
  Community-tested; thanks to @samanthahuggan.

## 0.3.0

- Preview resolution and frame rate: click the format next to PREVIEW (up to 4K; the camera only offers
  4K when connected to a USB 3 port, not through a USB 2 hub such as a keyboard's). Like Synapse's setting it only changes this app's preview;
  Zoom, Teams, OBS and others choose their own.
- USB 2 warning next to the resolution picker when the camera is connected through a USB 2 hub, and the
  picker refreshes when you replug the camera (e.g. into a USB 3 port for 4K).
- Update notice: once a day the app asks GitHub for the latest release and shows a banner when a
  newer version is out (Download / Skip This Version). Menu bar: **Check for Updates…** and
  **Check for Updates Automatically**.

## 0.2.0

- HDR setting (On/Off) in the Processing tab, using the camera's backlight compensation. On hardware
  it lifts shadows (darkest quarter 84 → 136) while highlight clipping stays the same (4.8% → 5.0%).
  Replaces the separate "Backlight compensation" switch.

## 0.1.0

First release.

- Standard camera controls: zoom, pan, tilt, focus, auto exposure, white balance, brightness,
  contrast, saturation, sharpness, anti-flicker, backlight compensation.
- Razer settings (verified on hardware): ISO, shutter speed, metering, exposure compensation,
  AF mode (Standard/Face), AF tracking, AF lighting, mirror, 2D/3D noise reduction,
  lens distortion compensation.
- SAVE also stores changed Razer settings in the camera's memory, like Synapse's Save.
- Field of view presets (Wide/Medium/Narrow) and FOV in degrees, based on the zoom.
- Live preview: changes apply immediately, profiles only change when you press Save.
- Revert, Reset All Settings, and automatic backups before every reset or restore.
- Profiles, re-applied when the camera connects and after the Mac wakes.
- Menu bar app with Launch at Login.
- Zoom presets 1–5 per profile, also in the menu bar menu.
- `kiyoctl` command-line tool.
