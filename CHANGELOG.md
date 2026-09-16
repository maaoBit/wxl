# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-09-16

### Added
- **Image thumbnails in the list**: image items now show a real thumbnail in the compact list (128 px PNG, downsampled via ImageIO at capture time) instead of a generic photo icon. Existing image items are backfilled once in the background on first launch after upgrade (database schema v3 migration).
- **Auto-paste option**: a new Settings → 通用 → 粘贴 toggle ("选中后自动粘贴到当前应用") pastes the selected item into the previously frontmost app by simulating ⌘V after the panel hides. Requires the Accessibility permission; without it the behavior silently degrades to copy-only, and the settings page offers a shortcut to grant the permission.
- **Per-app capture exclusion (privacy)**: apps added to the new Settings → 通用 → 隐私 exclusion list (e.g. password managers) no longer enter clipboard history.
- **Type filter chips**: the panel now has 全部 / 文本 / 链接 / 文件 / 图片 filter chips that stack on top of search. Text-like items (code, email, phone) are grouped under 文本 so they never disappear when filtering.
- **Clear all history**: Settings → 通用 → 数据 gains a destructive "清空全部历史" action (with confirmation dialog, includes pinned items, clears the search index too).

### Fixed
- **Settings shortcut recorder crash (issue #1)**: clicking the shortcut recorder in 设置 → 快捷键 could crash the app. KeyboardShortcuts was upgraded from a 2024-02 pin to 3.1.0, which fixes the macOS 26 (Tahoe) `RecorderCocoa` crash (upstream #231) and a Swift 6.3 release-build crash.
- **OCR text was unsearchable**: recognizing text on an image updated the main table but never the FTS5 index, so text visible only inside screenshots could never be found (FTS "success with zero hits" did not fall back to LIKE). OCR updates now sync the index.
- **Chinese substring search**: the FTS5 unicode61 tokenizer does not segment CJK text, so a substring like 验证码 inside a longer Chinese sentence matched nothing. Zero-hit FTS queries now fall back to the LIKE substring scan.
- **Clipboard changes lost right after paste**: the ignore-next-change flag (boolean) swallowed a user copy that landed within the same 0.5 s poll window after a paste. It now matches the exact expected pasteboard change count.
- **Inconsistent open actions**: the detail pane's arrow button did not add `https://` to scheme-less URLs while ⌘↵ did; three duplicated action code paths were consolidated into `IntelligentActionService`.
- **Pinned items kept their order forever**: pasting a pinned item refreshed neither its timestamp nor its position, so the pinned section never reordered. Pinned items now move to the top of the pinned section on use (mirrors normal-item behavior).
- **Unpinned pinned items never expired**: un-pinning an item left its expiry date cleared forever; the retention window is now restored on unpin.

### Changed
- **Capture pipeline off the main thread**: hashing (image SHA-256) and database writes now run on a dedicated serial queue; copying large screenshots no longer hitches the UI. Duplicate captures update the list in memory instead of a full reload.
- **Faster startup**: the FTS5 index full rebuild (previously on every launch, cost growing with history size) now runs once via a `PRAGMA user_version` migration marker.
- **Panel opens faster**: the panel's hosting view is created once (PanelView observes the shared app state) instead of being rebuilt on every show.
- **Detail image loads asynchronously**: selecting an image item reads its data from the database off-main instead of synchronously inside the view body; file icons are cached.
- **Max history count applies immediately**: changing 最大历史条数 in settings now trims history right away instead of waiting for the next capture.
- **Search selection resets**: changing the search text or type filter moves the selection back to the top item.
- **Context menu on list rows**: the compact list rows gained a right-click menu (粘贴 / 复制内容 / 置顶 / 打开 / 删除).
- **Dead code removed**: ~650 lines (unused `ClipboardItemRow`, `OCRService`+`OCRCache`, legacy search, misc views/flags); tests migrated accordingly (190 total).

## [1.4.0] - 2026-08-17

### Added
- Initial open source release

### Fixed
- **File items show full paths in detail panel**: Copying a file/folder in Finder displayed only the filename (or "N 个文件") in the right-hand detail panel. The detail view now renders the complete absolute paths from `fileURLs` (one per line, selectable); the left list stays compact with filenames. The footer stat shows file count instead of character count for file items.

### Removed
- **MCP server**: The built-in HTTP MCP server (port 9527), its settings tab, and related documentation were removed. Manual copy/paste (which is already auto-captured into history) covers the human↔AI content transfer use case; the one-way read-only MCP integration saw no real-world use and added maintenance burden.

### Changed
- **Testability refactor (behavior-equivalent)**: Clipboard capture logic extracted from `ClipboardMonitor` into `ClipboardItemFactory` (behind a `PasteboardReading` protocol), and paste-back logic extracted from `PanelView` into `ClipboardWriter` (behind a `PasteboardWriting` protocol); detail-panel display decisions moved into `ClipboardItem.detailLines` / `footerStatText`. No behavior changes. Added 36 tests covering fileURLs persistence round-trips (save/loadAllLight/searchLight, dedup update), detail display fallbacks, capture priority rules (file > image > text, existence filtering, text-vs-fileURL), and paste-back branches (36 new tests, 176 total).

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
