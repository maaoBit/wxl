//
//  CompactClipboardItemRow.swift
//  WXL
//
//  Compact list item for left panel
//

import SwiftUI

struct CompactClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 类型图标（小）
            Image(systemName: item.contentType.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.7))
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )

            // 内容预览（紧凑）
            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    // 来源应用
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                    }

                    // 时间
                    Text(item.timeAgo)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))

                    Spacer()

                    // 置顶标记
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onPaste()
        }
    }
}
