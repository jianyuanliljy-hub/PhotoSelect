# PhotoSelect — macOS MVP v2

PhotoSelect is the working code name for a native macOS photo-culling utility. This v2 is a deliberate reset around one job: **open a shoot and make fast, safe decisions while the photograph stays visually dominant**.

## What the app does now

1. Open a folder with `⌘O`.
2. PhotoSelect indexes supported images in place and resumes saved decisions.
3. A newly opened shoot starts in **Unreviewed**, so the first pass behaves like an inbox.
4. Browse with `← / →` and decide with `1 / 2 / 3 / 4`.
5. Auto Advance is on by default.
6. Press `F` for Focus Mode. The sidebar and filmstrip disappear so the image gets the maximum useful area.
7. Revisit Hero, Select, Keep, or Rejected from the sidebar.
8. Reject remains PhotoSelect metadata until the user explicitly confirms **Move to Trash** from the Rejected view.
9. Pinch anywhere on the preview to zoom around that point, then pan with two fingers. Use Fit to return to the full frame.
10. Reopen one of the eight most recent shoots from the sidebar or **File > Open Recent**.

There is no mandatory onboarding. The empty state explains the first action and gets out of the way.

## Keyboard

| Action | Shortcut |
|---|---|
| Previous / next | `←` / `→` |
| First / last visible photo | `⌘←` / `⌘→` |
| Clear decision | `0` |
| Reject | `1` |
| Keep | `2` |
| Select | `3` |
| Hero | `4` |
| Focus Mode | `F` |
| Undo | `⌘Z` |
| Open folder | `⌘O` |
| Toggle filmstrip | `⌥⌘F` |
| Zoom in / out | `⌘+` / `⌘−` |
| Fit photo to preview | `⌘0` |

## Product changes from the previous iteration

The previous prototype had started to behave like a broader photo-management app. v2 removes that pressure from the default workspace:

- no first-launch walkthrough blocking the user;
- no permanent EXIF/map inspector in the main layout;
- no export controls in the core culling UI;
- no configurable Liquid Glass appearance system;
- filmstrip hidden by default for new installs;
- Unreviewed is the default working filter;
- Focus Mode is a first-class culling action;
- the decision HUD lives on the photo canvas instead of competing for toolbar space.

Some deferred implementation helpers remain in the repository because they are already tested and may be reused later. They are intentionally not exposed in the MVP interface.

## Performance changes

The preview pipeline now has explicit cache tiers:

- filmstrip: `320 px` request tier;
- main preview + neighbor prefetch: one shared `3200 px` request tier.
- zoomed inspection: `7680 px` request tier, loaded only after leaving Fit.

The shared preview tier is important. The old code could prefetch one size and then request a different size when the next image became current, causing an avoidable second decode/cache miss.

Prefetch now follows the **active filtered sequence**, because the next photo in Select/Hero/Rejected can be far away from the current file in the full shoot. Requests are ordered next-first and performed sequentially to avoid starting many RAW decodes at once and competing with the foreground image.

Decision counts are maintained incrementally instead of rescanning the entire library for every sidebar count during a keystroke.

## Safety

Hero, Select, Keep, Reject, and Unreviewed are saved PhotoSelect decisions. They do not move the original.

Rejected originals only move after an explicit confirmation showing the exact count. The app uses the normal macOS Trash path and keeps per-file failures in the current library state.

Saved decisions live under the user's Application Support directory. The last opened folder and up to eight recent folders are restored using security-scoped bookmarks.

## Build

Open the checked-in project:

```bash
open PhotoSelect.xcodeproj
```

Then select the **PhotoSelect** scheme and **My Mac**.

Command-line build/tests on a Mac with Xcode:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PhotoSelect.xcodeproj -scheme PhotoSelect \
  -destination 'platform=macOS' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PhotoSelect.xcodeproj -scheme PhotoSelect \
  -destination 'platform=macOS' test
```

The project targets macOS 14+. `project.yml` remains available for XcodeGen users, but XcodeGen is not required because the `.xcodeproj` is checked in.

### Verification on 2026-10-22

The current source built successfully with Xcode and the macOS 26.5 SDK using `CODE_SIGNING_ALLOWED=NO`. This verifies local compilation, not distribution signing or notarization.

The test target compiled, but XCTest could not start because the execution sandbox blocked communication with `com.apple.testmanagerd.control`. No passing test-suite result is claimed for this check. Run the test command above in an unrestricted local Xcode environment to validate the suite.

Local smoke-test screenshots are excluded from Git because they contain personal photographs.

## Current tests

The XCTest target covers:

- decision journal persistence and reload;
- stable photo identity;
- Unreviewed auto-advance behavior;
- the case where Auto Advance is off but a decision removes the current frame from the active filter;
- incremental decision counts and undo restoration;
- first/last navigation;
- JPEG display-size downsampling and cache reuse;
- separate preview/inspection cache tiers and the 1×–8× zoom range;
- recent-folder bookmark ordering, deduplication, limit, and stale-folder cleanup;
- metadata extraction;
- deferred non-destructive copy/export helpers.

## Deliberately deferred

- compare mode and synchronized inspection;
- burst/scene grouping;
- categories;
- XMP interoperability;
- exposed export workflow;
- full EXIF inspector;
- AI ranking / focus / blink analysis;
- two-stage embedded RAW preview + higher-quality RAW render.

Do not add these merely to make the app appear feature-rich. The next milestone is a culling loop that is visibly fast and pleasant on a real shoot.
