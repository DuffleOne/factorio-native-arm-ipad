# Development and local checks

First complete setup and a device build as described in the [README](../README.md).
Run all commands here from the repository root.

## Check a build without Xcode signing

```sh
.venv/bin/python tools/prepare_sdl.py --sdk iphoneos
.venv/bin/python tools/build_probe.py --sdk iphoneos --uikit --bundle-data
.venv/bin/python tools/verify.py
```

`build_probe.py` generates its own audit from the selected original executable
and the installed SDK. No pre-generated reports are required. The resulting app
bundle is ad hoc signed and intended for local analysis. Installing it on a
physical iPhone or iPad still requires Xcode development signing.

`verify.py` checks the original hash, the recorded original bytes of all
instruction patches, unchanged file-backed original sections after reversing
those patches, platforms, and signatures. Game simulation is checked only when
you explicitly provide your own benchmark log. These checks do not replace a
graphical device test.

## Small simulation probe on a device

Save your game before terminating a running app. Set `FACTORIO_DEVICE_ID` and
`FACTORIO_BUNDLE_ID` as described in the README; the development-signed app must
already be installed.

```sh
mkdir -p reports
xcrun devicectl device process launch \
  --device "$FACTORIO_DEVICE_ID" --terminate-existing --console --timeout 120 \
  "$FACTORIO_BUNDLE_ID" --probe-core > reports/core-ipad.log 2>&1

xcrun devicectl device process launch \
  --device "$FACTORIO_DEVICE_ID" --terminate-existing --console --timeout 120 \
  "$FACTORIO_BUNDLE_ID" --probe-benchmark > reports/benchmark-ipad.log 2>&1

.venv/bin/python tools/verify.py --benchmark-log reports/benchmark-ipad.log
```

The first probe creates `Documents/Factorio/user/probe-map.zip` in the app
container; the second simulates that exact small map for 120 updates. Expected
output includes `Performed 120 updates`, a checksum, and `Goodbye`. For the
Factorio 2.1.23 Space Age installation tested on the iPhone Duo, the checksum
is `4032494708`; this matched the original Mac game and the simulator.
The probe does not overwrite normal saved games; running the first probe again
replaces `probe-map.zip`.

This local build retains the owned Space Age, Quality, and Elevated Rails assets
when present in the source installation. With all three expansion mods enabled,
the original macOS 2.0.77 executable produced checksum `2376201887` on the same
64 × 64, seed 12345, 120-update probe on October 7, 2026. For an iPad probe with
the same mods, explicitly compare against that native baseline:

```sh
.venv/bin/python tools/verify.py --benchmark-log reports/benchmark-ipad.log \
  --benchmark-checksum 2376201887
```

For 2.1.23 Space Age, use `--benchmark-checksum 4032494708` instead. The default
checksum remains the upstream 2.0.77 base-game value. A matching small
simulation does not establish graphical or full Space Age gameplay compatibility.
The local iPad run on October 7, 2026 matched `2376201887`, and a separate
graphical run reached the Space Age main menu after about 72 seconds. This does
not test large saves, progression through the expansion planets, or multiplayer.

Launching without arguments starts the normal game again. If you run these
probes through an Xcode scheme instead of the CLI, remove the launch arguments
afterward.

## Device screenshots / UIKit test helper

`tools/device_ui.py` builds and installs a separate XCTest helper. It is optional
and is not required for playing. Here, `--device` expects the **UDID from Xcode's
device view**, which may differ from the CoreDevice identifier used by
`devicectl`. Substitute your own values:

```sh
.venv/bin/python tools/device_ui.py \
  --device "YOUR_IPAD_UDID" \
  --team "$FACTORIO_TEAM_ID" \
  --bundle-id "$FACTORIO_BUNDLE_ID"
```

This command activates the installed app and exports screenshots to
`reports/DeviceUI-…/`. Use `--button 'Inventory'`, `--key Tab`, and
`--tap 0.5 0.4` for targeted actions. To run multiple actions in a specified
order, pass a JSON array to `--actions`; example entries include
`{"button":"Menu"}` and `{"x":0.5,"y":0.4}`. These actions affect the running
game. Screenshot tests check only that the app is in the foreground; assess the
actual game response by inspecting the images.

