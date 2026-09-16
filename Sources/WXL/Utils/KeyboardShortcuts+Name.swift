//
//  KeyboardShortcuts+Name.swift
//  WXL
//
//  Custom keyboard shortcuts configuration
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // 3.x 起 `default:` 参数更名为 `initial:`
    static let togglePanel = Self("togglePanel", initial: .init(.c, modifiers: [.command, .shift]))
}
