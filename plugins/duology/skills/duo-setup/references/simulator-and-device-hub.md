# The iPhone Duo simulator and Device Hub

Everything an agent can do with the iPhone Duo simulator from the shell, and what only the user can do in Device Hub.

Checked on 16 October 2026 with Xcode 27.1 (27A9275) and the iOS 27.1 runtime (24A94425). Every command on this page ran on that Mac unless the text says otherwise. Set `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer` first.

## Find the device

```bash
xcrun simctl list devicetypes | grep "iPhone Duo"
# iPhone Duo (com.apple.CoreSimulator.SimDeviceType.iPhone-Duo)
xcrun simctl list runtimes | grep "iOS 27"
xcrun simctl list devices available | grep "iPhone Duo"
# iPhone Duo (9F89DDE7-...) (Booted)
```

For scripts, read the JSON form. This prints the UDID of each "iPhone Duo" on the iOS 27.1 runtime:

```bash
xcrun simctl list --json devices available | python3 -I -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print("\n".join(x["udid"] for k,v in d.items() if k.endswith("iOS-27-1") for x in v if x["name"]=="iPhone Duo"))'
```

The Duo device type needs the iOS 27.1 runtime or later. Simulators are shared by every Xcode on the Mac: Xcode 26.5's `simctl` lists the same Duo device.

## Create, boot, delete

```bash
# create: prints the new UDID; the runtime is optional (newest compatible if left out)
xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1

# boot if needed, then wait until it is ready
xcrun simctl bootstatus <UDID or name> -b

# delete a simulator you created
xcrun simctl delete <UDID>
```

- `bootstatus -b` on a booted device prints "Device already booted, nothing to do." It usually returns in about a second. Once it took many minutes on a busy Mac, so agents should run it in the background and poll.
- `xcrun simctl boot` on a booted device fails: code 405, "Unable to boot device in current state: Booted", exit 149. Treat that as success.
- Pass a UDID, not a name, when two devices share a name.
- Several agents or terminals may share one booted simulator. Don't shut it down, erase it or change its settings unless you started it. `booted` picks any booted device when more than one runs.

## Device Hub

Xcode 27.1 runs simulators in Device Hub. It ships `DeviceHub.app` and no `Simulator.app`.

```bash
open "$DEVELOPER_DIR/../Applications/DeviceHub.app"
```

Or, in Xcode, choose Manage Devices from the run destination menu, or Xcode > Open Developer Tool > Device Hub. Running an app on a simulator opens a compact Device Hub window; expand it to see the sidebar, canvas and inspector. The sidebar lists only simulators you added or used as run destinations; add one with the + button ([Apple: managing devices](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub), [Apple: Device Hub](https://developer.apple.com/documentation/xcode/device-hub)).

## Poses: only in Device Hub

`xcrun simctl help` in Xcode 27.1 lists no pose, hinge or fold subcommand. The pose controls sit under the bezel in Device Hub ([Apple: interacting in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)):

- **Closed**: the button to the right of Rotate Right. The app moves to the outer display.
- **Partially Open**: the middle of the three pose buttons. The fold becomes a division region.
- **Open**: the button on the far right. The app fills the inner display.
- **Any angle**: hold Option and drag the slider that appears below the bezel.
- **Rotate**: the rotate button (Option-click rotates right), or Device > Orientation.

Words like "book" or "tabletop" are not Apple names. Apple's controls say Closed, Partially Open and Open. In code, the hinge status is `closed`, `partiallyOpen` or `fullyOpen` (see `reference/device-facts.md` in the Duology repo).

`simctl io <device> screenConfig` can power a screen off or change its geometry. It is not a pose control, and we did not test it. Don't use it to fake a pose.

When a task needs several poses, list them for the user, ask them to click each one, and take a screenshot after each click.

### Split View

On the inner display, the user drags the app by its home indicator to one side, then to the other ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). Two apps share the display 50/50 ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/)), and each app puts its bars on its outer edge ([HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)).

## Screenshots and video of each display

`simctl io` reads the screen and changes nothing:

```bash
xcrun simctl io booted enumerate                                      # lists the display ports
xcrun simctl io booted screenshot --display=primary   outer.png       # outer display
xcrun simctl io booted screenshot --display=primary-1 inner.png       # inner display
xcrun simctl io booted recordVideo --display=primary-1 --force inner.mov   # stop with Ctrl-C (SIGINT)
```

- With the phone open and held wide, `outer.png` came out 2034 × 1398 and black, and `inner.png` 2853 × 2007. The size follows the current orientation.
- These match Apple's App Store sizes for iPhone Duo: 1398 × 2034 (outer) and 2007 × 2853 (inner), portrait or landscape ([screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)).
- Device Hub's own screenshot button saves at full device resolution to the Desktop ([Apple: capturing screenshots](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices)).
- In a script, start `recordVideo` in the background and stop it with `kill -INT <pid>`; it then writes the file.

## Install, launch, read output, clean up

```bash
xcrun simctl install booted path/to/MyApp.app
xcrun simctl launch --terminate-running-process booted com.example.MyApp
xcrun simctl terminate booted com.example.MyApp
xcrun simctl uninstall booted com.example.MyApp
```

- `launch --stdout=<file>` sends `print` output to a file, but the app buffers it. In our run the file stayed empty while the app ran. To see output live, run `launch --console-pty` as a background job and send its output to a file. It blocks until the app ends, and `simctl terminate` ends it. In our run, the setup check's two `DUO-SETUP` lines appeared within seconds.
- Pass launch arguments after the bundle ID. Set environment variables for the app with a `SIMCTL_CHILD_` prefix (`xcrun simctl help launch`).
- Uninstall test apps when you finish, so the shared simulator stays clean.

## Settings you can read (and change with care)

```bash
xcrun simctl ui booted appearance        # light or dark
xcrun simctl ui booted content_size      # e.g. large
```

Both also take a value to change it, for example `appearance dark`. Put the old value back when you finish.

## Known limits

From the [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes) and [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes):

- The first simulator launch can take several minutes.
- StandBy isn't available in the iPhone Duo runtime.
- Most app extensions can't run or be debugged in the iPhone Duo runtime.
- An app using `CameraCaptureAccessory` can use both displays without a capture session. A real device needs one.
- Device Hub can't send a two-finger touch. Trackpad pinch and rotate reach standard UIKit components as pointer events, which is not the same as two fingers on glass. Test multi-touch gestures on a device.
- The simulator reports 60 frames per second at most. Test 120 Hz behaviour on a device (`reference/device-facts.md`).

## Other ways to test resizing

Apple also suggests the resizable iOS simulator in Device Hub and iPhone Mirroring on macOS 27, resized to extreme sizes. It calls the iPhone Duo simulator the best way to test the full native experience ([Apple: Three steps](https://developer.apple.com/iphone-duo/prepare/)). In Xcode Previews, the canvas overrides picker has a Display group for the device's other display ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).
