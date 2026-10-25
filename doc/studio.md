# Scrcpy Studio

This fork includes optional graphical applications around the original scrcpy
client and server. The command-line client remains unchanged.

## macOS app

`Scrcpy Studio` is a native SwiftUI application. It bundles the locally built
scrcpy client, adb and scrcpy server into one `.app` and provides:

- USB and TCP/IP device discovery;
- one-click mirroring with resolution, bitrate and frame-rate controls;
- audio, screen-off, stay-awake, touch-display and recording options;
- APK installation and file transfer;
- a visible command log.

Build the normal macOS client and Android server first, then run:

```bash
desktop/macos/build_app.sh
```

The output is `release/output/Scrcpy Studio.app`.

## Android companion

`Scrcpy Link` is an optional Android companion. It shows the phone's LAN
address and ADB/root status, and can enable or disable ADB over TCP port 5555.
The wireless toggle requires root and is intended for rooted development
devices. It does not persist the TCP port across reboot.

Build it with:

```bash
./gradlew :companion:assembleDebug
```

The debug APK is written to
`companion/build/outputs/apk/debug/companion-debug.apk`.

The Android app follows the system light/dark appearance automatically. ADB
over TCP should be disabled after use on an untrusted network.
