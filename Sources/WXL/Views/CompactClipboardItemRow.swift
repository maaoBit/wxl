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
    var onCopy: () -> Void = {}
    var openAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // 类型图标（小）
            typeIcon

            // 内容预览（紧凑） - 对于文件显示完整路径
            VStack(alignment: .leading, spacing: 2) {
                if item.contentType == .filePath, let fileURLs = item.fileURLs, !fileURLs.isEmpty {
                    Text(fileURLs.count == 1 ? fileURLs[0] : "\(fileURLs.count) 个文件")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(item.previewText)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

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
        .contextMenu {
            Button("粘贴") {
                onPaste()
            }
            Button("复制内容") {
                onCopy()
            }

            Divider()

            Button(item.isPinned ? "取消置顶" : "置顶") {
                onPin()
            }
            if let openAction = openAction {
                Button(openActionTitle) {
                    openAction()
                }
            }

            Divider()

            Button("删除", role: .destructive) {
                onDelete()
            }
        }
    }

    private var openActionTitle: String {
        switch item.contentType {
        case .url: return "在浏览器中打开"
        case .filePath: return "在 Finder 中显示"
        case .email: return "发送邮件"
        case .phoneNumber: return "FaceTime"
        default: return "打开"
        }
    }
    
    // MARK: - Type Icon
    @ViewBuilder
    private var typeIcon: some View {
    if item.contentType == .filePath, let fileURLs = item.fileURLs, let firstPath = fileURLs.first {
        // 显示文件的真实图标（带缓存，icon(forFile:) 每次调用都访问磁盘）
        let icon = FileIconCache.icon(forPath: firstPath)
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
    } else if item.contentType == .image,
              let thumbnailData = item.thumbnail,
              let thumbnailImage = NSImage(data: thumbnailData) {
        // 图片条目显示缩略图（无缩略图的旧条目回退到类型图标）
        Image(nsImage: thumbnailImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    } else {
        Image(systemName: item.contentType.icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.7))
            .frame(width: 16, height: 16)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
    }
    }
}
