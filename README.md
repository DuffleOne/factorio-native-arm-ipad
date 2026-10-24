# Factorio on iPhone and iPad — experimental local port

This repository builds a development-signed iOS app from **your own macOS
installation of Factorio**. The game and its assets run locally on the device;
the Mac is needed to build, install, and later renew the signing profile.

The installed app is named **Factorio** and uses the gear icon from your local
game installation. The Xcode project and internal executable remain named
`FactorioProbe`.

The build declares support for both iPhone and iPad. Its touch controls adapt
to narrow, wide, and short landscape views, and release held inputs when the
view resizes. Factorio 2.1.23 with Space Age reached gameplay on a physical
iPhone Duo on iOS 27.1. Its game view now sits inside narrow dark margins to
keep the HUD clear of the inner display's rounded corners. Complete gameplay and
fold/unfold transitions remain experimental; see
[local device and simulator checks](docs/DEVELOPMENT.md).

The repository includes porting code, touch controls, Xcode projects, and build
tools. **Factorio itself, game assets, prebuilt apps, certificates, and saved games
are not included.** This is not an official client from Wube Software.

For an iPhone Duo build, use these instructions with the
[iPhone Duo guide](docs/IPHONE_DUO.md). It covers the inner display, Space Age
assets, touch modes, and physical-device checks.

## Requirements and tested configuration

| Component | Requirement / tested configuration |
|---|---|
| Mac | Apple Silicon; run Terminal natively as ARM64, not through Rosetta |
| Xcode | Full Xcode installation with iOS SDK 26 or newer; iPhone Duo full-screen layout needs Xcode 27.1 / iOS 27.1 SDK |
| Python | 3.12 or newer; tested: 3.14 |
| CMake | Available in Terminal; setup saves its path for Xcode |
| iPad | iPadOS 26 or newer; graphics tested on an 11-inch iPad Pro **M1**, iPadOS 26.6.1 |
| iPhone | iOS 27.1 iPhone Duo for the current device build; Developer Mode enabled |
| Signing | Your own Apple Account in Xcode, a development team, and a paired device |
| Game | **Factorio 2.1.23, build 87750, macOS Steam, unmodified universal executable**; earlier 2.0.77 builds remain accepted |

Other iPads and newer SDKs have not automatically been verified. The original
Metal renderer requires suitable BC texture support, among other capabilities.
The simulator cannot replace device testing: normal graphical startup falls
back to OpenGL because its simulated GPU lacks the needed Metal family, and
that OpenGL context cannot be created. The earlier Metal diagnostic bypass
reached a BC3_RGBA texture-format failure. Small game simulation tests run there.

On the M1 iPad, testing covered the menu, tutorial, movement, inventory, mining
trees, text input, saving, and loading a saved game. Audio was confirmed on the
device. English on-screen controls and a visible touch cursor are included.
Physical keyboard and mouse support is connected through SDL but has not yet been
tested with real hardware. Large factories, the full range of building actions,
and long-term stability remain unverified. See [Architecture and limitations](docs/ARCHITECTURE.md).

On the physical iPhone Duo, Factorio 2.1.23 with the Space Age expansion loaded
through its main menu and an early tutorial save. The active inner display is
2853 × 2007 pixels; the current inset build uses a smaller 2757 × 1911
Metal drawable inside it. The game uses low-quality texture compression on
iPhone to keep the initial texture allocation down. This is still an
experimental port.

## 1. Prepare the repository and tools

Clone the repository, or download and extract its ZIP. In Terminal, change to the
folder containing this README and `FactorioProbe.xcodeproj`.
Run all commands below from that folder.

Open Xcode once, complete its setup, and install the iOS platform support.
Check your tools:

```sh
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
python3 --version
cmake --version
```

If `xcodebuild` points only to Command Line Tools, select the full Xcode
installation under **Xcode → Settings → Locations → Command Line Tools**.
If you already use Homebrew, you can install Python and CMake with:

```sh
brew install python cmake
```

The first build needs an internet connection to download PyYAML, SDL, and, if
necessary, Apple signing profiles. The build downloads SDL 3.4.14 for Factorio
2.1.23 or SDL 2.30.9 for Factorio 2.0.77 from the official SDL repository and
checks the archive against a pinned SHA-256 hash.

## 2. Select your own Factorio app

You need a complete installation of one of the supported macOS game versions.
The locally audited **Factorio 2.1.23 / build 87750 Steam** executable has this
exact SHA-256 hash:

```text
42218e9676f36687282800e5b6336b049c0f0e45f0f71eb20f90c49ccdec4359
```

