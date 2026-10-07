# Changelog

## Unreleased

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

Not yet supported: HDR (command unknown).
