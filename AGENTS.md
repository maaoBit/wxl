# WXL Project - AI Agent Development Guide

## Project Overview

WXL is a macOS clipboard history manager built with SwiftUI, featuring Liquid Glass UI and intelligent content detection.

**Tech Stack**: Swift 5.9, SwiftUI, SQLite.swift, KeyboardShortcuts, CryptoKit  
**Platform**: macOS 14.0+ (Sonoma)  
**Architecture**: MVVM pattern with Services layer

## Build Commands

### Building
```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Build for specific platform
swift build -c release --arch arm64  # Apple Silicon
swift build -c release --arch x86_64 # Intel
```

### Testing
```bash
# Run all tests
swift test

# Run specific test case
swift test --filter WXLTests.ClipboardItemTests

# Run specific test method
swift test --filter WXLTests.ClipboardItemTests/testDetectContentType_HTTP_URL

# Run tests matching pattern
swift test --filter "URL"  # Runs all tests containing "URL"

# Skip specific tests
swift test --skip PerformanceTests

# Generate test coverage
swift test --enable-code-coverage
```

### Dependencies
```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update

# Reset package cache
swift package reset
```

## Project Structure

```
Sources/WXL/
├── Models/           # Data models (ClipboardItem, ContentType)
├── Services/         # Business logic and storage
│   ├── ClipboardStorage.swift      # SQLite persistence
│   ├── ClipboardMonitor.swift      # Clipboard monitoring + OCR
│   ├── ClipboardItemFactory.swift  # Pasteboard → ClipboardItem capture logic (testable)
│   ├── ClipboardWriter.swift       # ClipboardItem → pasteboard write-back (testable)
│   ├── IntelligentActionService.swift  # Smart actions
│   └── UpdateChecker.swift         # Version update check
├── ViewModels/       # MVVM view models
├── Views/            # SwiftUI views
│   ├── PanelView.swift             # Main UI panel
│   ├── SettingsView.swift          # Settings
│   └── LiquidGlassView.swift       # UI components
├── Utils/            # Helpers and extensions
└── AppDelegate.swift # App lifecycle

Tests/
├── ClipboardItemTests.swift            # Model tests
├── ClipboardItemCodableTests.swift     # Serialization tests
├── ClipboardItemDetailTests.swift      # Detail panel display logic tests
├── ClipboardStorageTests.swift         # Storage tests
├── ClipboardStorageFileURLsTests.swift # fileURLs persistence round-trip tests
├── ClipboardItemFactoryTests.swift     # Capture logic tests (mock pasteboard)
├── ClipboardWriterTests.swift          # Paste-back logic tests (mock writer)
└── IntelligentActionServiceTests.swift # Service tests
```

## Code Style Guidelines

### Swift Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line length**: 120 characters max
- **File header**: Include file name, project, and brief description
- **File footer**: Single blank line at end

### Naming Conventions
```swift
// Types: UpperCamelCase
class ClipboardStorage { }
struct ClipboardItem { }
enum ContentType { }

// Functions/Variables: lowerCamelCase
func detectContentType(_ content: String) -> ContentType
var isPinned: Bool
let sourceAppBundle: String?

// Constants: lowerCamelCase (not SCREAMING_CASE)
private let itemsTable = Table("clipboard_items")
private let maxPreviewLength = 100

// Booleans: use "is", "has", "should" prefixes
var isPinned: Bool
var hasImageData: Bool

// Singletons: .shared
static let shared = ClipboardStorage()
```

### MARK Comments
Use `// MARK: -` to organize code sections:
```swift
// MARK: - Content Type
enum ContentType { }

// MARK: - Initialization
init() { }

// MARK: - Public Methods
func saveItem(_ item: ClipboardItem) { }

// MARK: - Private Helpers
private func setupDatabase() { }
```

### Documentation
```swift
/// Detects the content type of given text
/// - Parameter content: The text content to analyze
/// - Returns: The detected ContentType enum value
static func detectContentType(_ content: String) -> ContentType
```

### Imports Organization
```swift
// 1. Foundation and standard library
import Foundation
import AppKit

// 2. External frameworks
import SQLite
import CryptoKit

// 3. Apple frameworks
import Vision
import os.log
```

## Architecture Patterns

### MVVM Pattern
- **Models**: Data structures and business logic (`ClipboardItem`)
- **ViewModels**: State management and presentation logic (`ClipboardViewModel`)
- **Views**: SwiftUI views with declarative UI (`PanelView`, `SettingsView`)
- **Services**: Singleton services for cross-cutting concerns (`ClipboardStorage`, `ClipboardMonitor`)

