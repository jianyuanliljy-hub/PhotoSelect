# Development

**English** · [简体中文](DEVELOPMENT.zh-CN.md)

PhotoSelect uses Swift / SwiftUI and AppKit, targets macOS 14+, and has no third-party runtime dependencies. Read [AGENTS.md](../AGENTS.md), the [product specification](../PRODUCT_SPEC.md), and the [v2 audit](../V2_AUDIT.md) before substantial changes.

<a id="build"></a>

## Build and test

Use a full Xcode installation, the PhotoSelect scheme, and My Mac. The checked-in `.xcodeproj` is ready to use; `project.yml` is available for developers who prefer XcodeGen.

```bash
open "PhotoSelect.xcodeproj"
```

Build from the command line:

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' build
```

Run tests:

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' test
```

Append `CODE_SIGNING_ALLOWED=NO` to the build command for a local compilation check without signing. This does not verify distribution signing, notarization, or runtime permissions. Do not disable App Sandbox or broaden file access to resolve a local signing problem.

<a id="verification"></a>

## Latest verification: 2026-10-22

| Check | Result | Scope |
| :--- | :--- | :--- |
| Local build | Succeeded | Xcode / macOS 26.5 SDK, Apple Silicon, `CODE_SIGNING_ALLOWED=NO` |
| XCTest target compilation | Succeeded | Test code compiled and linked |
| XCTest execution | Blocked by the environment | The execution sandbox prevented connection to `com.apple.testmanagerd.control`; no passing-suite result was obtained |
| Real-shoot interaction check | Not performed in this pass | The complete workflow needs verification in a normal desktop session |

The commands used for this check are below. Result files were saved to the execution machine's temporary directory and are not checked in.

```bash
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "/private/tmp/PhotoSelect-status-20261022" \
  CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" \
  xcodebuild -project "PhotoSelect.xcodeproj" -scheme PhotoSelect \
  -destination 'platform=macOS' \
  -derivedDataPath "/private/tmp/PhotoSelect-status-20261022" \
  CODE_SIGNING_ALLOWED=NO test
```

The build emitted an unused local-binding warning in `AsyncPhotoView.swift`. It did not prevent compilation. A successful build does not establish interaction quality or file-safety acceptance.

## Test coverage

The XCTest target includes these scenarios. This list describes the tests, not a claim that they all passed in the latest run.

- Decision-journal persistence, reload, cleanup, and stable path-based asset identity.
- Consecutive decisions in Unreviewed, auto-advance, and valid selection when a decision leaves the active filter with Auto Advance off.
- Undo after switching filters, decision counts, first/last navigation, and rapid repeated navigation.
- Active-filter, next-first prefetch ordering.
- JPEG downsampling and cache reuse, preview/inspection tiers, and zoom bounds.
- Recent-folder deduplication, the eight-folder limit, and unavailable-folder cleanup.
- EXIF extraction and deferred non-destructive copy/export helpers.

## Image-pipeline constraints

| Request tier | Requested maximum dimension | Purpose |
| :--- | ---: | :--- |
| Filmstrip | 320 px | Filmstrip thumbnails |
| Preview | 3200 px | Current photo and neighboring prefetch, sharing a cache tier |
| Inspection | 7680 px | Detail inspection after leaving Fit |

The image cache has a target cost limit of 256 MiB and a count limit of 96. `NSCache` controls eviction; these settings are not a cap on total application memory. Actual resolution depends on the source and system decoder. RAW requests try Quick Look first, then fall back to ImageIO.

Prefetch follows `visibleAssets`, requesting the next three frames and then the previous two. Speculative requests run sequentially to avoid fanning out many RAW decodes. Directory scanning runs in the background in batches of up to 128 files.

<a id="storage"></a>

## Data storage and backup

Saved decisions use the standardized file path as their key. `DecisionPersistence` creates these files under the runtime user's Application Support directory:

```text
PhotoSelect/decisions.json
PhotoSelect/decisions.json.journal
```

With App Sandbox enabled and the current bundle identifier, this is typically:

```text
~/Library/Containers/com.example.PhotoSelect/Data/Library/Application Support/PhotoSelect/
```

An unsandboxed environment typically resolves to `~/Library/Application Support/PhotoSelect/`. The actual location follows the runtime user-domain directory. Changing the bundle identifier changes the sandbox container.

Quit the app before backing up the entire PhotoSelect data directory, including both the snapshot and journal when present. The snapshot may not exist yet, and the latest decisions may only be in the journal. The journal compacts into a snapshot after 1,000 mutations. Folder bookmarks, recent folders, and preferences are stored in UserDefaults; the undo stack is session-only.

## Suggested manual checks

Use disposable copies for file-operation tests, never the only copy of an original.

1. Open several hundred mixed-format images and confirm that the first batch appears before indexing finishes.
2. Navigate and rate repeatedly; verify selection and counts across all filters.
3. Toggle Auto Advance and inspect navigation and undo when the current frame leaves its filter.
4. Pinch, pan, return to Fit, switch photos, and resize the window.
5. Toggle Focus Mode and the filmstrip; confirm that keyboard control remains available.
6. Quit and relaunch; verify restored decisions and folder access.
7. With disposable files, verify the Trash confirmation count, successful removal, and accurate retention of failures.

Historical screenshots remain in the local `SmokeTestArtifacts/` directory. They contain personal photographs and are excluded by `.gitignore`. The README artwork is a separate vector illustration, not verification evidence.
