# Evidence

What we checked for `duo-app-store`. No real iPhone Duo.

## Screenshots from the simulator (23 October 2026)

Xcode 27.1 (27A9275), the iPhone Duo simulator on iOS 27.1, closed and upright, another app in front.

| Command | Result |
|---|---|
| `simctl io <UDID> screenshot --display=primary` | 1398 × 2034 PNG, with an alpha channel. This is the outer display. |
| `simctl io <UDID> screenshot --display=primary-1` | 2007 × 2853 PNG, with an alpha channel, every pixel black: the inner display is off while the phone is closed. |
| `sips -s format jpeg -s formatOptions 92` on the 2007 × 2853 PNG | JPEG at the same size, no alpha. |
| `simctl io <UDID> screenshot --type=jpeg --display=primary` | 1398 × 2034 JPEG, no alpha. |
| `scripts/duo-shots`, with no `UDID` set | Found the booted iPhone Duo, wrote `<name>-outer.jpg` (1398 × 2034, JPEG, no alpha) and printed "skip inner … black". |
| `simctl status_bar <UDID> override --time 9:41 …`, then `clear` | Both returned 0. The frames had no visible status bar (a sheet covered it), so the effect on each display is unverified. |

A full-size black JPEG weighs about 92 KB, about as much as a plain screen, so file size can't tell a blank frame from a real one. `duo-shots` checks the mean colour instead (the frame shrunk to one pixel).

Both sizes match App Store Connect's list for iPhone Duo. The earlier device facts (16 October 2026) recorded the same displays turned: 2034 × 1398 and 2853 × 2007.

## App Store Connect API (18 October 2026)

From a maintainer's real submission, with the App Store Connect API:

- Creating an `appScreenshotSets` record with an unknown display type returned an error that listed the accepted values; `APP_IPHONE_DUO` was among them.
- Screenshots of the inner display at 2007 × 2853 were accepted in an `APP_IPHONE_DUO` set.
- Not recorded: whether 2853 × 2007 or the outer sizes were accepted in the same set.

On 23 October 2026, Apple's [ScreenshotDisplayType](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype) reference listed 33 values and none for iPhone Duo.

## Apple's pages (23 October 2026)

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications): the four Duo sizes, 1 to 10 per set, JPEG or PNG without alpha, the badge, and the April 2027 rule for apps using the iOS 27.1 SDK or later.
- [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications): 886 × 1920 and 1920 × 886, labelled 19.5:9, next to the device sizes 2034 × 1398 and 2853 × 2007, which aren't 19.5:9.
- [News of 5 October 2026](https://developer.apple.com/news/?id=kkphp5qo): the badge, the preview tool, and "any apps or games submitted" needing Duo screenshots from April 2027.
