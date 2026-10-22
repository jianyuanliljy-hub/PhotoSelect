# PhotoSelect Product / UX Specification — v2 Reset

> **Status:** working specification. PhotoSelect is still a working code name. This document defines the current product direction for the culling MVP, not a permanent feature contract.

## 1. Product sentence

**A native Mac culling desk: open a shoot, put the photograph first, make one decision per keystroke, and safely reduce a large shoot to the frames worth editing.**

The reference feeling is a focused Apple pro utility: visually quiet, immediate, keyboard-friendly, and comfortable to leave open for hours.

## 2. The only workflow that must be excellent now

Open folder → Unreviewed → inspect photo → press one key → next photo → finish first pass → review strong frames → review rejects → optionally commit rejects to macOS Trash.

If a feature does not materially improve this path, it belongs in a later phase.

## 3. Decision model

| State | Meaning | Key |
|---|---|---:|
| Unreviewed | no decision yet | `0` clears back to this state |
| Reject | clear miss / duplicate / unusable frame | `1` |
| Keep | usable frame worth retaining | `2` |
| Select | strong frame likely worth editing | `3` |
| Hero | standout frame | `4` |

One image has exactly one culling decision. Categories, stars, colors and XMP mappings are separate later concerns.

## 4. Navigation model

- `← / →`: previous / next photo in the **active filter**.
- `⌘← / ⌘→`: first / last photo in the active filter.
- Auto Advance defaults ON.
- `F`: Focus Mode.
- `⌘Z`: undo last decision.

A first-pass user should be able to work almost entirely with arrows plus `1 2 3 4`.

## 5. Default workspace

### Normal mode

- quiet native sidebar on the left;
- large black preview canvas;
- standard macOS titlebar/toolbar;
- filmstrip optional and hidden by default for new installs;
- small filename/position overlay at top-left of the canvas;
- current decision badge at top-right;
- compact decision HUD at bottom-center.

### Focus Mode

Focus Mode temporarily hides the sidebar and filmstrip. It exists for one reason: maximize useful image area during the first pass.

Focus Mode is session state, not a permanent preference.

## 6. Sidebar

Only culling views:

- All Photos
- Unreviewed
- Hero
- Select
- Keep
- Rejected

The bottom of the sidebar may show the active folder and an Open/Change Folder button. Avoid instructions, export panels, metadata panels, albums or DAM controls here.

## 7. Toolbar

Keep it small:

- previous / next;
- current filter + progress;
- Auto Advance;
- filmstrip toggle;
- Focus Mode;
- Move to Trash only while reviewing Rejected.

Decision buttons belong on the photo canvas, where the relationship between judgement and frame is visually obvious.

## 8. Visual language

- photo supplies the color;
- canvas is black;
- surrounding UI follows macOS appearance;
- native semantic colors and SF Symbols;
- restrained 8–12 pt utility radii;
- standard system materials where transparency helps legibility;
- no user-facing “glass intensity” system;
- no decorative transitions between frames;
- no large cards, gradients or dashboard layouts.

The image should remain the first thing the eye sees at every normal window size.

## 9. First-launch behavior

Do not force a tutorial before the user can work.

With no folder open, show one clear empty state:

**Open a shoot** → Open Folder…

Keyboard discoverability can live in button labels, tooltips, menus and Settings.

## 10. First-pass behavior

A newly opened shoot starts in **Unreviewed**. This provides a useful completion condition: each rated frame leaves the current view, and eventually Unreviewed reaches zero.

When zero is reached, show a quiet completion state with direct routes to Selects and All Photos.

If Auto Advance is off and a decision removes the current frame from the active filter, PhotoSelect must still select the nearest remaining frame. The UI must never retain a stale selection that is no longer visible.

## 11. Performance invariants

These are more important than adding features.

### Stable preview tier

The visible preview and neighbor prefetch must request the same cache tier. Current MVP tier: approximately `3200 px` maximum dimension.

### Filter-aware prefetch

Prefetch the next frames in the sequence the user will actually navigate. In a Select/Hero/Rejected view, that means the filtered sequence, not adjacent files from the entire shoot.

### Next-first and bounded speculation

Order likely next frames before previous frames. Avoid launching many RAW decodes simultaneously. Foreground navigation should win CPU, disk and memory contention.

### Main thread

Directory enumeration and image decoding must stay away from the main thread. A decision keypress should update application state immediately.

### Benchmark direction

- warm next-frame transition should usually feel instantaneous;
- no repeated full-size decode when a prefetched cache entry exists;
- first useful image should appear before a large folder finishes indexing;
- rapid arrow-key navigation must not make the UI stop accepting input.

## 12. File safety

Reject is metadata during culling.

Only the explicit Rejected → Move to Trash action touches originals. The confirmation must show the exact file count. Per-file failures remain represented accurately in application state.

No code path may permanently erase originals automatically.

## 13. What is intentionally outside the current UI

The repository may contain reusable code for some of these, but do not surface them in this milestone:

- export/copy workflow;
- full metadata inspector and map;
- onboarding/help center;
- appearance-tuning controls;
- compare mode;
- 100% synchronized zoom;
- categories;
- XMP;
- AI-assisted ranking.

This is a scope decision for the current milestone, not a declaration that these features are bad.

## 14. Next major product feature after the core is proven

**Compare Mode** remains the highest-value expansion: 2–4 related frames, large synchronized inspection, fast winner selection. Build it only after the basic one-frame culling loop survives real-world testing.

## 15. The design test

Give a photographer 1,000 mixed JPEG/RAW frames. If the first pass can be completed with very little mouse movement, almost no waiting, and almost no attention paid to the application chrome, this MVP is succeeding.
