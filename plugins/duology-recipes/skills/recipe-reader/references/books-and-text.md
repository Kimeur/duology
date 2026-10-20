# Books and text in the reader recipe

Your own books, how the text is set, Dynamic Type, and what we measured in each pose. For the general reading rules (selection, notes beside the page, PDFs, Apple Pencil), load `duo-reading`.

## Your own books

`Books/Library.json` lists the books:

| Field | Type | Notes |
|---|---|---|
| `books[].id` | text | Unique. The launch switches and UI tests use it. |
| `title`, `author`, `summary` | text | |
| `kind` | text | A short label for the cover: "A story", "A field guide". |
| `colors` | two hex strings | `"1F4E79"`, for the drawn cover's gradient. |
| `chapters[].title` | text | The chapter's first paragraph, set larger. |
| `chapters[].file` | text | A UTF-8 `.txt` file next to `Library.json`. |

A chapter file is plain text. Blank lines separate paragraphs; a single line break inside a paragraph becomes a space; spaces at the start and end of a line go. Use typographic quotes and apostrophes in the file; the reader shows exactly what you write. File names must be unique across all books: Xcode copies the folder's files flat into the app bundle.

`Tools/run-model-tests.sh` reads the real files and checks that the library decodes, IDs and file names are unique, every chapter has text and paragraphs, and no line holds a double space.

- **Long books.** The reader paginates one chapter at a time, on the main actor. `duo-reading` measured 2.75 s for 558,000 characters on the simulator, so split long books into chapters of tens of thousands of characters, not one file. The sample chapters are about 3,600 to 4,700 characters each.
- **The place across editions.** An offset counts UTF-16 units in the chapter as `ChapterText` builds it (the title, a line break, then the paragraphs). Edit a chapter and saved offsets after the edit shift. For books that change, store a paragraph number and an offset inside it instead.
- **EPUB and HTML.** Not in the template. An EPUB is a zip of XHTML chapters; turn each into a title and paragraphs and the rest of the reader stays the same. We have not built or tested that.
- **The sample books** were written for this template, about 6,400 words in all, and their authors are invented. Replace them before you ship.

## How the text is set

`Reader/TextStyle.swift` builds one `NSAttributedString` per chapter. The paginator measures it and the pages show slices of it, so change the look there and nowhere else.

| Choice | Value | Why |
|---|---|---|
| Body font | The system serif (New York) for `.body`, through `UIFontDescriptor.withDesign(.serif)` | A book face that scales with Dynamic Type. |
| Title | Serif `.title1`, bold | The chapter's first paragraph. |
| Line height | `lineHeightMultiple` 1.12 | A little air on a narrow page. |
| Paragraph spacing | 0.6 of the font's point size | Paragraphs apart without indents. |
| Alignment | natural (left in English, right in right-to-left languages) | A page shows a slice of the chapter. Justified text would leave the last line of a page ragged when the page ends mid-paragraph, and a first-line indent would indent a page that starts mid-paragraph. |
| Hyphenation | `hyphenationFactor` 0.6 | Fewer ragged lines at 320 pt. |
| Colour | `UIColor.label` | Light and dark mode with a clear page. |

`PageInsets` sets the page around the text: 40 pt for the running head, 36 pt for the page number, at least 24 pt at the sides, and lines no longer than 600 pt (on a tall single page the side margins grow instead). The running head is the book's title over the leading page of a spread and the chapter's title elsewhere.

## Dynamic Type

- The reader reads `dynamicTypeSize` from the environment and moves it by `ReadingLog.textStep`: the Text Size menu's Larger Text and Smaller Text buttons. Default Size goes back to the system size. The step is kept inside the 12 sizes, so it can't grow past AX5.
- The type size is in the pagination key. A new size paginates at once; the offset stays, and the page that holds it shows.
- The page furniture (running head, page number) stops growing at `xLarge`, and the covers keep `large`: they are decoration, and VoiceOver reads the page number from the page's label instead.
- Two pages stay two pages at large sizes in book pose. Each page is still about as wide as the closed page (323.5 pt against 334 pt, *measured*).

*Measured* at AX5 (`-textStep 8` from Large), with the place at character 2,400 of the first chapter: closed, 64 pages, page 34 holding characters 2,394 to 2,474; book, 66 pages, pages 33 and 34 holding 2,258 to 2,407. A page holds about 80 characters at that size, and the place stayed on screen. At Large the same chapter is 7 pages closed and 8 in book pose.

## Accessibility

- Each page is an accessibility container labelled "Page 4". The text inside is a `UITextView`, so VoiceOver reads it line by line and its rotor works.
- A three-finger swipe turns the page (`accessibilityScrollAction`). The swipe gesture and the toolbar buttons do the same.
- The book tiles read as a button: title, author, then "New" or "44 percent read". The Continue Reading card reads as one button with a hint.
- Pages are selectable, so Copy, Look Up and Share work. `duo-reading` adds an Add to Notes action to the same `UITextView`.
- Right to left: SwiftUI mirrors the reader's frame and, by default, the reserved regions, so the first page should land on the right (*unverified*: we did not run a right-to-left check). A swipe to the left always turns forward.

## What we measured

On the iPhone Duo simulator, Xcode 27.1, iOS 27.1, 20 October 2026, Large text, the place at character 2,400 of "The Last Supply Boat" (about 4,700 characters). A scratch build logged the reader's size, the fold frame and the pages on screen each time they changed; the screenshots match the logs.

| Pose | Reader | Fold frame in the reader | Mode | Page size | Pages | On screen |
|---|---|---|---|---|---|---|
| Closed | 382 × 562 pt | none | single | 334 × 486 pt | 7 | page 4 (characters 2,021 to 2,665) |
| Open, flat, held wide | 867 × 553 pt | x 455.5, y −82, 40 × 669, inactive | spread | 323.5 × 477 pt | 8 | pages 3 and 4 (1,261 to 2,546) |
| Book | 867 × 553 pt | the same frame, active | spread | 323.5 × 477 pt | 8 | pages 3 and 4, not paginated again |
| Tabletop | 669 × 835 pt | x 0, y 373.5, 669 × 40, active | tabletop | 600 × 297.5 pt | 7 | page 4 (2,155 to 2,929) |

- One app process went closed, open and book, and another went tabletop then closed; the offset stayed 2,400 throughout and was on screen each time. Other apps sharing the simulator sent ours to the background mid-run, so we did not get one process through all four poses in a row.
- Held wide, the fold's frame is the window's full height: it starts 82 pt above the reader, which sits below the navigation bar.
- The fold's frame started at x 455.5, 22 pt right of the reader's middle (433.5 pt). A spread split at `width / 2` would put the end of the leading page's lines in the fold.
- Rotating into tabletop sent intermediate sizes, such as an 867 × 495 pt reader with a side-to-side fold: the 200 ms wait before paginating skips them.
- The shelf: four columns in book pose at x 62, 245, 495 and 679 (two each side of the fold) and four in a row in tabletop, where the fold runs across the shelf. The shelf scrolls, and Apple says scrolling content may cross the fold ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=597)).

Not measured: a real iPhone Duo, the open phone held tall and flat, Split View, right to left, VoiceOver's spoken output.
