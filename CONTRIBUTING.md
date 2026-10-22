# Contributing

**English** · [简体中文](CONTRIBUTING.zh-CN.md)

Reproducible bug reports, feedback from real shoots, and focused fixes are welcome. The current priority is a reliable single-photo loop: open, inspect, decide, advance, and review.

## Before you start

Read [AGENTS.md](AGENTS.md), the [product specification](PRODUCT_SPEC.md), the [v2 audit](V2_AUDIT.md), and the [development guide](docs/DEVELOPMENT.md). The product is still an MVP. Discuss larger features in an issue first, including the user need and tradeoffs.

## Report a problem

Include your macOS and Xcode versions, commit, image formats and count, minimal reproduction steps, expected behavior, and actual behavior. For performance reports, add the camera model, image dimensions, storage type, and whether browsing was cold or cached.

Remove faces, GPS coordinates, personal paths, and other sensitive information from screenshots and logs. Use synthetic or appropriately licensed samples when possible. For unexpected file operations or data-loss risks, read [SECURITY.md](SECURITY.md) first.

## Submit a change

- Keep each change focused on one problem. Preserve native SwiftUI / AppKit interactions and avoid dependencies or frameworks without a concrete need.
- Add targeted regression coverage for navigation, filtering, persistence, and file operations. Verify file behavior using disposable copies.
- Run the [build and tests](docs/DEVELOPMENT.md#build). Record exact environment blockers, and distinguish compilation, passing tests, and manual verification.
- Explain the problem, cause, change, validation, and remaining limitations in the PR. Include screenshots without private photographs for interface changes.
- Keep originals, personal test screenshots, signing material, local Xcode state, and build output out of commits.

A license has not been selected yet. Confirm contribution and reuse terms with the maintainer before contributing or reusing code.
