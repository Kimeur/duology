---
id: duo-scenes/camera-subject-view
skill: duo-scenes
title: Show the person being filmed a countdown on the outer display
readme: no
fixture: Shoot
project: Shoot.xcodeproj
scheme: Shoot
build: yes
lint: yes
checklist: R10
timeout: 1800
status: ready
---

# Show the person being filmed a countdown on the outer display

When iPhone Duo is fully open and an app captures with the rear camera, the app can show extra content on the outer display through a camera capture accessory: `CameraCaptureAccessory` inside `.sceneAccessory` in SwiftUI, or `UISceneAccessory.cameraCapture(sceneConfiguration:)` in UIKit. The system decides when it shows, so the app must work without it ([Registering a camera capture accessory](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), [api-index.md](../../../reference/api-index.md#scenes-and-scene-accessories)). The other accessory in the SDK, `ExternalNonInteractiveAccessory`, is for connected displays; Apple names no other route to the outer display while the app runs on the inner one.

## Prompt

```text prompt
This is a camera app for filming other people. On iPhone Duo, when the phone is open and the rear camera is filming, show the person being filmed the countdown and a recording light on the outer display. The person filming must be able to turn that off. Everything must keep working when the outer display can't be used.
```

## Starting point

Fixture [`Shoot`](../../fixtures/Shoot): a full-screen rear camera preview with a record button (`shoot.record`), a 3-second countdown and a recording badge, all driven by one `CameraModel`. iOS 17 target, Swift 5. The simulator has no camera, so the preview says "Camera unavailable"; the countdown and badge still work. duo-lint finds nothing.

The deployment target is below iOS 27.1, so the build gate also checks that the accessory code sits behind an availability check.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing (so no `UIScreen.screens`).

```sh check uses-the-camera-accessory
has_src 'CameraCaptureAccessory|cameraCapture\(sceneConfiguration'
has_src 'sceneAccessory|registerSceneAccessory'
```

```sh check no-display-hunting
# External-display scenes and non-interactive accessories are for connected
# displays, not the outer display.
no_src 'UIScreen\.screens|ExternalDisplay|ExternalNonInteractiveAccessory|externalNonInteractive'
```

```sh check follows-availability
# The app hears when the system shows or hides the accessory.
has_src 'onAvailabilityChange|\.isAvailable'
```

```sh check can-be-turned-off
# A setting the person filming controls: the accessory's isEnabled.
has_src 'CameraCaptureAccessory\(isEnabled:|\.isEnabled *='
```

```sh check record-kept
has_src '"shoot.record"'
```

```sh check one-camera-model
# The accessory shows the same model as the main screen, so its countdown matches.
pycheck single_owner.py 'CameraModel\('
```

```sh check launches
launch_ok
```

## Checklist

The simulator shows the accessory without a running capture session (an Xcode 27.1 known issue), so this checks layout only. Availability with a real camera needs a device.

- **R10**: Open: start a recording. The countdown and the recording badge still show on the inner display, the record button works, and the switch that turns the outer display view off is reachable. Closed: the app works the same, with no error and no missing control.
- Outside the rule verdict, note what the outer display shows in the simulator when open: the countdown, then the recording light, readable from a distance.
