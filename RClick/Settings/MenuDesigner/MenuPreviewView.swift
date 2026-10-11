//
//  MenuPreviewView.swift
//  RClick
//
//  Live WYSIWYG macOS Right-Click Context Menu Preview
//

import AppKit
import SwiftUI

struct MenuPreviewView: View {
    @ObservedObject var viewModel: MenuDesignerViewModel
    @State private var hoveredItemId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - 1. Preview Header & Controls
            previewHeader

            // MARK: - 2. Immersive Desktop Canvas
            desktopCanvas

            // MARK: - 3. Bottom Deck: Structure Health & Live Guide
            bottomDeck
        }
    }

    // MARK: - Header
    private var previewHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Label(AppLocalization.localized("Live Preview"), systemImage: "macwindow.on.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Submenu collapse button if currently active
            if viewModel.previewActiveSubmenuId != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.previewActiveSubmenuId = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text(appLocalized: "Collapse")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .transition(.opacity)
            }

            // Theme Switcher (Segmented Light / Dark)
            Picker("", selection: $viewModel.isPreviewDarkMode) {
                Label(AppLocalization.localized("Light"), systemImage: "sun.max.fill").tag(false)
                Label(AppLocalization.localized("Dark"), systemImage: "moon.stars.fill").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 135)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Desktop Canvas
    private var desktopCanvas: some View {
        ZStack(alignment: .topLeading) {
            // macOS Sonoma/Sequoia style wallpaper backdrop
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: viewModel.isPreviewDarkMode
                            ? [
                                Color(red: 0.13, green: 0.14, blue: 0.22),
                                Color(red: 0.07, green: 0.08, blue: 0.13)
                            ]
                            : [
                                Color(red: 0.88, green: 0.91, blue: 0.96),
                                Color(red: 0.79, green: 0.83, blue: 0.90)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            viewModel.isPreviewDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )

            // Simulated Finder Context Watermark
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary.opacity(0.7))
                Text(appLocalized: "Finder")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(.top, 8)
            .padding(.leading, 12)

            // Content
            if viewModel.items.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 6) {
                    // Primary Context Menu
                    contextMenuCard(items: viewModel.items, isSubmenu: false)
                        .frame(width: 195)

                    // Cascading Submenu Flyout (if active)
                    if let activeId = viewModel.previewActiveSubmenuId,
                       let activeItem = findItem(id: activeId, in: viewModel.items),
                       activeItem.kind == .submenu,
                       !activeItem.children.isEmpty {
                        contextMenuCard(items: activeItem.children, isSubmenu: true)
                            .frame(width: 195)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 28)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 330)
        .compositingGroup()
        .environment(\.colorScheme, viewModel.isPreviewDarkMode ? .dark : .light)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(AppLocalization.localized("Menu is empty"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(AppLocalization.localized("Add items on the left to build your menu"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Context Menu Card
    private func contextMenuCard(items: [DesignerItem], isSubmenu: Bool) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    switch item.kind {
                    case .separator:
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)

                    case .item, .submenu:
                        contextMenuItemRow(item: item)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.regularMaterial)
                .shadow(
                    color: Color.black.opacity(viewModel.isPreviewDarkMode ? 0.45 : 0.16),
                    radius: 14,
                    x: 0,
                    y: 7
                )
                .shadow(
                    color: Color.black.opacity(viewModel.isPreviewDarkMode ? 0.25 : 0.08),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(viewModel.isPreviewDarkMode ? 0.18 : 0.12), lineWidth: 0.7)
        )
        .compositingGroup()
    }

    // MARK: - Menu Item Row
    private func contextMenuItemRow(item: DesignerItem) -> some View {
        let isHovered = hoveredItemId == item.id
        let isSubmenuActive = viewModel.previewActiveSubmenuId == item.id
        let isSelectedInTree = viewModel.selectedItemId == item.id
        let isHighlighted = isHovered || isSubmenuActive

        return Button {
            // 点击联动：展开/收起二级菜单，并在左侧树形编辑器高亮对应项
            if item.kind == .submenu {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if viewModel.previewActiveSubmenuId == item.id {
                        viewModel.previewActiveSubmenuId = nil
                    } else {
                        viewModel.previewActiveSubmenuId = item.id
                    }
                }
            }
            viewModel.selectedItemId = item.id
        } label: {
            HStack(spacing: 8) {
                // Item Icon
                itemIconView(item: item, isHighlighted: isHighlighted)
                    .frame(width: 16, height: 16)

                // Item Title
                Text(item.displayTitle)
                    .font(.system(size: 12.5, weight: isSelectedInTree ? .medium : .regular))
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                // Submenu Chevron
                if item.kind == .submenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .padding(.horizontal, 4)
        .onHover { hovering in
            hoveredItemId = hovering ? item.id : nil
            if hovering && item.kind == .submenu {
                withAnimation(.easeInOut(duration: 0.12)) {
                    viewModel.previewActiveSubmenuId = item.id
                }
            }
        }
    }

    // MARK: - Item Icon View
    @ViewBuilder
    private func itemIconView(item: DesignerItem, isHighlighted: Bool) -> some View {
        if item.itemType == .app, let url = item.appURL {
            Image(nsImage: IconCache.shared.icon(for: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            let symbol = item.displayIcon
            Image(systemName: symbol.isEmpty ? "gear" : symbol)
                .font(.system(size: 12))
                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
        }
    }

    // MARK: - Bottom Deck (下半部分空间利用)
    private var bottomDeck: some View {
        VStack(spacing: 8) {
            // 结构与指标卡片
            menuHealthCard

            // 交互提示卡片
            interactiveGuideCard
        }
    }

    // MARK: - Menu Health Card
    private var menuHealthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(AppLocalization.localized("Menu Structure"), systemImage: "chart.bar.doc.horizontal")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // 健康度建议徽章
                healthBadge
            }

            HStack(spacing: 6) {
                statPill(
                    title: AppLocalization.localized("Top Level"),
                    value: "\(viewModel.items.count)",
                    icon: "list.bullet"
                )

                statPill(
                    title: AppLocalization.localized("Submenus"),
                    value: "\(viewModel.availableSubmenus.count)",
                    icon: "folder"
                )

                statPill(
                    title: AppLocalization.localized("Total Actions"),
                    value: "\(viewModel.totalItemCount)",
                    icon: "sparkles"
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Health Recommendation Badge
    private var healthBadge: some View {
        let count = viewModel.items.count
        let (label, color): (String, Color) = {
            if count == 0 {
                return (AppLocalization.localized("Empty"), .secondary)
            } else if count <= 8 {
                return (AppLocalization.localized("Optimal"), .green)
            } else if count <= 12 {
                return (AppLocalization.localized("Moderate"), .orange)
            } else {
                return (AppLocalization.localized("Too Many Items"), .red)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Stat Pill
    private func statPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Interactive Guide Card
    private var interactiveGuideCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(appLocalized: "Live Interactive Tips")
                    .font(.system(size: 11, weight: .semibold))
                Text(appLocalized: "Hover or click submenus to preview cascading flyout. Click any item to locate it in the tree editor.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func findItem(id: UUID, in list: [DesignerItem]) -> DesignerItem? {
        for item in list {
            if item.id == id { return item }
            if let found = findItem(id: id, in: item.children) { return found }
        }
        return nil
    }
}
