# iPhone Duo build and use

This guide adds the Duo-specific steps to the [main build instructions](../README.md).
The tested combination is a physical iPhone Duo on iOS 27.1, Xcode 27.1 with
its iOS 27.1 SDK, and the unmodified macOS Steam **Factorio 2.1.23 / build
87750** executable. Space Age assets must come from your own installed game.
This is an experimental local port, not a downloadable game release.

## Build for the physical Duo

1. Unfold the Duo, connect it to the Mac by USB, unlock it, and accept the Trust
   prompt. In Xcode, wait for device preparation to finish. Enable
   **Settings → Privacy & Security → Developer Mode** on the phone, restart, and
   confirm **Turn On** after restarting.
2. Check that the Steam installation contains the supported executable. The
   hash below is of the complete macOS executable, not its ARM64 slice:

   ```sh
   shasum -a 256 "$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
   ```

   For the tested build this prints
   `42218e9676f36687282800e5b6336b049c0f0e45f0f71eb20f90c49ccdec4359`.
   A newer Steam update is **not** automatically compatible: setup rejects
   other hashes because the Mach-O and SDL patches depend on this exact layout.
   Do not bypass that check.
3. From the repository root, run `python3 tools/setup.py`, then
   `open FactorioProbe.xcodeproj`. In the **FactorioProbe** target's
   **Signing & Capabilities**, enable automatic signing, select your own Team,
   and choose a unique bundle ID. Select the connected physical iPhone Duo as
   the run destination and choose **Product → Run**. The installed app is named
   **Factorio** and gets its icon from your local game installation.
4. Launch Factorio with the Duo unfolded and the inner display in landscape.
   Dismiss the Steam unavailable notice if it appears. The first graphical
   startup can take longer while the game prepares its data.

The build copies the locally installed game data into the app, including owned
Space Age, Quality, and Elevated Rails assets when present. Enable the expansion
mods through Factorio's own mod controls. No game executable, assets, signed app,
Apple credentials, or save data are stored in this repository. Save your game
before reinstalling; keep the same bundle ID to update the existing app and
preserve its container. The [README](../README.md#saves-updates-and-renewing-signing)
shows how to back up saves.

## Inner display and controls

The Duo has two displays. This port selects the active UIKit window scene
instead of assuming `UIScreen.mainScreen` is the game display. SDL's later
orientation updates also use that scene; otherwise the inner display can
rotate into a 669-point-wide view, leaving the right side black and cutting
off the bottom. The game window fills the inner display, while its Metal view
sits inside dark margins so Factorio's edge-aligned HUD avoids rounded corners.
On the tested landscape inner display, the window was **951 × 669 points**
(2853 × 2007 pixels) and the drawable **919 × 637 points**
(2757 × 1911 pixels). The top and bottom margins are both 16 points; the side
margins follow the larger of the system safe area and 16 points.

Use the first three icons in the pill above the game to select the input behavior:

| Mode | Touch behavior |
|---|---|
| Tap | Direct touch for menus and ordinary selection |
| Mine | Touch and hold ore or a tree to hold the right mouse button |
| Cursor | Move a visible pointer without clicking; hold **Use** (left click) or **Mine** (right click) to act at its position |

The on-screen mouse buttons stay down while your finger remains on them and
release when you lift it. To drag, hold a mouse button and move the cursor
with a second finger. The eye icon hides the controls if you are using a
hardware keyboard and mouse. Control positions adapt when the window size
changes; an in-progress held input is released on resize to avoid a stuck key.
See the [full control map](../README.md#touch-controls-and-hardware-input).

The phone uses low-quality texture compression, virtual-atlas compression,
and low video-memory settings on startup. This reduces the initial texture
allocation; it does not establish performance or stability for a large factory.
Fold/unfold transitions, full Space Age progression, multiplayer, and the
complete range of building actions have not been verified.

## Physical display check and simulator limits

If the right edge is black or the HUD is clipped, capture the **inner** display
instead of relying on the XCTest helper's default screenshot. Get the device
identifier from `xcrun devicectl list devices` and the active display's unique
ID from `device info displays`:

```sh
export FACTORIO_DEVICE_ID="YOUR_DEVICE_IDENTIFIER"
xcrun devicectl device info displays --device "$FACTORIO_DEVICE_ID"
mkdir -p reports
xcrun devicectl device capture screenshot \
  --device "$FACTORIO_DEVICE_ID" \
  --display-unique-id "YOUR_INNER_DISPLAY_UNIQUE_ID" \
  --destination reports/duo-inner.png
swift tests/check_duo_viewport.swift reports/duo-inner.png
swift tests/check_duo_safe_viewport.swift reports/duo-inner.png
```

The checks inspect the tested landscape screenshot layout. A changed device
resolution, rotation, or a loading screen can invalidate their assumptions;
also inspect the image itself. The separate UIKit touch-control harness and
small Space Age simulation probes are described in
[Development and local checks](DEVELOPMENT.md#iphone-duo-simulator-checks).

The iPhone Duo simulator requires the Xcode 27.1 iOS 27.1 runtime for its
profile. It can run those input/layout and simulation checks, but normal
graphical startup cannot pass its missing Metal GPU-family and BC3 texture
support. Use a physical Duo to assess graphics. The 120-update Space Age probe
matched the original Mac and physical Duo checksum `4032494708`; that tests a
small simulation only, not complete graphical gameplay.
