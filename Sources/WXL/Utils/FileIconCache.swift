//
//  FileIconCache.swift
//  WXL
//
//  Caches NSWorkspace file icons (icon(forFile:) hits disk on every call)
//

import AppKit

enum FileIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forPath path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }
}