On the iPhone Duo, XCTest may capture its primary/outer display instead of the
active inner game display. For Duo graphics checks, use the
[inner-display screenshot procedure](IPHONE_DUO.md#physical-display-check-and-simulator-limits).

The helper uses fresh DerivedData for each run. This avoids an issue observed
in the original project where a reused test runner had inconsistent signatures.
To remove only this helper:

```sh
xcrun devicectl device uninstall app \
  --device "$FACTORIO_DEVICE_ID" local.factorio.probesnapshot.xctrunner
```

## Simulator CLI (optional)

### iPhone Duo simulator checks

The iPhone Duo profile requires **Xcode 27.1 and the iOS 27.1 simulator runtime**.
An iOS 27.0 runtime cannot boot this profile. If multiple Xcode versions are
installed, set `DEVELOPER_DIR` to the desired app's `Contents/Developer` directory.
Use `xcrun simctl list devices available` to obtain the simulator UDID.

Build the universal simulator app with the same source game and expansion assets:

```sh
.venv/bin/python tools/prepare_sdl.py --sdk iphonesimulator
.venv/bin/python tools/build_probe.py --sdk iphonesimulator --uikit --bundle-data \
  --bundle-id "$FACTORIO_BUNDLE_ID"
.venv/bin/python tools/verify.py --sdk iphonesimulator
xcrun simctl install "$FACTORIO_SIMULATOR_ID" build/FactorioProbe.app
xcrun simctl launch --console "$FACTORIO_SIMULATOR_ID" "$FACTORIO_BUNDLE_ID" --probe-core
xcrun simctl launch --console "$FACTORIO_SIMULATOR_ID" "$FACTORIO_BUNDLE_ID" --probe-benchmark
```

The separate UIKit control harness exercises the production `TouchControls.m`
without loading the game renderer. It checks safe-area bounds, control overlaps,
keyboard bounds/visibility, cursor coordinates after resizing, and release of
held input. It also checks that a mouse button remains down until touch-up.
SDL input endpoints are recording sinks in this harness; it does not
prove in-game input integration or graphical gameplay.

```sh
.venv/bin/python tools/test_touch_controls.py --device "$FACTORIO_SIMULATOR_ID"
```

Results and rendered control screenshots are copied to `reports/touch-controls/`.
Eight cases passed on the iPhone Duo / iOS 27.1 simulator: seven representative
window sizes, including the inner display, and the simulator's actual window/safe
area.
The 2.0.77 Space Age map creation and 120-update probe also passed, matching the
Mac and physical iPad checksum **2376201887**. A 2.1.23 Space Age probe matched
the Mac and physical iPhone checksum **4032494708**. Simulator timing is not a
phone performance measurement: the simulator uses the Mac's resources.

Normal graphical startup currently fails: the simulated Metal device reports
no Mac1/Apple7 GPU-family support and no BC texture compression, and the game's
OpenGL fallback cannot create its context. Physical iPhone graphics, complete
gameplay and live fold/unfold transitions remain unverified. The physical Duo
rendered both the Space Age main menu and an early tutorial scene on its
2853 × 2007 inner display, with the bottom HUD visible. SDL must use the active
window scene's orientation during later frame updates; the global status-bar
orientation can be unknown and crop the view to 669 points wide. Capture the
inner display with `xcrun devicectl device capture screenshot` and run
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift tests/check_duo_viewport.swift <screenshot.png>`
to detect the black right-edge regression. The existing
`--simulator-metal` option is diagnostic only and is forbidden for device builds.
That diagnostic reached Metal initialization on the Duo simulator, then failed
texture validation for pixel format 134 (`BC3_RGBA`), confirming the simulator's
graphics limitation. The standard build does not include this diagnostic bypass.

On the physical Duo, the inset build leaves the UIWindow at 951 × 669 points.
The game view uses the larger of the system safe area and 16 points at the top
and sides, with a fixed 16-point bottom margin matching the Duo's top margin.
The tested landscape game view is 919 × 637 points / 2757 × 1911 pixels.
Capture a game screen and run
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift tests/check_duo_safe_viewport.swift <screenshot.png>`
to check that game pixels no longer reach the unsafe side and bottom edges.

### Other simulator CLI probes

Start an iPad simulator in Xcode. If several simulators are running, use the
appropriate identifier from `xcrun simctl list devices` instead of `booted`.
These instructions use the default bundle identifier `local.factorio.loaderprobe`:

```sh
.venv/bin/python tools/prepare_sdl.py --sdk iphonesimulator
.venv/bin/python tools/build_probe.py --sdk iphonesimulator --uikit --bundle-data
xcrun simctl install booted build/FactorioProbe.app
.venv/bin/python tools/run_probe.py create --device booted
.venv/bin/python tools/run_probe.py benchmark --device booted
.venv/bin/python tools/verify.py --sdk iphonesimulator \
  --benchmark-log reports/benchmark-simulator.log
```

The runner script creates its own diagnostic configuration and `probe-map.zip`
in the simulator; it is not intended to manage a normal simulator game session.
For a custom identifier, pass `--bundle-id` to both `build_probe.py` and
`run_probe.py`. See [Architecture](ARCHITECTURE.md) for the known simulator
graphics limitation.

## Local source compatibility tests

The Python tests do not contain or download game files. To check the experimental
variant against your own installation, including rejecting altered patch layouts:

```sh
FACTORIO_TEST_APP="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app" \
  .venv/bin/python -m unittest discover -s tests -v
```

Without `FACTORIO_TEST_APP`, checks requiring the game are explicitly skipped.
These checks do not replace `tools/verify.py`, simulation, or physical iPad tests.
Builds made before source hashes were added to patch manifests must be rebuilt
before using the updated verifier.

The SDK audit accepts Xcode 27's `arm64e-ios` and `arm64e.x1-ios` system-library
exports as well as the earlier `arm64-ios` exports. Catalyst and macOS exports
remain excluded. Small standalone TBD fixtures test that discovery and library
reexports without requiring an installed SDK.

## Check the repository before uploading

After a local `git init`, use `git status --short --ignored` to see which files
are excluded. Check `git diff --cached --stat` before committing. Generated
copies of the original executable, SDL downloads, game assets, diagnostic
reports, and local signing files do not belong in the source repository.
A fresh checkout must be able to generate them locally.

No automatic deployment, GitHub upload, release upload, or CI download of
Factorio is configured. The build reads only your existing local installation
and downloads only the specified SDL version as a build dependency.
