<p align="center">
  <img src="docs/icon.png" width="128" alt="Kiyo Control icon">
</p>

<h1 align="center">Kiyo Control</h1>

<p align="center">
  Camera settings for the <b>Razer Kiyo Pro Ultra</b> on macOS — the controls Razer Synapse offers on Windows but not on Mac.
</p>

<p align="center">
  <a href="#install"><b>Install</b></a> ·
  <a href="https://www.paypal.com/donate/?hosted_button_id=CSFVGLP7FFYMU"><img src="https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white" alt="Donate with PayPal" align="center"></a>
</p>

> **Unofficial.** Kiyo Control is an independent, community-made project. It is not affiliated with,
> endorsed by, or supported by Razer Inc. See [Disclaimer](#disclaimer).

<p align="center">
  <img src="docs/kiyo-control.png" width="800" alt="Kiyo Control window with camera settings on the left and a live preview on the right">
</p>

## Features

- Live preview while you adjust; nothing is stored in a profile until you press **Save** (⌘S).
- **Revert** to the last saved settings, **Reset All Settings** to factory defaults.
- Automatic backups: the camera's state is saved when it connects and before every reset or restore
  (`~/Library/Application Support/KiyoControl/backups`, last 20 kept). Restore from the `…` menu.
- **SAVE** also stores the Razer settings in the camera's memory, so they stick without the app, also on other computers.
- Profiles, re-applied when the camera is plugged in and after the Mac wakes from sleep.
- Runs from the menu bar, optionally at login, so profiles apply without opening the window.
- Zoom presets 1–5 per profile, also one click away in the menu bar menu.
- Works while other apps (Zoom, Meet, OBS…) use the camera.

| Status | Settings |
|---|---|
| Working | Zoom, pan, tilt, auto/manual focus, auto exposure, white balance, brightness, contrast, saturation, sharpness, anti-flicker, HDR (backlight compensation) |
| Working (Razer commands) | ISO, shutter speed, metering, exposure compensation, AF mode (Standard/Face), AF tracking, AF lighting, mirror, 2D/3D noise reduction, lens distortion compensation (after SAVE + replug) |
| Working (app) | Field of view presets Wide/Medium/Narrow (set the zoom; FOV in degrees is calculated from it) |
| Unconfirmed | HDR uses the camera's backlight compensation: shadows come up, highlights stay. Whether Synapse's HDR sends a different Razer command is unknown; the Dell UltraSharp HDR command (`ff 11`) is rejected. |

## Install

You need a Mac with macOS 15 (Sequoia) or newer and a Razer Kiyo Pro Ultra.

### Easiest: one line

1. Open **Terminal** (press ⌘ Space, type *Terminal*, press Return).
2. Paste this line and press Return:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/f0ns/kiyo-control/main/scripts/install.sh | sh
   ```

3. Kiyo Control opens. When it asks for the camera, click **Allow**.

Run the same line again later to update.

### Or: download it yourself

1. **Download.** Go to the [latest release](../../releases/latest) and click **KiyoControl-….zip**
   under *Assets*. It lands in your Downloads folder.
2. **Unzip.** Double-click the zip. You now have **KiyoControl** (the icon with the green ring).
3. **Move it to Applications.** Drag KiyoControl into the **Applications** folder in Finder's sidebar.
4. **Open it the first time.** Double-click KiyoControl in Applications. macOS will say it
   *"cannot verify"* the app, because it's a free app that isn't registered with Apple. That's expected:
   - Click **Done** (not *Move to Trash*).
   - Open  › **System Settings** › **Privacy & Security**.
   - Scroll down to the message about KiyoControl and click **Open Anyway**, then enter your password.
   - Click **Open Anyway** once more in the window that appears.

   You only have to do this once.
5. **Allow the camera.** When asked *"KiyoControl would like to access the camera"*, click **Allow**.
   This is for the live preview.

That's it. Plug in the camera and the settings appear.

### Everyday use

- Change settings and watch the preview. Nothing is kept until you click **SAVE**; **Revert**
  undoes your changes.
- Closing the window keeps KiyoControl running in the **menu bar** (the camera icon at the top of
  the screen), so your settings come back whenever you plug the camera in.
- Want it to start automatically? Click the menu bar icon and turn on **Launch at Login**.
- Made a mess? Click **Reset All Settings**, or the **⋯** button › **Restore Backup**.

### Uninstall

Click the menu bar icon › **Quit**, then drag KiyoControl from Applications to the Trash.
To also remove your profiles, delete the folder `~/Library/Application Support/KiyoControl`.

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
.build/debug/kiyoctl snap frame.jpg      # grab one frame
```

`kiyoctl save-to-camera --yes` stores the current Razer settings in the camera's memory, like
Synapse's Save button (the app's SAVE does this when a Razer setting changed). Standard UVC settings (zoom, brightness…)
are not kept by the camera across a replug; the app re-applies those from your profile.

## How it works

The camera is a standard UVC device. Settings are UVC control requests sent over the USB default pipe
via Apple's IOUSBHost framework, without claiming the device, so other apps keep streaming. `tools/uvc-dump.c` and `tools/uvc-probe.c` are read-only
helpers that list the camera's descriptors and vendor extension unit controls.

Razer-specific features are 8-byte commands sent to extension unit 6
(`23e49ed0-1178-4f31-ae52-d2fb8a8d3b48`, selector 1); the camera answers on selector 2. The command
layouts come from USB captures of Synapse documented by the
[cameractrls](https://github.com/soyersoyer/cameractrls/issues/19) project. Thanks!
`scripts/hardware-test.sh` checks them on a real camera by comparing frames before and after each change.
Never send guessed commands to that unit, and the app never sends the save-to-camera command.

## Support

Kiyo Control is free and open source. If it saves you from booting Windows, you can
[buy me a coffee via PayPal](https://www.paypal.com/donate/?hosted_button_id=CSFVGLP7FFYMU) ☕
(also the **♥ Donate** link in the app).

## Credits

The Razer-specific command layouts were documented by
[cameractrls](https://github.com/soyersoyer/cameractrls) contributors (issue #19) from USB captures.
Kiyo Control uses those facts about the camera's protocol; it contains no code from cameractrls,
Razer Synapse or any other Razer software.

## Disclaimer

- **No warranty, use at your own risk.** This software is provided "as is", without warranty of any
  kind (see [LICENSE](LICENSE)). The authors are not liable for any damage to your camera, computer,
  data or anything else, including from settings saved to the camera.
- **Not affiliated with Razer.** Razer, Kiyo, Kiyo Pro Ultra and Synapse are trademarks or registered
  trademarks of Razer Inc. The names are used only to describe which hardware this software works
  with. This project is not affiliated with, endorsed by, sponsored by, or supported by Razer Inc.
  For official support, use Razer's own software and support channels.
- **Interoperability.** Kiyo Control talks to the camera through the standard USB Video Class
  interface and documented vendor commands, solely to make the camera usable on macOS. It contains
  no Razer firmware, software, code, images or other proprietary material; `scripts/legal-check.sh`
  checks this on every change.
- **Warranty of your device.** Changing camera settings with third-party software might affect
  Razer's support or warranty. Check Razer's terms if that matters to you.

## License

MIT, see [LICENSE](LICENSE).
