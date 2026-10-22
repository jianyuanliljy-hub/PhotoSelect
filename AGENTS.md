# PhotoSelect

PhotoSelect is an early-stage native macOS photo-culling application.

## Long-lived principles

- Prefer native Swift / SwiftUI and normal macOS interaction patterns.
- Keep the photograph visually dominant.
- Treat browsing latency and keyboard responsiveness as product quality.
- Preserve user originals; destructive file operations require explicit intent.
- Avoid unnecessary dependencies and architecture.

## Working in this repository

Read `README.md`, `PRODUCT_SPEC.md`, and `V2_AUDIT.md` before substantial changes.

The product specification is current direction, not an immutable contract. Better ideas are welcome, but verify the existing behavior before replacing it and keep unrelated changes small.

Prefer a working, tested interaction over adding another feature.
