//
//  SettingsCard.swift
//  RClick
//
//  Created by Claude on 2026/10/11.
//

import SwiftUI
import AppKit

/// 现代卡片容器：提供统一的微边框、背景、内间距与标题结构
struct SettingsCard<Content: View, Trailing: View>: View {
    let title: String?
    let icon: String?
    let iconColor: Color
    let subtitle: String?
    let trailing: Trailing?
    let headerAction: (() -> Void)?
    let content: Content

    init(
        title: String? = nil,
        icon: String? = nil,
        iconColor: Color = .blue,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.trailing = trailing()
        self.headerAction = headerAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || icon != nil {
                headerContent

                Divider()
                    .opacity(0.6)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private var headerContent: some View {
        if let headerAction {
            Button(action: headerAction) {
                headerRow
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            headerRow
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                    )
            }

            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
        .padding(.vertical, 4)
        .padding(.bottom, 2)
    }
}

extension SettingsCard where Trailing == EmptyView {
    init(
        title: String? = nil,
        icon: String? = nil,
        iconColor: Color = .blue,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            icon: icon,
            iconColor: iconColor,
            subtitle: subtitle,
            trailing: { EmptyView() },
            content: content
        )
    }
}

/// 卡片内部的标准行组件
struct SettingsCardRow<Trailing: View>: View {
    let icon: String?
    let iconImage: String?
    let iconColor: Color
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        icon: String? = nil,
        iconImage: String? = nil,
        iconColor: Color = .blue,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconImage = iconImage
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let iconImage {
                Image(iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                    )
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            trailing
        }
        .padding(.vertical, 4)
    }
}

/// 状态指示胶囊药丸组件
struct StatusPill: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }

            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}
