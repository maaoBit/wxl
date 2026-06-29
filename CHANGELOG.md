# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial open source release

## [1.3.3] - 2026-06-29

### Added
- **Automatic update detection and installation**: The app now checks for new versions on GitHub Releases on launch (configurable in Settings → 通用 → 启动时自动检查更新, enabled by default) and via a manual "检查更新" button in Settings → 关于. When a newer version is found, the menu bar icon shows a badge and the About page offers a one-click "下载并安装" flow that downloads the architecture-matched DMG (arm64/x86_64), mounts it, replaces the running `.app` in place, clears quarantine attributes (to avoid Gatekeeper blocking the ad-hoc signed build), and relaunches the app. Version comparison is based on `CFBundleShortVersionString` (the installed version) rather than the compile-time constant.

### Fixed
- **AppConstants version desync**: The About page reads a hardcoded `AppConstants.version`; it now displays the actual installed version from `Info.plist` so the version string stays in sync with releases.

## [1.3.2] - 2026-06-29

### Fixed
- **Image preview broken in detail panel**: When selecting an image in the history list, the right-hand detail panel displayed the literal text "[Image]" instead of the image itself. The clipboard list is loaded without `imageData` (via `loadAllLight()`) for performance, so `selectedItem.imageData` was `nil` and the detail view fell back to the placeholder text. The detail preview now loads the image data on demand from the database (same pattern already used by `copyToClipboard`).

## [1.3.1] - 2026-06-14

### Fixed
- **Image paste from history broken**: Pasting images loaded from the database (after app restart or dedup refresh) inserted the literal text "[Image]" instead of the actual image. Clipboard list items are loaded without `imageData` for performance; the paste paths now load image data on demand when it is missing.
- **FTS5 search failures on special characters**: Searching for queries containing FTS5 special characters (`:`, `(`, `-`, `*`, etc.) threw syntax errors and silently returned empty results. Query terms are now properly double-quote escaped, and `searchLight` falls back to LIKE search when the FTS5 query fails.
- **Content type misclassified as code**: Everyday English such as "let me know", "first class", and "import data" was incorrectly detected as code. Detection now uses a two-tier heuristic: strong indicators (`func`/`def`/`var`/`#include`) alone trigger code; weaker indicators (`let`/`import`/`class`/braces) require two or more.
- **Paste blocked main thread**: `pasteSelected` reloaded the entire history (including image BLOBs) on the main thread just to reorder. It now reorders in memory, consistent with the keyboard paste path.

## [1.3.0] - 2026-06-09

### Performance
- **FTS5 Full-Text Search**: Added SQLite FTS5 index for content and OCR text, replacing slow LIKE queries
- **Lightweight Data Loading**: New `loadAllLight()` and `searchLight()` methods that skip imageData BLOBs
- **Incremental Updates**: Clipboard operations (paste, delete, pin) now update arrays directly instead of full database reloads
- **Pagination**: Panel loads 50 items initially with infinite scroll, search results capped at 200
- **Debounce Optimization**: Increased search debounce from 200ms to 300ms

### Fixed
- Search freezing when clipboard history has many items
- Main thread blocking when updating duplicate clipboard items
- FTS5 query parameter binding issues

## [1.0.0] - 2024-02-23

### Added
- **Core Features**
  - Clipboard history tracking with automatic content detection
  - Support for text and image clipboard content
  - Persistent storage using SQLite database
  - Content deduplication using SHA-256 hashing

- **Smart Content Detection**
  - URL detection (http, https, ftp)
  - Email address detection
  - Phone number detection (international formats)
  - File path detection (Unix and macOS style)
  - Code detection (Swift, Python, C, JavaScript indicators)

- **Smart Actions**
  - Open URLs in default browser
  - Reveal files in Finder
  - Compose emails with detected email addresses
  - Initiate FaceTime calls with detected phone numbers

- **User Interface**
  - Liquid Glass UI with modern blur effects
  - Panel appears near mouse cursor
  - Menu bar status item for quick access
  - Dark mode support
  - Real-time search filtering

- **Keyboard Shortcuts**
  - Global hotkey (⌘⇧C) to toggle panel (customizable)
  - Arrow keys for navigation
  - Enter to paste selected item
  - ⌘+Enter for smart actions
  - ⌘+P to pin/unpin items
  - ⌘+D to delete items
  - ESC to close panel

- **Settings**
  - Configurable history expiry time (6h - 7 days)
  - Configurable maximum history count (100 - 2000)
  - Launch at login option
  - Customizable global keyboard shortcut

- **Data Management**
  - Pin important items to prevent auto-cleanup
  - Auto-cleanup of expired items
  - History count limiting
  - Source application tracking

- **Developer Features**
  - Comprehensive unit test suite (132 tests)
  - Swift Package Manager support
  - Clean architecture with MVVM pattern

### Technical Details
- Built with SwiftUI and macOS 14+ SDK
- SQLite database for persistent storage
- CryptoKit for content hashing
- KeyboardShortcuts library for global hotkeys

---

## Version History Summary

| Version | Date | Description |
|---------|------|-------------|
| 1.3.3 | 2026-06-29 | Auto-update: version detection and one-click install |
| 1.3.2 | 2026-06-29 | Bug fix: image preview in detail panel |
| 1.3.0 | 2026-06-09 | Performance optimization: FTS5 search, lightweight loading, pagination |
| 1.0.0 | 2024-02-23 | Initial release with core features |
