# Security

**English** · [简体中文](SECURITY.zh-CN.md)

PhotoSelect reads user-selected photo folders and can move rejected originals to the macOS Trash after explicit confirmation. Unexpected file movement, permanent deletion, access outside the authorized scope, and unintended disclosure of photographs or location data are priority concerns.

## Reporting

Do not upload private photographs, GPS coordinates, bookmark data, full personal paths, or signing material to public issues.

If **Security → Advisories → Report a vulnerability** is available, use that private channel. Its availability is not guaranteed, and a dedicated security email has not been established. If no private channel is available, open an issue without sensitive details to request one from the maintainer before sharing reproduction material.

Include the affected commit, macOS version, reproduction steps, observed impact, and a minimal example using synthetic files or disposable copies. Do not perform destructive tests on your only copy of a photograph.

## Maintenance scope

The current maintenance target is MVP v2 on `main`. There are no separately maintained stable versions or committed response-time guarantees. File safety and data integrity take priority over new features.
