# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial open source release

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
| 1.3.0 | 2026-06-09 | Performance optimization: FTS5 search, lightweight loading, pagination |
| 1.0.0 | 2024-02-23 | Initial release with core features |
