# PhotoSelect v2 Audit

This note explains why the current repository was reset before the next Codex pass.

## What had gone wrong

The previous implementation successfully accumulated features, but the product priority became blurred. The repository grew to more than 3,000 lines of Swift while adding first-launch onboarding, a help center, configurable Liquid Glass, a large EXIF/map inspector, export controls and multiple toolbar surfaces.

Those additions were not the highest-risk part of the product. PhotoSelect succeeds or fails on the speed and clarity of the one-photo culling loop.

## Concrete technical issues found

### 1. Preview and prefetch cache requests were not guaranteed to use the same tier

The visible preview derived `maxPixel` from the current window size, while prefetch used a fixed value. After quantization some window sizes matched and others produced a different cache key. A prefetched next photo could therefore require another decode when it became current.

**v2:** main preview and neighbor prefetch use the same declared `ImagePipeline.previewMaxPixel` tier.

### 2. Prefetch followed the full library instead of the active filter

Navigation happens through `visibleAssets`, but prefetch previously used neighbors in the unfiltered `assets` array. During a second pass through Select/Hero/Rejected, the actual next visible image could be hundreds of files away and remain cold.

**v2:** prefetch uses the active filtered sequence.

### 3. Speculative image work was too concurrent

The old prefetch path launched a task-group request for every neighbor at once. Multiple RAW decodes can compete with the foreground image for CPU, disk and memory.

**v2:** next-first prefetch is sequential and bounded. At cancellation time there can be at most one speculative decode already in flight.

### 4. Auto Advance OFF could leave stale selection state

When the active view was Unreviewed/Keep/Select/etc., changing the current photo to a decision outside that filter removed it from `visibleAssets`. With Auto Advance off, the old code returned early and left `currentID` pointing at an invisible asset.

**v2:** leaving the active filter always selects the nearest remaining visible frame. Auto Advance only controls the extra step when the current frame remains visible.

A regression test covers this case.

### 5. Sidebar counts repeatedly rescanned the entire library

Every count call filtered the whole asset array. SwiftUI can request these values many times around a single state change.

**v2:** decision counts are maintained incrementally on index, decision, undo and Trash commit.

### 6. The default workflow did not express completion

Opening into All Photos works mechanically but gives no natural “done with first pass” state.

**v2:** open into Unreviewed. Reaching zero produces a dedicated first-pass-complete state.

## Product reset

The default UI now prioritizes:

1. the current image;
2. one-keystroke decisions;
3. navigation;
4. lightweight progress;
5. safe reject review.

Filmstrip is optional. `F` enters Focus Mode and removes sidebar + filmstrip from the culling surface.

Inspector, map, export, appearance tuning and onboarding are deferred from the active UI. Their existence should not drive the next development pass.
