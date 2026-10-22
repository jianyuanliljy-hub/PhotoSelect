<div align="center">

<img src="docs/assets/mark.svg" width="80" height="80" alt="PhotoSelect logo">

# PhotoSelect

<p><strong>English</strong> · <a href="README.zh-CN.md">简体中文</a></p>

### Find your best frames.

Native macOS photo culling. Keyboard-driven decisions. Your photographs, kept local.

<p>
  <img src="https://img.shields.io/badge/macOS-14%2B-222222?style=flat-square&logo=apple&logoColor=white" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Built_with-SwiftUI-F05138?style=flat-square&logo=swift&logoColor=white" alt="Built with SwiftUI">
  <img src="https://img.shields.io/badge/Dependencies-0-287D70?style=flat-square" alt="No third-party dependencies">
  <img src="https://img.shields.io/badge/Status-MVP_v2-94733D?style=flat-square" alt="MVP v2 development stage">
</p>

<p>
  <a href="#quick-start">Quick start</a> ·
  <a href="#workflow">Workflow</a> ·
  <a href="#shortcuts">Shortcuts</a> ·
  <a href="#safety">File safety</a> ·
  <a href="docs/DEVELOPMENT.md">Development</a> ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

<img src="docs/assets/overview.svg" width="100%" alt="PhotoSelect interface illustration: sidebar filters, a large photo canvas, and four keyboard decisions">

<sub>Vector interface illustration. Actual appearance varies with macOS version and window size.</sub>

</div>

<br>

Open a shoot, browse with the arrow keys, and decide with `1 / 2 / 3 / 4`. PhotoSelect brings unreviewed frames, keepers, selects, and rejects into a focused native workspace. Originals stay in their folders; your decisions stay on your Mac.

