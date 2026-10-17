# The 15 rules in depth

Each rule says why it exists, what to look for in the frames, what passes and fails, the default severity, and what to do when a still frame can't show it. Fix code for each rule is in [fixes.md](fixes.md).

Coordinates are in points. Screenshot pixels are points × 3. The fold band and camera regions are in [frames.md](frames.md).

---

## R1 No letterboxing

**Why.** An app built with the iOS 27.1 SDK fills both displays edge to edge. Built with the iOS 26 SDK or earlier, it runs at a familiar iPhone size in the middle of the inner display with empty space around it, and sits left of the status bar and camera on the outer display. Built with the iOS 27 SDK, it fills most of the inner display but still leaves the status bar strip on the right ([prepare page](https://developer.apple.com/iphone-duo/prepare/), [talk 111461, 0:30](https://developer.apple.com/videos/play/tech-talks/111461/?time=30)). Games should change their aspect ratio rather than letterbox; if they can't, fill the padding with artwork ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)). Full-bleed hero images and video can lose their subject on wider displays ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

**Look for.**
- Black or empty bands on any edge of either display.
- A phone-shaped window floating in the middle of the inner display.
- On the outer display, background that stops at the trailing column instead of running under the status bar.
- A game or canvas with plain bars on two sides.
- A hero image or video whose subject (a face, a product, text) is cut off in one shape but not the other.

**Passes.** Backgrounds reach every edge. Foreground content sits inside the safe area. A game shows artwork, not bars, in any padding.

**Fails.** Any of the above.

**Severity.** Blocker when the whole app is letterboxed: rebuild with Xcode 27.1 first, then review again. Major for a letterboxed game or canvas. Minor for a cropped hero image.

**Fix.** [fixes.md, R1](fixes.md#r1-no-letterboxing).

---

## R2 State survives fold and unfold

**Why.** People open and close the phone often while using an app. Apple asks for the same functionality and the same state of elements on both displays ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices), [talk 111466, 7:34](https://developer.apple.com/videos/play/tech-talks/111466/?time=454)). Android's adaptive quality guide tests the same thing as T-Config_State ([Android](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality)); treat that as prior art, not an Apple rule.

**Look for.** Compare a closed frame and an open frame taken at the same moment, then the reverse:
- the same screen and navigation depth;
- the same selected item;
- the same scroll position (the same first visible item);
- the same text in fields, with the keyboard focus kept;
- the same playback position, and playback still running;
- uploads, forms and sign-in not restarted.

**Passes.** Open shows the same place, perhaps with one more level of hierarchy beside it (Mail shows the list next to the message).

**Fails.** Open jumps to the root, to the top of a list, to an empty editor, or restarts a video.

**Severity.** Blocker if typed text, playback or an upload is lost. Major for lost scroll, selection or navigation.

**Can't see it?** A single frame can't prove state. Mark Check and ask for the closed/open pair. In Figma, check that the closed and open frames of one flow show the same content and selection.

**Fix.** Load `duo-continuity`. [fixes.md, R2](fixes.md#r2-state-survives-fold-and-unfold).

---

## R3 No size from the main screen

**Why.** On iPhone Duo the app's size changes on every fold and often doesn't match the screen. `UIScreen.main` is ambiguous on a phone with two displays and is deprecated since iOS 26.0. Size from the view, window or scene, and re-read it on every change. Don't choose layouts by idiom, by "regular width means iPad", by orientation, or by known device heights ([prepare page](https://developer.apple.com/iphone-duo/prepare/), [talk 111461, 3:57](https://developer.apple.com/videos/play/tech-talks/111461/?time=237), [`UIScreen.main`](https://developer.apple.com/documentation/uikit/uiscreen/main)).

**Look for.**
- Content laid out for the other display: tiny on the inner display, clipped on the outer one.
- A fixed-width column (often 375, 390 or 430 pt wide) with dead space beside it.
- An iPad layout that appears whenever the width is regular, with iPad-only features that make no sense on a phone.
- A layout that stays the same after the window changes size (Split View, PiP, unfold).
- In Figma: frames made by stretching another iPhone frame, or fixed widths and absolute positions instead of constraints.

**Passes.** Each frame looks designed for its own size. Columns, margins and type follow the space.

**Fails.** Any of the above.

**Severity.** Major. Blocker when content or a control becomes unreachable.

**Fix.** [fixes.md, R3](fixes.md#r3-no-size-from-the-main-screen). For code, run `duo-lint`.

---

## R4 Nothing interactive in the fold

**Why.** Buttons are hard to tap when they land in the fold. System sheets, alerts, menus and toolbar buttons move aside on their own when the phone is partly folded; custom controls must do the same ([talk 111466, 9:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=568), [HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). Apple calls the move displacement: move the smallest unit that works, keep related things together, don't move them far, and never displace scrolling content ([talk 111463, 2:26](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)). The cameras are reserved regions too: keep important controls clear of the inner camera while it's active ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=27)).

**Look for.**
- In partly folded frames: any button, slider, switch, text field, segmented control, tab item, drag handle or floating action button that touches the fold band.
- In flat held-wide frames: controls centred on the fold line. They are fine flat, but ask for the folded frame to see where they go.
- Controls under the outer camera or the status bar corner, or under the inner camera on a capture screen.

**Passes.** Partly folded, every control sits wholly on one side of the band. Scrolling lists and feeds may run under the fold.

**Fails.** A control overlaps the band when folded, or sits under a camera.

**Severity.** Blocker for a primary action (Play, Send, Buy, Capture). Major for anything else interactive.

**Fix.** Use system components first. For custom controls, read the `.division` region and move them. [fixes.md, R4](fixes.md#r4-nothing-interactive-in-the-fold); patterns: `duo-patterns`, displacement.

---

## R5 Even grids

**Why.** In a grid, an even number of columns lets the fold fall between tiles. Choose an even count whenever a fold crosses the grid, even while it's inactive, so the grid doesn't jump when someone folds the phone. Apple's Fitness example keeps the outer margins and widens the gap at the hinge ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions), [talk 111463, 5:12 and 7:50](https://developer.apple.com/videos/play/tech-talks/111463/?time=312)).

**Look for.** Held wide on the inner display: count the columns of every grid that spans the middle. Find the fold band. Is it in a gutter or through a tile?

**Passes.** 2, 4 or 6 columns with the fold in the middle gap. Partly folded, the middle gap is at least as wide as the fold band.

**Fails.** 3 or 5 columns across the fold, or an even count whose middle gutter sits off the fold because margins are uneven.

**Severity.** Major when a folded frame shows tiles cut by the fold. Minor in a flat frame.

**Don't flag.** Odd counts on the outer display (no fold), or held tall (the fold runs between rows).

**Fix.** [fixes.md, R5](fixes.md#r5-even-grids); full recipe: `duo-patterns`, feed reflow.

---

## R6 Side controls, symbols and titles

**Why.** On the outer display, and on the inner display in landscape, the system gathers the navigation bar, toolbar and tab bar into one vertical bar on the side, under the status bar and Dynamic Island. Inner portrait keeps horizontal bars ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls), [talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/)). The rules for what goes in it:
- Back or Close at the top, then prominent actions such as Done ([talk 111462, 4:29](https://developer.apple.com/videos/play/tech-talks/111462/?time=269)).
- Items from the top bar go to the top of the vertical bar; items from the bottom bar go to the bottom ([talk 111466, 5:07](https://developer.apple.com/videos/play/tech-talks/111466/?time=307)).
- Every item has a symbol and a title. The vertical bar shows the symbol; the overflow menu shows both. A title-only item, or a custom view, stays in a horizontal bar ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).
- Keep text buttons to a minimum. Use the system overflow menu, and keep the ellipsis symbol for it ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).
- Space for content is asymmetric. Content must not sit under the bar ([talk 111461, 7:30](https://developer.apple.com/videos/play/tech-talks/111461/?time=450)).
- Controls that belong to one pane stay with that pane, as Mail keeps the list controls above the list ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).

What the simulator showed us (outer display, closed, iOS 27.1): a toolbar with Close, Done, a text-only Edit and a bottom group of Share and Delete drew one vertical bar on the trailing edge, with Close at the top, Done below it and Share and Delete at the bottom. Edit stayed in a horizontal bar at the top of the content.

**Look for.**
- Closed frames with a tab bar or toolbar along the bottom or top edge: a custom bar, or a mockup that ignores the vertical layout.
- Icon-only items with no title in the spec (check the overflow and VoiceOver labels).
- Many text buttons, or a segmented control in the bar.
- A custom "more" menu next to the system overflow.
- Text or controls under the vertical bar, or centred on the full width when they should be offset.
- In Split View: the left app's bar must be on the left.

**Severity.** Major for a custom horizontal bar on the outer display, content under the bar, or missing titles. Minor for ordering and too many text buttons.

**Fix.** [fixes.md, R6](fixes.md#r6-side-controls-symbols-and-titles); depth: `duo-navigation`.

---

## R7 Tabletop and book layouts

Duology says "tabletop" for Apple's "seated on a table like a laptop" (held tall, the fold running side to side) and "book" for "partially folded, like a book" (held wide, the fold top to bottom).

**Why.** A special layout for the phone on a table is optional. If you add one, put media on top and tappable controls on the stable bottom half, with the same controls and hierarchy as in other poses ([talk 111466, 3:42](https://developer.apple.com/videos/play/tech-talks/111466/?time=222)). Partly folded like a book, alerts move to the trailing side, near where they appear once the phone closes ([talk 111463, 4:00](https://developer.apple.com/videos/play/tech-talks/111463/?time=240)). Split views even out to 50/50 at the fold ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).

**Look for.**
- Tabletop: video, a call or a recipe in the top part; transport, camera or step controls in the bottom part; nothing interactive across the fold.
- Tabletop: every control from the flat layout is still there, or one tap away.
- Book: two panes, or two pages, one per side; no page, image or sentence spanning the fold.
- Book: custom alerts and popovers on the trailing side, not centred on the fold.

**Severity.** Major if a tabletop or book layout removes a control or splits a page across the fold. Minor if a media, call or camera app has no tabletop layout at all: it's optional.

**Fix.** [fixes.md, R7](fixes.md#r7-tabletop-and-book-layouts); two pages: `duo-patterns`, two-page.

---

## R8 Split View and PiP work

**Why.** Every app takes part in Split View on the inner display: two apps share it 50/50, and each puts its bars on its outer edge ([talk 111466, 0:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=28), [talk 111464, 2:59](https://developer.apple.com/videos/play/tech-talks/111464/?time=179)). A Picture in Picture video can be pinned to the top; the app below resizes to the space left, and partly folded the video takes half the display ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=28)).

**Look for.**
- The app in the left half and in the right half: nothing clipped, bars on the outer edge, content clear of both apps' bars.
- The app under a pinned PiP video: a short, wide window; nothing important pushed off screen; no fixed heights.
- A video app: a PiP button, and video that keeps playing when the person leaves.

**Severity.** Blocker if the app breaks, clips a control or can't scroll in a half. Major otherwise, and for a video app with no PiP.

**Don't assume.** We have not measured the size class or point size of a Split View half or of the space under PiP. Judge by what you see, not by a number.

**Fix.** [fixes.md, R8](fixes.md#r8-split-view-and-pip-work). Test Split View in Device Hub by dragging the app by its home indicator to one side, then the other ([talk 111461, 7:30](https://developer.apple.com/videos/play/tech-talks/111461/?time=450)).

---

## R9 Camera preview upright

**Why.** When the phone opens, closes or rotates, the app can move to the other display and the camera in use can point the other way. Adopt the rotation coordinator so the preview and photos stay upright; on iPhone Duo it updates when the app moves displays. Mirror the preview when a rear camera faces the person. Group controls in the space beside the preview, or let the preview fill the display ([talk 111465, 6:17 to 8:47](https://developer.apple.com/videos/play/tech-talks/111465/?time=377), [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces)).

**Look for.**
- Capture screen closed, open and open turned around: the preview is upright in all three, and after a rotation.
- A selfie through a rear camera (open, turned around) looks mirrored like a normal selfie.
- Shutter and mode controls clear of the inner camera region and of the fold.
- On the inner display: either a full preview, or a preview offset to one side with the controls grouped in the rest.

**Severity.** Blocker if the preview or the captured photo is sideways or upside down. Major for wrong mirroring or controls under a camera.

**Can't see it?** Rotation and handover need the running app. Mark Check without a capture sequence. Camera handover between the two front cameras is unverified on the simulator.

**Fix.** [fixes.md, R9](fixes.md#r9-camera-preview-upright); depth: `duo-camera` when it ships.

---

## R10 Same features on the outer display

**Why.** Keep functionality and hierarchy the same on both displays and in every pose. The inner display may show one more level of hierarchy. Don't tie a feature to a display or a pose ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices), [talk 111466, 7:34](https://developer.apple.com/videos/play/tech-talks/111466/?time=454)).

**Look for.** List every action and pane in the open frames. Find each one in the closed frames: in the screen, the vertical bar, the overflow menu, a sheet or one push away.

**Passes.** A supporting pane open becomes a sheet or a pushed screen closed. A sidebar open becomes a tab bar closed.

**Fails.** "Open the phone to edit", a pane with no closed equivalent, or a tabletop-only control.

**Severity.** Blocker.

**Fix.** Map each open-only element to a closed path. Patterns: `duo-patterns`, supporting pane and list-detail.

---

## R11 Multiple windows

**Why.** iPhone Duo is the first iPhone with several windows of one app. Apple's talk says new windows can't be created on the outer display, so handle errors when you request one, and use `UIWindowScene.ActivationAction`, which hides itself when a new window isn't possible ([talk 111464, 3:38](https://developer.apple.com/videos/play/tech-talks/111464/?time=218)). Apple's [ActivationAction doc](https://developer.apple.com/documentation/uikit/uiwindowscene/activationaction) says it shows an alternate action on iPhone and in apps without multiple windows.

**What the simulator did (closed, outer display, iOS 27.1, our probe):** `activateSceneSession(for:errorHandler:)` and SwiftUI's `openWindow(id:)` both succeeded. Each request made a new scene that took over the display; the old one went to the background. No error came back. `supportsMultipleWindows` read `true` while closed, although Apple's doc lists only macOS and iPadOS. We did not test the open phone or a real device. So, until that's checked: don't use `supportsMultipleWindows` to hide window commands on the outer display.

**Look for.**
- An "Open in New Window" command: shown only where it makes sense, and never leaving the person stranded in a new window with no way back to the old one.
- Two windows of the app side by side in Split View: each keeps its own selection and scroll position.

**Severity.** Major for a window command that loses the person's place. Minor (an opportunity, not a defect) for a document app with no multiple-window support.

**Fix.** [fixes.md, R11](fixes.md#r11-multiple-windows).

---

## R12 Smooth transitions

**Why.** Avoid extreme layout changes as the phone folds. Move only what's needed, with small adjustments, so people can follow it ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). Don't move an element far from where it came from ([talk 111463, 2:26](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)). The app should feel like one experience across sizes ([talk 111466, 10:01](https://developer.apple.com/videos/play/tech-talks/111466/?time=601)).

**Look for**, in a recording of close, open, fold and rotate:
- a blank or white frame, a spinner, or a reload;
- a jump to the top of a list;
- elements that swap places, change style and change size at the same time;
- a toolbar item that vanishes and comes back somewhere else.

**Severity.** Major for a reload, blank frame or lost place. Minor for a jumpy but continuous change.

**Can't see it?** Stills can't show motion. Mark Check without a recording. Smoothness at 120 Hz needs a real device: the simulator reports 60 frames per second.

**Fix.** [fixes.md, R12](fixes.md#r12-smooth-transitions); state: `duo-continuity`.

---

## R13 Touch targets of 44 pt

**Why.** Apple's general rule: a button needs a hit region of at least 44 × 44 pt ([HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)). The accessibility page gives 44 × 44 pt as the default iOS control size and 28 × 28 pt as the minimum, with about 12 pt of padding around bezeled controls ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Mobility)). The outer display is wider and shorter than other iPhones, which tempts designers to pack rows tighter.

**Look for.** Measure each tappable element's hit region, not its glyph. In a simulator screenshot, 44 pt is 132 px. Check list rows, chips, icon buttons in custom views, close buttons on cards, and anything near the fold.

**Severity.** Major below 44 pt for a frequent or primary control. Minor for a rare one between 28 and 44 pt.

**Fix.** [fixes.md, R13](fixes.md#r13-touch-targets-of-44-pt).

---

## R14 Hardware keyboard

**Why.** People can connect a physical keyboard to iPhone. They expect standard shortcuts to work, and Full Keyboard Access to reach every control ([HIG, Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)). They expect Space to play and pause media ([HIG, Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video)). Apple's iPhone Duo pages say nothing about keyboards. Duology includes the rule because the inner display invites longer work sessions. (Our reasoning, not Apple's.)

**Look for.**
- Command-N for new, Command-F for find, Command-Z for undo, Esc to cancel a sheet, where the app has those actions.
- Space plays and pauses in a media app.
- No custom shortcut that reuses a standard one for something else.
- While you're there, the on-screen keyboard: on the short outer display in landscape, the focused field must stay visible above it. The keyboard also takes space from the vertical bar, which then overflows sooner ([talk 111462, 11:40](https://developer.apple.com/videos/play/tech-talks/111462/?time=700)). Keyboard accessory bars stay attached to the keyboard, not in the vertical bar ([talk 111462, 9:27](https://developer.apple.com/videos/play/tech-talks/111462/?time=567)).

**Severity.** Minor. Major for text-heavy or productivity apps, and for a focused field hidden by the on-screen keyboard.

**Can't see it?** Stills can't show shortcuts. Mark Check unless you have the running app or a spec of its commands.

**Fix.** [fixes.md, R14](fixes.md#r14-hardware-keyboard).

---

## R15 Drag and drop

**Why.** People try drag and drop everywhere. Apple's HIG names text views on opposite sides of a split view and different apps as typical source and destination. Offer another way, such as a menu command, to do the same thing ([HIG, Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop)). Apple's iPhone Duo pages don't mention drag and drop. Duology includes it because the inner display shows two panes, or two apps in Split View, side by side. (Our reasoning, not Apple's.)

**Look for.**
- Items that people would move (photos, files, notes, links, text): can they be dragged from one pane to the other, and to the other app in Split View?
- A drop target that highlights only while something is over it.
- A non-drag path (Copy, Move to, Share) for the same result.

**Severity.** Minor. Major when moving content is the app's main task, as in a file manager or photo organiser.

**Can't see it?** Mark Check without the running app or a prototype. Device Hub can't send two-finger touches, so test multi-item drags on a device ([Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)).

**Fix.** [fixes.md, R15](fixes.md#r15-drag-and-drop).
