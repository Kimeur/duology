---
id: duo-camera/front-camera-switch
skill: duo-camera
also: duo-postures, duo-continuity
title: Switch to the front camera on both displays
readme: no
fixture: Shoot
project: Shoot.xcodeproj
scheme: Shoot
build: yes
lint: yes
checklist: R4 R10 R13
timeout: 1800
status: ready
---

# Switch to the front camera on both displays

iPhone Duo has a front camera above each display. Apps that ask for the usual front camera (`.builtInWideAngleCamera` or `.builtInUltraWideCamera` at `.front`) get a virtual front camera that streams from the camera above the display the app is on, and switches when the phone opens or closes ([Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces)). The two physical front cameras (`.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera`, iOS 27.1) both report `position == .front`, so an app that picks one of them must ask `AVCaptureDeviceDirectionCoordinator` (AVKit) which way it faces. Previews and recordings stay upright through rotation with `AVCaptureDevice.RotationCoordinator` ([doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)), which duo-camera remakes after every camera switch.

## Prompt

```text prompt
Add a button that switches between the back camera and the front camera, for selfie videos. On iPhone Duo it has to work closed, on the outer display, and open, on the inner display. The preview must stay upright and the selfie preview must look like a mirror, also when the phone is opened, closed or rotated while the camera runs. Keep the record button and its accessibility identifier.
```

## Starting point

Fixture [`Shoot`](../../fixtures/Shoot): a full-screen rear camera preview with a record button (`shoot.record`), a 3-second countdown and a recording badge, all driven by one `CameraModel`. iOS 17 target, Swift 5. The simulator has no camera, so the preview says "Camera unavailable"; the countdown and badge still work. duo-lint finds nothing.

The model asks for `.builtInWideAngleCamera` at `.back` with `AVCaptureDevice.default`, and nothing turns the preview when the device rotates.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check has-front-camera
has_src '\.front\b'
```

```sh check physical-cameras-need-direction
# The two physical front cameras both report position .front. Which way each one
# points depends on the display, so code that picks one must ask a direction
# coordinator. The virtual front camera switches by itself and needs none.
if [ -n "$(src_grep 'builtInOuterUltraWideCamera|builtInInnerUltraWideCamera')" ]; then
  has_src 'AVCaptureDeviceDirectionCoordinator'
fi
```

```sh check rotation-from-coordinator
# Upright preview and video through rotation and fold: a rotation coordinator,
# not the device orientation.
has_src 'RotationCoordinator'
```

```sh check no-orientation-guessing
no_src 'UIDevice\.current\.orientation|\.videoOrientation\b|statusBarOrientation'
```

```sh check record-kept
has_src '"shoot\.record"'
```

```sh check launches
launch_ok
```

## Checklist

The simulator has no camera (duo-camera measured that every discovery session returns no device), so preview rotation and mirroring (R9) need a device and are not part of this verdict. Note on a device, if you have one: the selfie preview mirrors closed and open, and stays upright through rotation and fold.

- **R4**: partly folded, the switch and record buttons stay off the fold and clear of the inner camera, which is an occlusion while it runs.
- **R10**: closed, the switch button is there and works; the app shows no error that the open phone doesn't.
- **R13**: the switch button is at least 44 × 44 pt.
