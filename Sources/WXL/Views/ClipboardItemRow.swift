//
//  ClipboardItemRow.swift
//  WXL
//
//  Individual clipboard item row view
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let onAction: (() -> Void)?

    @State private var isHovered: Bool = false

    var body: some View {
        FloatingCard(isSelected: isSelected) {
            HStack(alignment: .top, spacing: 12) {
                // 类型图标
                typeIcon

                // 内容区域
                VStack(alignment: .leading, spacing: 4) {
                    headerView
                    contentView
                    footerView
                }

                Spacer()

                // 操作按钮
                if isSelected || isHovered {
                    actionButtons
                }
            }
        }
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onPaste()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Type Icon
    private var typeIcon: some View {
        Image(systemName: item.contentType.icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            // 来源应用
            if let app = item.sourceApp {
                HStack(spacing: 4) {
                    if let bundleId = item.sourceAppBundle,
                       let appImage = NSImage(contentsOfFile: NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path ?? "") {
                        Image(nsImage: appImage)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text(app)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // 时间
            Text(item.timeAgo)
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))

            // 置顶标记
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var contentView: some View {
        if item.contentType == .image, let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
            // 图片预览
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            // 文本内容
            Text(item.previewText)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 8) {
            // 内容类型标签
            Text(item.contentType.rawValue.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

            // OCR 标记
            if item.ocrText != nil {
                Text("OCR")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // 置顶按钮
            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(item.isPinned ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help("置顶 (⌘P)")

            // 联动操作
            if let action = onAction {
                Button(action: action) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(actionHint)
            }

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("删除 (⌘D)")
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var actionHint: String {
        switch item.contentType {
        case .url: return "在浏览器中打开"
        case .filePath: return "在 Finder 中显示"
        case .email: return "发送邮件"
        case .phoneNumber: return "FaceTime"
        default: return ""
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("粘贴") {
            onPaste()
        }
        .keyboardShortcut(.return, modifiers: [])

        Divider()

        Button(item.isPinned ? "取消置顶" : "置顶") {
            onPin()
        }
        .keyboardShortcut("p", modifiers: .command)

        Button("删除") {
            onDelete()
        }
        .keyboardShortcut("d", modifiers: .command)

        if let action = onAction {
            Divider()

            Button(contextActionTitle) {
                action()
            }
        }

        Divider()

        Button("复制内容") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.content, forType: .string)
        }
    }

    private var contextActionTitle: String {
        switch item.contentType {
        case .url: return "在浏览器中打开"
        case .filePath: return "在 Finder 中显示"
        case .email: return "发送邮件"
        case .phoneNumber: return "FaceTime"
        default: return ""
        }
    }
}