### Singleton Services
```swift
class ClipboardStorage {
    static let shared = ClipboardStorage()
    private init() { }
}
```

### Dependency Injection for Tests
```swift
// Production
private init() {
    self.isTestMode = false
    setupDatabase(at: nil)
}

// Testing
init(databasePath: String?) {
    self.isTestMode = true
    setupDatabase(at: databasePath)
}
```

## Error Handling

### Swift Errors
```swift
enum ClipboardError: Error {
    case databaseConnectionFailed
    case invalidData
    case itemNotFound
}

func loadItem(id: UUID) throws -> ClipboardItem {
    guard let item = try fetchItem(id: id) else {
        throw ClipboardError.itemNotFound
    }
    return item
}
```

### Optional Chaining
```swift
// Prefer guard let for early returns
guard let db = db else {
    logger.error("Database not initialized")
    return
}

// Use if let for single conditional
if let imageData = item.imageData {
    processImage(imageData)
}
```

### Logging
```swift
import os.log

private let logger = Logger(subsystem: "com.wxl", category: "Storage")

logger.info("Item saved: \(item.id)")
logger.error("Failed to save: \(error.localizedDescription)")
```

## Testing Guidelines

### Test Naming
```swift
// Format: test<MethodName>_<Scenario>
func testDetectContentType_HTTP_URL() { }
func testDetectContentType_Email_WithDots() { }
func testSaveItem_WithValidData_Succeeds() { }
```

### Test Structure
```swift
func testDetectContentType_URL() {
    // Given
    let content = "https://example.com"
    
    // When
    let result = ClipboardItem.detectContentType(content)
    
    // Then
    XCTAssertEqual(result, .url)
}
```

### Test Isolation
```swift
final class ClipboardStorageTests: XCTestCase {
    var storage: ClipboardStorage!
    var tempDBPath: String!
    
    override func setUp() {
        tempDBPath = NSTemporaryDirectory().appending("test_\(UUID().uuidString).db")
        storage = ClipboardStorage(databasePath: tempDBPath)
    }
    
    override func tearDown() {
        storage = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }
}
```

### Simulation Mode
```swift
// For services that interact with system (files, URLs, apps)
class IntelligentActionService {
    var simulationMode = false
    var lastSimulatedAction: (type: String, content: String)?
    
    func openURL(_ urlString: String) {
        if simulationMode {
            lastSimulatedAction = ("openURL", urlString)
            return
        }
        NSWorkspace.shared.open(url)
    }
}
```

## Platform-Specific Considerations

### macOS APIs
- Use `NSWorkspace` for system integration (opening URLs, apps)
- Use `NSPasteboard` for clipboard access
- Use `UserDefaults` for app preferences
- Use `FileManager` for file operations in Application Support

### Sandbox Compliance
- Database location: `~/Library/Application Support/WXL/clipboard.db`
- Use `FileManager.default.url(for: .applicationSupportDirectory, ...)`
- Handle sandbox permissions gracefully

### SwiftUI Best Practices
- Use `@State`, `@Published`, `@ObservedObject` for state management
- Prefer declarative UI over imperative updates
- Use `.sheet`, `.alert`, `.confirmationDialog` for modals
- Leverage SwiftUI previews for development

## Git Conventions

### Commit Format
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Test additions/changes
- `refactor`: Code refactoring
- `style`: Formatting (no code change)
- `chore`: Build/config changes

### Examples
```
feat(detection): add support for detecting IP addresses

- Add IPv4 address detection pattern
- Add IPv6 address detection pattern
- Update ContentType enum

Closes #123
```

## Development Workflow

1. **Before implementing**: Review existing code patterns in similar files
2. **Write tests first**: TDD approach for new features
3. **Run tests**: `swift test --filter <TestCase>` after each change
4. **Check diagnostics**: Use `swift build` to catch compilation errors
5. **Update documentation**: Update README.md and CHANGELOG.md if needed

## Common Patterns

### Singleton with Test Support
```swift
class MyService {
    static let shared = MyService()
    private let isTestMode: Bool
    
    private init() {
        self.isTestMode = false
    }
    
    init(testMode: Bool) {
        self.isTestMode = testMode
    }
}
```

### DispatchQueue for Background Work
```swift
private let queue = DispatchQueue(label: "com.wxl.service", qos: .userInitiated)

func performAsync() {
    queue.async {
        // Background work
        DispatchQueue.main.async {
            // UI updates
        }
    }
}
```

### Codable for Persistence
```swift
struct ClipboardItem: Codable {
    let id: UUID
    let content: String
    // Automatic Codable synthesis
}
```
