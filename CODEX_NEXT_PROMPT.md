# Codex task — harden PhotoSelect MVP v2

Work directly in the current repository. This is a **focused integration and hardening pass**, not another feature-expansion pass.

Before changing code, read:

- `AGENTS.md`
- `README.md`
- `PRODUCT_SPEC.md`
- `V2_AUDIT.md`
- the current Swift source and tests

`V2_AUDIT.md` is especially important: the repository has already been deliberately simplified after the previous iteration drifted into onboarding, appearance controls, export UI, a large metadata/map inspector and other secondary work. Do not reintroduce that scope during this task.

## Goal

Finish the current v2 foundation into a reliable, runnable macOS culling MVP on this Mac.

The product test is simple: open a real shoot, look mostly at the photograph, use arrows plus `1/2/3/4`, and move through the shoot without visible interaction friction or unsafe file operations.

Do the work in the repository. Do not stop at a proposal.

## 1. Establish the real baseline first

Use the checked-in `PhotoSelect.xcodeproj` unless it is genuinely broken.

Run a clean build and the test suite with the installed Xcode/macOS SDK. Capture the exact commands and errors. Fix actual compile/test failures before changing product behavior.

Do not regenerate the project with XcodeGen merely because `project.yml` exists. Regenerate only if the checked-in project is inconsistent and explain why.

Expected commands are roughly:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PhotoSelect.xcodeproj -scheme PhotoSelect \
  -destination 'platform=macOS' clean build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PhotoSelect.xcodeproj -scheme PhotoSelect \
  -destination 'platform=macOS' test
```

If signing blocks command-line execution, separate signing configuration from source-code failures and use an appropriate local build/test configuration rather than weakening sandbox/file-safety behavior.

## 2. Preserve the v2 product shape

The current UI direction is intentional:

- open into `Unreviewed`;
- black photo canvas;
- quiet sidebar;
- filmstrip hidden by default for new installs;
- filename/progress overlay on the image;
- compact `Reject / Keep / Select / Hero` HUD on the image;
- `F` toggles Focus Mode, hiding sidebar + filmstrip;
- minimal native toolbar;
- no mandatory onboarding.

Polish obvious native macOS layout/focus problems if they appear during real execution, but do not redesign the app into a dashboard and do not add secondary panels to make it look “more complete”.

### Do not add or expose in this pass

- Help Center / first-launch tutorial
- large EXIF inspector or map
- export UI
- Liquid Glass intensity/settings system
- compare mode
- categories
- XMP
- AI culling
- editing controls

The repository may retain deferred helper code and tests. Leave it dormant unless a build failure requires a small repair.

## 3. Verify the core state machine, not just the happy path

Exercise and, when useful, add targeted tests for these behaviors:

### Opening

- `⌘O` opens a folder.
- Supported photos begin appearing before a large folder finishes indexing.
- Restored decisions are respected.
- The default filter is Unreviewed.

### Navigation

- `← / →` move in the active filtered sequence.
- `⌘← / ⌘→` go to first/last visible photo.
- rapid repeated arrow presses do not break selection state.

### Decisions

- `0` clears to Unreviewed.
- `1` Reject.
- `2` Keep.
- `3` Select.
- `4` Hero.
- Auto Advance ON gives one-keystroke-per-frame behavior.
- Undo restores both the decision and the correct current frame.

Pay special attention to the regression documented in `V2_AUDIT.md`: when Auto Advance is OFF and the current decision removes the image from the active filter, the app must still land on a valid nearest visible image. Never leave `currentID` pointing at an invisible frame.

### Completion

When Unreviewed reaches zero, the first-pass-complete state should appear cleanly and routes to Selects / All Photos should work.

### Focus Mode

`F` must reliably hide/show the sidebar and filmstrip without losing current selection or keyboard control. Window resize and normal macOS full-screen should remain sane.

## 4. Validate the image pipeline with the actual navigation model

Do not replace the pipeline just for architectural novelty. Verify the concrete fixes already made in v2.

### Required invariants

1. Main preview and neighbor prefetch use the same `ImagePipeline.previewMaxPixel` cache tier.
2. Prefetch follows `visibleAssets` / the active filter, not neighboring files in the full unfiltered shoot.
3. Likely next frames are requested before previous frames.
4. Speculative prefetch does not fan out into many simultaneous RAW decodes.
5. Image decoding does not run synchronously on the main thread.
6. Filmstrip thumbnails use their smaller tier and do not force full preview decodes.

If you add temporary logging/signposts to verify cache hits or decode behavior, remove noisy diagnostics before finishing unless they are intentionally useful in DEBUG builds.

Do not optimize from theory alone. If the current code already behaves correctly, keep it.

## 5. Smoke-test with a realistic local shoot

If a suitable photo folder is available locally, use it. Otherwise create a disposable test folder outside the repository with enough JPEGs to exercise indexing, navigation and filters. A few files are not enough to expose interaction problems; aim for hundreds if generation is cheap.

Test at least:

- open folder;
- first image appearing during indexing;
- 30+ rapid next/previous operations;
- 20+ consecutive decision keystrokes;
- Auto Advance on and off;
- Undo several decisions;
- All / Unreviewed / Keep / Select / Hero / Rejected filters;
- Focus Mode;
- filmstrip toggle;
- relaunch and decision persistence.

For Trash behavior, use disposable test files only. Verify that the confirmation contains the exact reject count, successful files disappear from the library, failed files would remain represented, and files go through normal macOS Trash rather than permanent deletion.

## 6. Do a visual sanity check on the running app

Capture screenshots of at least:

- normal culling mode with a real photo loaded;
- Focus Mode with a real photo loaded;
- first-pass-complete state or Rejected review state.

Check these visually:

- photograph is clearly the dominant object;
- HUD does not obscure important image area excessively;
- sidebar width is restrained;
- toolbar does not look like a browser or a settings panel;
- text does not truncate badly at the minimum supported window size;
- dark canvas is visually continuous around the photo;
- Focus Mode materially increases useful preview area.

Fix clear layout problems you can demonstrate. Avoid decorative redesign.

## 7. Keep the code understandable

Prefer small corrections over a new architecture. In particular:

- do not introduce third-party dependencies;
- do not create a new state-management framework;
- do not replace native file APIs with custom wrappers without a concrete need;
- do not make broad naming/branding changes; `PhotoSelect` remains the working code name for now.

Update tests when you fix a real regression. Update `README.md` only if build steps, shortcuts, behavior or known limitations actually change.

## Definition of done

Do not claim completion until all feasible items below are true on this Mac:

- project builds with the installed Xcode/macOS SDK;
- XCTest target passes, or any environment-only blocker is isolated and documented precisely;
- app launches;
- a real/disposable photo folder can be opened;
- keyboard-first culling works across filters;
- Focus Mode works;
- decisions persist across relaunch;
- reject remains non-destructive until explicit Trash confirmation;
- warm sequential browsing demonstrates the intended prefetch/cache path;
- no secondary feature creep has been reintroduced.

## Final response

Give me a compact engineering report containing:

1. exact build/test commands run and their result;
2. bugs you actually found;
3. files changed and why;
4. manual smoke tests performed;
5. screenshot paths;
6. remaining known issues, separated into **blocking** and **later**;
7. one recommendation for the next development pass.

Do not end with a generic list of feature ideas. The next step should follow from what you observed while running this version.