> **Current stage:** MVP v2, available to build and try from source. The core culling workflow is implemented; performance and stability on large, real-world RAW shoots still need validation. See the [development guide](docs/DEVELOPMENT.md#verification) for build results, test status, and limitations.

## One photograph. One decision.

| Capability | What you can do today |
| :--- | :--- |
| **Open in place** | Browse a folder as it is indexed in batches. Supports JPEG, HEIC, PNG, TIFF, and RAW formats your system can decode. |
| **Cull from the keyboard** | Make four-level decisions, auto-advance, revisit filtered picks, and undo without reaching for the mouse. |
| **Inspect with focus** | Press `F` to hide the sidebar and filmstrip. Pinch to zoom, pan with two fingers, and return to Fit. |
| **Pick up where you left off** | Restore decisions, preferences, and the last folder. Reopen up to eight recent shoots. |
| **Prefetch the sequence you see** | Prepare neighboring frames in the active filter, next-first, using the same cache tier as the main preview. |
| **Review before removal** | Reject records a decision. Originals move to the macOS Trash only after you confirm the exact count in Rejected. |

<a id="quick-start"></a>

## Quick start

You need **macOS 14 or later** and a full **Xcode** installation that supports your target system. The app currently builds from source; a signed, notarized installer is not yet available.

```bash
git clone https://github.com/jianyuanliljy-hub/PhotoSelect.git
cd "PhotoSelect"
open "PhotoSelect.xcodeproj"
```

In Xcode, select **PhotoSelect → My Mac** and Run (`⌘R`). If signing setup is requested, choose your Development Team under **Signing & Capabilities**.

The `.xcodeproj` is checked in. XcodeGen is optional.

<a id="workflow"></a>

## From a full shoot to your strongest frames

1. **Open a shoot.** Press `⌘O`. Photos appear in batches, saved decisions are restored, and the default view is Unreviewed.
2. **Make your first pass.** Browse with `← / →` and rate with `1 / 2 / 3 / 4`. Auto Advance is on by default.
3. **Inspect the details.** Pinch to zoom, pan with two fingers, and press `⌘0` to fit the image. Press `F` for more canvas space.
4. **Revisit your picks.** Review Hero, Select, and Keep separately. Use `⌘Z` to undo or `0` to clear a decision.
5. **Review your rejects last.** Open Rejected, inspect the set, then choose Move to Trash and confirm the file count if you want to remove them.

When Unreviewed reaches zero, a first-pass-complete state links to Select and All Photos. Decisions remain PhotoSelect-local; export and XMP writing are not exposed in the current interface.

<a id="shortcuts"></a>

## Keep your hands on the keyboard

| Key | Decision | Meaning |
| :---: | :--- | :--- |
| `1` | Reject | Mark for review; the original stays in place |
| `2` | Keep | A usable frame worth retaining |
| `3` | Select | A strong frame worth editing |
| `4` | Hero | A standout from the shoot |
| `0` | Unreviewed | Clear the current decision |

<details>
<summary><strong>All keyboard shortcuts</strong></summary>

| Action | Shortcut |
| :--- | :--- |
| Previous / next photo | `←` / `→` |
| First / last photo in the active filter | `⌘←` / `⌘→` |
| Undo the last decision | `⌘Z` |
| Open a folder | `⌘O` |
| Toggle Focus Mode | `F` |
| Show / hide the filmstrip | `⌥⌘F` |
| Zoom in / out | `⌘+` / `⌘−` |
| Fit to window | `⌘0` |

</details>

<a id="safety"></a>

## Your originals stay yours

**Decisions do not move originals.** Hero, Select, Keep, and Reject are local records. Only the confirmed Rejected → Move to Trash action moves files, using the standard macOS Trash API. Files that fail to move remain represented in the library.

**Decisions are stored locally.** A JSON snapshot and append-only journal save your choices. See [data storage](docs/DEVELOPMENT.md#storage) for sandbox locations and backup guidance. Folder access uses macOS security-scoped bookmarks.

**File paths are the current identity.** Moving or renaming originals outside the app breaks their association with saved decisions. Undo history lasts for the current session and does not survive relaunch. Maintain an independent backup of important photographs.

## Development status

| Status | Scope |
| :--- | :--- |
| **Implemented** | Single-photo culling, four-level decisions, filtered navigation, undo, zoom and pan, Focus Mode, decision persistence, recent folders, and confirmed Trash operations |
| **Needs validation** | Browsing latency on large mixed JPEG / RAW shoots, long-session stability, and camera-specific RAW compatibility |
| **Next priority** | Validate the core loop on real shoots before building Compare Mode |
| **Not yet exposed or implemented** | Synchronized comparison, burst grouping, XMP, AI culling, export UI, a full EXIF inspector, and two-stage high-quality RAW rendering |

RAW compatibility depends on the installed macOS ImageIO / Quick Look codecs. Zoom is relative to Fit, currently 1×–8×; it is not a sensor-pixel 100% inspection mode. Folder scanning includes subfolders, with no capture-time sorting or option to exclude subfolders yet.

## For developers

PhotoSelect uses **SwiftUI + AppKit**, with no third-party dependencies. Views, culling state, image decoding, and persistence have distinct responsibilities.

```text
PhotoSelect/
├── Models/             Photo identity, decisions, and metadata
├── Stores/             Culling state, navigation, undo, and file operations
├── Services/           Image cache, decision persistence, bookmarks, and metadata
└── Views/              SwiftUI views and the AppKit zoom surface
PhotoSelectTests/       XCTest coverage
docs/                   Development notes and project artwork
```

The image pipeline requests `320 px` filmstrip thumbnails, `3200 px` previews, and `7680 px` inspection images. Actual output depends on the source and decoder. Prefetch follows the active filter, next-first, to reduce competition between speculative decoding and foreground browsing.

[Build and test](docs/DEVELOPMENT.md#build) · [Verification record](docs/DEVELOPMENT.md#verification) · [Product specification](PRODUCT_SPEC.md) · [Why v2 changed](V2_AUDIT.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

<details>
<summary><strong>Frequently asked questions</strong></summary>

**Can I download an installer?**

Build from source for now. A signed, notarized installer is not yet available.

**Does it run on Windows or Linux?**

The current app targets macOS and uses SwiftUI, AppKit, and system image codecs.

**Can I export my selected photographs?**

Copy/export helpers and tests remain in the repository, but the current MVP does not expose an export workflow.

**Why is there no passing-tests badge?**

The local build succeeded on 2026-10-22 and the test target compiled. The execution sandbox prevented the test runner from starting, so no full passing-suite result is claimed. See the [verification record](docs/DEVELOPMENT.md#verification).

**What is the license?**

A license has not been selected yet. Licensing terms will be documented separately.

</details>

---

<div align="center">
<sub>PhotoSelect · Built for the space between shooting and editing.</sub>
</div>
