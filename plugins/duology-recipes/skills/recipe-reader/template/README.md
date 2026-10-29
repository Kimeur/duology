# __APP_NAME__

A reading app for iPhone Duo. Pick a book from the shelf and read one page on the closed phone, two facing pages when it opens, and the page above the fold with big page turns below it when you set it on a table half folded. Fold, unfold, turn the phone or change the text size: the same words stay on screen. Made from Duology's `recipe-reader`.

## Run it

```bash
Tools/run-model-tests.sh      # pages, places, layout and shelf, on your Mac, in seconds
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The rules: the library, chapter text, reading places, page breaks and page turns, the reader's layout, the shelf's columns, fold geometry. Foundation and CoreGraphics only. |
| `__APP_NAME__/Text/` | `Paginator`: TextKit 1 page breaks. The Mac tests run it through AppKit. |
| `__APP_NAME__/Reader/` | The reader screen, the page view and the text style. |
| `__APP_NAME__/Library/` | The shelf, the Continue Reading card and the drawn covers. |
| `__APP_NAME__/Shared/` | The fold reader and the test markers. |
| `__APP_NAME__/Books/` | `Library.json` and one plain-text file per chapter. |
| `__APP_NAME__/App/` | The app entry, the root view, the store and the launch switches for tests. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `__APP_NAME__/Assets.xcassets/` | The accent colour and a placeholder app icon: one 1024 × 1024 image, from which Xcode makes the other sizes. Replace the icon with your own before you ship. |
| `Tools/` | The model test program and both test scripts. |

## Your own books

Add a book to `Books/Library.json` and one `.txt` file per chapter next to it. In a chapter file, blank lines separate paragraphs; single line breaks become spaces. File names must be unique across all books: the app bundle keeps them in one folder. Run `Tools/run-model-tests.sh` afterwards: it checks every file is there and has text.

The three sample books were written for this template. Their authors are invented. Replace them before you ship.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-open ID` | Open a book in the reader. |
| `-chapter N` | With `-open`: at this chapter, counting from 0. |
| `-offset N` | With `-open`: at this character in the chapter. |
| `-textStep N` | Text size steps above the system size (negative: below). |
| `-resetState` | Forget every saved place and the text size. |
| `-uiTesting` | Animations off, test markers on. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each by hand: closed, one page; open and held wide, two pages either side of the fold line; folded like a book, the same two pages; Partially Open then Rotate Right (tabletop), the page above the fold and the page turns below it.
- Read to the middle of a chapter, then fold, unfold and rotate: the same paragraph stays on screen.
- Change the text size in the reader's Text Size menu, or in Settings: the pages reflow and the place holds.