This build uses SDL 3.4.14 and 1,269 static redirects to its iOS backend. The
source validator checks the entry point, SDL version, and unused space before
patching a copy. The original game is never modified. The 2.1.23 Space Age
120-update probe produced checksum `4032494708` on the original Mac game,
iPhone Duo simulator, and physical iPhone Duo. This verifies a small simulation,
not graphical play.

The earlier upstream-tested **Factorio 2.0.77 / build 84539** executable has
this SHA-256 hash:

```text
00b014d78df07e05ab1cee853904c8f7b3814ca652c043461a9d49fbad46cdf6
```

The hash applies to `factorio.app/Contents/MacOS/factorio`, not the app directory
or just its ARM64 slice. The version number alone is insufficient: other
distributions or executables that have been re-signed may differ.
A dSYM file is not required for this build; the necessary symbols are read from
the verified executable.

This local checkout also accepts the following **experimental** Steam 2.0.77,
build 84539 executable, inspected on October 7, 2026:

```text
90e2ebfdb5fd8b3966915f704a0ae99177c2af64ed9267c634ced42bff36d820
```

Its startup symbols, display-patch instructions and branch target, and padding
for the documented 817 SDL redirects were checked locally. Setup repeats the
layout checks. The build records the actual source hash, and verification rejects
an app built from a different source. This is not a claim of device compatibility;
full Space Age gameplay still needs testing. On October 7, 2026 this variant was
built with Xcode 27, signed, installed on an M1 iPad Pro running iPadOS 27, and
observed rendering the Space Age main menu and touch controls. Its 120-update
Space Age probe matched the original Mac checksum `2376201887`. All other hashes
remain rejected. See [local checks](docs/DEVELOPMENT.md#local-source-compatibility-tests).

For the standard Steam installation, run:

```sh
python3 tools/setup.py
```

For a different installation location:

```sh
python3 tools/setup.py --app "/path/to/your/factorio.app"
```

Setup checks the original hash and tools, creates `.venv`, installs the pinned
Python dependency, and writes local paths to `.local-config.json`.
That file is excluded by `.gitignore`. See also
[`local-config.example.json`](local-config.example.json).

If you see `Unsupported Factorio executable`, stop and provide your own matching
installation. **Do not remove the hash check:** the binary patches are specific
to the audited executables. Other game versions require a new analysis.
This project does not modify the original app.

## 3. Set up the iPhone or iPad and signing

1. Connect the device to the Mac over USB, unlock it, and accept the trust prompt.
   Xcode must recognize the device and finish preparing it.
2. On the device, enable Developer Mode under
   **Settings → Privacy & Security → Developer Mode** and confirm the requested
   restart. If the option is missing, pair the device with Xcode first.
3. Sign in with your own Apple Account under
   **Xcode → Settings → Apple Accounts**.

Apple documents these steps in
[Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
and [Running apps on devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).

For iPhone Duo, unfold the device and select the connected **physical iPhone
Duo** as the Xcode run destination. The tested graphical path uses its inner
display in landscape. The Duo simulator can run the small command-line probes,
but cannot render normal Factorio graphics; see the [Duo guide](docs/IPHONE_DUO.md).

```sh
open FactorioProbe.xcodeproj
```

In Xcode, open the **FactorioProbe** target. Under **Signing & Capabilities**,
enable **Automatically manage signing** and select your own **Team**.
If necessary, enter your own unique **Bundle Identifier**, such as
`com.yourname.factorioipad`. This identifier is also applied to the generated app.
At the top, select the **FactorioProbe** scheme and your connected **physical device**.

Xcode can also create a Personal Team. Check whether signing works with your own
account configuration and how long its profile remains valid; no one else's
profiles are supplied with this repository.
[Apple: Signing workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html)

## 4. Build and launch

In Xcode, choose **Product → Run** / **⌘R**. The first build downloads and compiles
SDL, generates the import audit, adapts a copy of the original executable, and
bundles the local game data, including installed expansion assets. This takes time and several GB of free disk
space. Xcode then signs the app and libraries and installs them.

The build intentionally uses a shell script phase: Xcode first compiles a small
placeholder, which is then replaced by the locally generated game executable.
Edit files in `probe/` directly; you do not need to add them separately to
“Compile Sources.”

The initial graphical startup took about 20–30 seconds on the tested device.
Dismiss the Steam unavailable message with **Confirm**; Steam login and Steam
features are unavailable. Close the changelog if it appears. Then start a
tutorial or a base-game session from the main menu.

Once installed, **Factorio** can be opened directly on the device, and you can
disconnect the USB cable. Normal play does not require the XCTest helper.
Automatic crash-log uploading is disabled in the local build.

## Alternative: Build and install from Terminal

After setup, device pairing, and configuring your Xcode account, replace the
example values below with your own. The team ID must identify your signing team;
the bundle ID must match your intended app.

```sh
export FACTORIO_TEAM_ID="YOUR_TEAM_ID"
export FACTORIO_BUNDLE_ID="com.yourname.factorioipad"

xcodebuild \
  -project FactorioProbe.xcodeproj \
  -scheme FactorioProbe \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/Xcode \
  DEVELOPMENT_TEAM="$FACTORIO_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$FACTORIO_BUNDLE_ID" \
  -allowProvisioningUpdates build
```

The installable product is generated at
`build/Xcode/Build/Products/Debug-iphoneos/FactorioProbe.app`.
**`build/iphoneos/FactorioProbe.app` is only ad hoc signed and cannot be installed
directly on a physical device.**

Verify the signature, game binary sections, and identifier:

```sh
.venv/bin/python tools/verify.py \
  --signed-app build/Xcode/Build/Products/Debug-iphoneos/FactorioProbe.app \
  --bundle-id "$FACTORIO_BUNDLE_ID"
```

List devices and enter your iPhone or iPad's identifier:

```sh
xcrun devicectl list devices
export FACTORIO_DEVICE_ID="YOUR_DEVICE_IDENTIFIER"

xcrun devicectl device install app \
  --device "$FACTORIO_DEVICE_ID" \
  build/Xcode/Build/Products/Debug-iphoneos/FactorioProbe.app

xcrun devicectl device process launch \
  --device "$FACTORIO_DEVICE_ID" "$FACTORIO_BUNDLE_ID"
```

This installation replaces an existing app with the same identifier. Save your
current game before updating. Keep the same bundle ID for future updates so that
the same app and its existing data are updated.

## Touch controls and hardware input

The controls are icon-based, translucent, and fade back after five seconds
without a touch; the next touch on a control brings them back. Buttons give a
light haptic tap when pressed.

| Control | Function |
|---|---|
| Pill at the top | Input mode (Tap / Mine / Cursor), on-screen keyboard, and hide/show controls |
| Stick at the bottom left | WASD movement in eight equal sectors, so diagonals are as easy to hold as straight lines |
| Rail above the stick | Menu (Escape), Inventory (E), Research (T), Map (M) |
| **Use** — large button in the bottom-right corner | Left mouse button |
| Inner arc: **Mine** / **Rotate** / **Pipette** | Right mouse button / R / Q (clear cursor or pick an entity) |
| Outer arc: **Pick up** / **Shoot** / **Gun** / **Middle** | F / Space / Tab (switch gun; also acknowledges the matching tutorial prompt) / middle mouse button |
| Zoom pair above the arc | Zoom out / in through mouse-wheel events |
| Shift / Ctrl / Alt | Toggle modifiers on; tap again to release |
| Keyboard | Full on-screen keyboard with letters, numbers, Enter, and special keys |

Select a mode directly in the top pill; the active mode is highlighted and a
short hint appears below it:

- **Tap:** Touching the screen clicks directly. Use this for normal menu interaction.
- **Mine:** Holding a finger on a tree or ore acts as holding the right mouse
  button. Switch back to Tap for menus.
- **Cursor:** Touch positions a visible white arrow without clicking. Then press
  **Use** or **Mine**. The arrow tip marks the click position. To drag,
  hold a mouse button and slide a second finger across the game area. Building
  actions involving multiple fingers still need further device testing.

**Use** (left click) is used for actions such as selecting and placing; **Mine**
(right click) for mining and other inventory actions; **Middle** for actions such
as setting inventory filters. The exact effect depends on the game context and key bindings.
Separate mouse buttons are not needed for ordinary tapping.

### Portrait split layout

Rotate the device to portrait to move the controls onto an opaque deck below the
game. The game view shrinks to the upper part of the screen, so no control covers
it; the on-screen keyboard opens in the deck and leaves the game visible above.
Hiding the controls gives the game the whole portrait screen again.

### Bluetooth keyboard, mouse or trackpad, and controllers

When a keyboard, mouse/trackpad, or game controller connects, the touch controls
hide automatically and a short notice says so; tap the eye icon to bring them
back. They return automatically when all hardware disconnects, unless you changed
them yourself in the meantime.

**Trackpad or mouse on iPhone:** iOS on iPhone does not pass Bluetooth mouse or
trackpad movement to apps. It reports the device as connected, but no movement
reaches the game, and iOS refuses the pointer lock that would release it (tested
on iPhone Duo, iOS 27.1). Turn on **Settings → Accessibility → Touch →
AssistiveTouch** and pair the trackpad under **Pointer Devices**. Its pointer
movement then reaches the game as hover. On iPhone Duo with iOS 27.1, AssistiveTouch
draws its pointer and delivers its taps only on the outer display, even while the
app is on the inner one (an iOS bug); the port draws its own white arrow there
once hover movement arrives. iOS 27.2 RC2 draws the AssistiveTouch pointer on the
inner display, so the port does not add its arrow on 27.2 or later.

iPhone also keeps the trackpad's **left** button for AssistiveTouch's tap, and
because of the same bug that tap never reaches the inner display. Only the right
button arrives, so on iPhone the port makes the **right button act as left click**
(select, build, open). To mine
or remove with the trackpad, bind **Mine** and the other right-click actions to
keyboard keys in Factorio's **Settings → Controls**, or use the overlay's Mine
mode. If a trackpad does deliver left-button events, the mapping returns to
normal after the first left click. iOS 27.2 RC2 fixes both problems: the
AssistiveTouch pointer and left-click tap work on the inner display, so the port
keeps the trackpad's buttons as they are and draws no arrow of its own while
AssistiveTouch is running.

On iPad, the port asks for pointer lock when a mouse connects, forwards the
movement to the game, and draws the white arrow once movement arrives. Mouse
buttons and scrolling come from SDL.

Factorio's own controller support is no longer disabled at launch (the
`--nogamepad` argument was removed). Controller play is experimental and has
not yet been tested on the device.

## Saves, updates, and renewing signing

Saves are stored inside the iPhone or iPad app at `Documents/Factorio/user/saves`, and the
configuration is stored at `Documents/Factorio/config.ini`. After an update,
container-dependent data paths are adjusted at startup.

Using your device and bundle IDs set above, you can back up saves to the Mac
before an update. Choose a new destination folder for each backup:

```sh
xcrun devicectl device copy from \
  --device "$FACTORIO_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$FACTORIO_BUNDLE_ID" \
  --source Documents/Factorio/user/saves \
  --destination build/save-backup-01
```

Signing validity depends on your own development profile. When it expires,
rebuild and reinstall using your own team. Do not delete the app for
troubleshooting before backing up saves: uninstalling removes its local data.
A Steam game update may cause the next build to fail the hash check; an already
installed app contains its own copy of the game assets.

## Troubleshooting

| Problem | Next step |
|---|---|
| Original hash does not match | Provide your own exact supported game version; do not bypass the version check |
| `.venv/bin/python` is missing | Run `python3 tools/setup.py` in the repository |
| `cmake` is missing only in Xcode | Rerun setup in Terminal; it saves the absolute CMake path locally |
| Download or SDL hash check fails | Check the connection; remove only the relevant downloaded SDL archive under `build/vendor/` and rebuild; keep hash verification enabled |
| `Signing requires a development team` | Select your team, automatic signing, and your own bundle ID in Signing & Capabilities |
| iPhone or iPad is unavailable | Check that it is unlocked, USB trust is granted, Developer Mode is enabled, and Xcode has finished preparing it |
| App is reported as untrusted | First check the signature with `codesign --verify --deep --strict`; use fresh DerivedData for a broken build; if the signature is valid, follow the specific Xcode/device prompt |
| Menus respond incorrectly | Switch to Tap; temporarily use Hide controls if buttons are obscured |
| Duo simulator fails on BC3 / pixel format 134 | Known graphics limitation; test graphical play on a supported physical device |
| `FACTORIO_PROBE_UNIMPLEMENTED` / crash | An unimplemented platform call was reached; save the log. The port does not cover every macOS function |

Build details are available in Xcode's build log and locally in
`reports/sdl-configure-iphoneos.log` and `reports/sdl-build-iphoneos.log`.
Copy the current game log with:

```sh
xcrun devicectl device copy from \
  --device "$FACTORIO_DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$FACTORIO_BUNDLE_ID" \
  --source Documents/Factorio/user/factorio-current.log \
  --destination reports/ipad-current.log
```

Logs contain local paths and device details. Review relevant excerpts before
sharing them. More diagnostic commands: [Development and testing](docs/DEVELOPMENT.md).

## What belongs in the GitHub repository?

Upload this folder's contents, including `.gitignore`. Files under `probe/`,
`tools/`, `tests/`, and `docs/`, together with the shared Xcode projects, are the
required sources. A build does not generate any additional files that need to be
committed for another user.

`build/`, `reports/`, `.venv/`, `.local-config.json`, signed apps, game archives,
certificates, and Xcode user settings are excluded. Do not upload these manually
through GitHub's web interface either: `.gitignore` does not protect against
explicitly selecting files there. The other person runs their own setup with
their own game installation and signing configuration.

Porting code and documentation: [MIT License](LICENSE).
Factorio, SDL, and other components: [Scope and notices](THIRD_PARTY_NOTICES.md).
