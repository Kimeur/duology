# Kids rules, the privacy manifest, and what the owner sets

What App Review asks of apps for children, how the template meets each point, and the App Store Connect answers that only the app's owner can give. Apple's pages are paraphrased here, never quoted at length; read them before you submit. This is not legal advice: children's privacy laws differ by country, and a lawyer should check yours.

Sources, checked 25 October 2026: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (1.3, 2.3.8, 5.1.1, 5.1.4), Apple's page on [designing safe, age-appropriate experiences](https://developer.apple.com/app-store/kids-apps/), App Store Connect Help on [age ratings](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) and [app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), and the [required reasons for UserDefaults](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## What App Review asks

| Rule | In our words | In the template |
|---|---|---|
| 1.3, Kids Category | Links out of the app, purchases and other distractions belong only in a set-apart area behind a parental gate. | The only link (the privacy policy) and the only destructive control (Reset Progress) sit in the grown-ups area. There are no purchases. A model test fails if a link appears in any other file. |
| 1.3 | Kids Category apps should avoid third-party analytics and advertising; the narrow exceptions require that nothing identifying a child or device is collected or sent. | No analytics, no ads, no third-party code at all. |
| 1.3 | No personal or device information goes to third parties, including data that could identify someone when combined. | No networking code. A model test fails on `URLSession`, `NWConnection`, web views, the advertising identifier, `identifierForVendor`, App Tracking Transparency, CloudKit and more. |
| 1.3 | An app that once met the Kids Category rules keeps meeting them in later updates, even after leaving the category. | Keep the model tests in your build. |
| 5.1.4, Kids | Handle children's data with care and follow laws such as COPPA and GDPR. A Kids Category app needs a privacy policy. A parental gate is not parental consent to collect data. | Nothing leaves the device, so there is nothing to consent to. If you add collection, the gate is not enough. |
| 2.3.8 and 5.1.4(b) | Words such as "For Kids" and "For Children" in the name, subtitle, icon, screenshots or description are kept for Kids Category apps. | The template's name and texts don't use them. Watch your store text. |
| 5.1.1(i) | Every app links its privacy policy in App Store Connect and inside the app, somewhere easy to find. | Inside the app, one gate away in the grown-ups area. Our reading is that this satisfies both 1.3 and 5.1.1(i) for a Kids Category app (*unverified* with App Review). |

## The parental gate

Apple's kids page describes a parental gate as an adult-level task, shows a maths problem and a question as examples, and suggests a spoken prompt so that children who can't read know to fetch a parent. It also says what gates are for: purchases, and links to websites, social networks or other apps.

The template's gate:

- **The task:** a multiplication of a number from 6 to 9 by one from 4 to 9 (answers 24 to 81), typed on a number pad. Our choice: hard for the 5-and-under and 6-to-8 bands, a moment's work for an adult. The number pad gives no hint: it takes up to three digits.
- **A wrong answer closes the gate.** The next opening asks a different question; a question is never asked twice in a row, and every question is used once, passed or not.
- **The spoken prompt:** when the gate opens, the app says that this part is for grown-ups (unless the parent turned speech off, or VoiceOver is on, which reads the heading instead). A speaker button repeats it.
- **Seeded:** the questions come from `SeededGenerator` (SplitMix64). The app seeds it at random on each launch; UI tests pass `-gateSeed 42` and get the same questions every time (debug builds only).
- **The grown-ups area locks again** when it closes. Nothing behind the gate stays open.

Tested on the Mac: same seed, same questions; factors in range; every pair of factors comes up in 2,000 draws; never the same question twice in a row; digits only, at most three, no leading zero; an empty entry counts no attempt; wrong answers fail and count; right answers pass. On the simulator: a wrong answer closes the sheet, the next question differs, the right answer opens the grown-ups area, Done locks it again, and the same seed asks the same first question after a relaunch.

## The privacy manifest

`PrivacyInfo.xcprivacy` in the app target ([privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)):

| Key | Value | Why |
|---|---|---|
| `NSPrivacyTracking` | false | The app doesn't track. |
| `NSPrivacyTrackingDomains` | empty | It connects to nothing. |
| `NSPrivacyCollectedDataTypes` | empty | Nothing is sent off the device. |
| `NSPrivacyAccessedAPITypes` | `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` | Progress and the speech setting are saved in UserDefaults. CA92.1 is the reason for defaults that only the app itself reads and writes. |

The same file as `recipe-reader`'s. The model tests read it: they fail if tracking is on, if a domain or data type appears, or if the app uses `UserDefaults` or `@AppStorage` without CA92.1 (or declares it without using them). Before you submit, generate Xcode's privacy report from the archive (Organizer, Generate Privacy Report).

Speech uses `AVSpeechSynthesizer`, which runs on the device and needs no usage description. The app never records audio or uses speech recognition (which can send audio to Apple); a model test fails on `SFSpeechRecognizer`.

## What the owner sets in App Store Connect

The template can't make these choices. Each one is the owner's, and some can't be undone.

1. **Kids Category and age band.** App Information, Age Ratings, Set Up Age Ratings: answer the questionnaire, then under Age Categories and Override choose Made for Kids and an age range (5 and under, 6 to 8, or 9 to 11). The calculated rating has to be 4+ or 9+. Once App Review approves the app, the choice can't be changed, and every later update must follow the Kids rules ([help](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)). The sample's activities suit the 5-and-under and 6-to-8 bands.
2. **Privacy answers.** App Privacy, Get Started: if the app and any partners collect nothing, answer "No, we do not collect data from this app" and save ([help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)). Apple counts data as collected when it leaves the device in a form you or a partner can read for longer than it takes to serve the request ([details](https://developer.apple.com/app-store/app-privacy-details/)); data kept on the device isn't collected. The template qualifies as shipped. Change the answer the day you add anything that sends data.
3. **Privacy policy URL.** Required for iOS apps, entered on the App Privacy page. Use the same address as `AppFacts.privacyPolicy` in the app, and replace the template's `https://example.com/privacy` first.
4. **Primary category.** The project sets `public.app-category.education` in the Info.plist; App Store Connect has its own category setting.
5. **Store text and screenshots.** Real screens with the sample or your own content, the closed and open phone (see `duo-app-store`), and no "For Kids" wording unless the app is in the Kids Category.

## Things the template leaves to you

- Verifiable parental consent, accounts, cloud sync, purchases or ads. Each one changes the privacy manifest, the App Store Connect answers and the Kids Category rules that apply; the model tests will flag most of them.
- Localisation. The questions, the spoken prompts (`AppFacts.speechLanguage`, `en-US`) and the gate's prompt are English.
- A real privacy policy page.
