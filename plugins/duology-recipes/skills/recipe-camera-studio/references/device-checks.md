# What to check on a real iPhone Duo

The studio's capture code typechecks against the iOS 27.1 SDK and builds with no warnings, but no camera has run it yet (`device: no`). Run each line on a device, without `-standIn`, and note what happened. Apple's sources for what to expect: [registering a camera capture accessory](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), [choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces), [the rotation coordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator), and Tech Talks [111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=300) and [111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=488).

| Check | Expect |
|---|---|
| First launch | The camera prompt with the usage string. Allow: the rear camera's preview. Deny: the message and Open Settings. |
| Photo, closed and open | A JPEG in the gallery, upright, the same way the preview showed it |
| Photo with the 3-second and 10-second timer | The countdown on the preview; open, also on the outer display; the photo at zero |
| Switch to video | The microphone prompt; the preview stays |
| Record 10 s, closed; then open while recording | One movie, about 10 s, with sound; the recording carries on through the fold |
| Open, rear camera running | The subject view on the outer display: the subject's live picture, mirrored, with "Look here" |
| Subject view during a countdown and a recording | The countdown, then the recording time, large |
| Subject View button off, then on | The outer display goes dark, then comes back |
| Book, then tabletop, with the subject view showing | Note whether the system keeps it. Apple's conditions say fully open; the simulator kept it in both. |
| Rotate the open phone in each pose, then take a photo | Both previews upright; the photo upright |
| Switch Camera to the front camera, open and closed | The virtual front camera follows the app between displays; the preview is mirrored; the subject view shows only the countdown |
| Split View with another app on the inner display | The session is interrupted (`.videoDeviceNotAvailableWithMultipleForegroundApps`); capture comes back at full screen. The app shows no message for this yet: add `duo-camera`'s `CaptureStatus` if you need one. |
| Close the phone while the subject view shows | It goes away; the photographer's preview keeps running on the outer display |
| Share a photo, then Save Image | The add-only photo library prompt, with the usage string |
| A second preview layer on one session | Both previews live at once. If one freezes, show the countdown alone on the outer display. |
