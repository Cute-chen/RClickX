//
//  MenuDesignerTabView.swift
//  RClick
//
//  Visual WYSIWYG Context Menu Designer Tab
//

import AppKit
import SwiftUI

struct MenuDesignerTabView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: MenuDesignerViewModel
    @State private var showResetConfirmation = false
    @State private var showPresetSheet = false

    init(viewModel: MenuDesignerViewModel = MenuDesignerViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Toolbar
            toolbarHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Toast / Alert Banners
            if let toast = viewModel.saveToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 13))
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            // MARK: - Main Dual-Panel Workspace
            HStack(spacing: 0) {
                // Left Panel: Menu Items Tree
                treeEditorPanel
                    .frame(minWidth: 320, maxWidth: .infinity)

                Divider()

                // Right Panel: Live Context Menu Preview (Expanded to 460 to accommodate cascading flyouts)
                MenuPreviewView(viewModel: viewModel)
                    .padding(14)
                    .frame(width: 460)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
            }
        }
        .onAppear {
            viewModel.loadIfNeeded(using: appState)
        }
        .sheet(isPresented: $showPresetSheet) {
            PresetPickerSheetView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(isPresented: $viewModel.showAddItemSheet) {
            AddItemSheetView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(isPresented: $viewModel.showAddSubmenuSheet) {
            AddSubmenuSheetView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.itemToEdit) { item in
            EditItemSheetView(item: item, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showRawJsonSheet) {
            RawJsonSheetView(viewModel: viewModel)
        }
        .alert(
            Text(appLocalized: "Restore Default Menu?"),
            isPresented: $showResetConfirmation
        ) {
            Button(AppLocalization.localized("Restore"), role: .destructive) {
                viewModel.restoreDefaultLayout(using: appState)
            }
            Button(AppLocalization.localized("Cancel"), role: .cancel) {}
        } message: {
            Text(appLocalized: "This resets the context menu to the default structure. Your custom ordering and submenus will be removed.")
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 12) {
            Label(
                String(format: AppLocalization.localized("%lld items"), viewModel.items.count),
                systemImage: "list.bullet.rectangle"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

            Spacer()

            // Presets Picker
            Button {
                showPresetSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text(appLocalized: "Presets")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(AppLocalization.localized("Select Menu Preset"))

            // Quick Add Menu
            Menu {
                Button {
                    viewModel.targetParentSubmenuId = nil
                    viewModel.showAddItemSheet = true
                } label: {
                    Label(AppLocalization.localized("Add Item…"), systemImage: "plus")
                }

                Button {
                    viewModel.targetParentSubmenuId = nil
                    viewModel.showAddSubmenuSheet = true
                } label: {
                    Label(AppLocalization.localized("Add Submenu…"), systemImage: "folder.badge.plus")
                }

                Button {
                    viewModel.addSeparator(toSubmenu: nil)
                } label: {
                    Label(AppLocalization.localized("Add Separator"), systemImage: "minus")
                }
            } label: {
                Label(AppLocalization.localized("Add"), systemImage: "plus")
            }
            .menuStyle(.borderedButton)

            Divider()
                .frame(height: 18)

            // Raw JSON code viewer
            Button {
                viewModel.showRawJsonSheet = true
            } label: {
                Image(systemName: "curlybraces")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(AppLocalization.localized("View Generated JSON"))

            // Reset to defaults
            Button {
                showResetConfirmation = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(AppLocalization.localized("Restore Default Layout"))

            // Save & Apply button
            Button {
                viewModel.saveAndApply(using: appState)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(appLocalized: "Apply to Finder")
                }
                .fontWeight(.medium)
                .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(viewModel.hasUnsavedChanges ? .blue : .secondary)
        }
    }

    // MARK: - Tree Editor Panel

    private var treeEditorPanel: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(appLocalized: "No menu items yet")
                        .font(.headline)
                    Text(appLocalized: "Add items from the toolbar or restore defaults to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.localized("Restore Default Layout")) {
                        viewModel.restoreDefaultLayout(using: appState)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.items) { item in
                            DesignerNodeRowView(item: item, level: 0, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Node Row View

struct DesignerNodeRowView: View {
    let item: DesignerItem
    let level: Int
    @ObservedObject var viewModel: MenuDesignerViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Indentation
                if level > 0 {
                    Spacer().frame(width: CGFloat(level * 20))
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1.5, height: 18)
                }

                // Row Body based on kind
                switch item.kind {
                case .separator:
                    HStack(spacing: 8) {
                        Image(systemName: "minus")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(appLocalized: "Separator")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                case .submenu:
                    HStack(spacing: 8) {
                        Button {
                            viewModel.toggleExpand(id: item.id)
                        } label: {
                            Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: item.displayIcon)
                            .font(.system(size: 14))
                            .foregroundStyle(.purple)

                        Text(item.displayTitle)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(String(format: "(%lld)", item.children.count))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()

                        Spacer()

                        // Submenu quick add button
                        Button {
                            viewModel.targetParentSubmenuId = item.id
                            viewModel.showAddItemSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                        .help(AppLocalization.localized("Add into this Submenu"))
                    }

                case .item:
                    HStack(spacing: 8) {
                        if item.itemType == .app, let url = item.appURL {
                            Image(nsImage: IconCache.shared.icon(for: url))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: item.displayIcon.isEmpty ? "gear" : item.displayIcon)
                                .font(.system(size: 13))
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(item.displayTitle)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                if item.customTitle != nil || item.customIcon != nil {
                                    Text(appLocalized: "Customized")
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                        .fixedSize()
                                }
                            }
                        }

                        Spacer()

                        // Type badge
                        Text(item.typeBadge)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.typeBadgeColor.opacity(0.12))
                            .foregroundStyle(item.typeBadgeColor)
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }

                // Action Controls: Move Up, Down, Edit, Delete
                HStack(spacing: 4) {
                    Button {
                        viewModel.moveUp(id: item.id)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help(AppLocalization.localized("Move Up"))

                    Button {
                        viewModel.moveDown(id: item.id)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help(AppLocalization.localized("Move Down"))

                    if item.kind != .separator {
                        Button {
                            viewModel.itemToEdit = item
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help(AppLocalization.localized("Edit Item"))
                    }

                    // Move to submenu or top level
                    Menu {
                        if level > 0 {
                            Button(AppLocalization.localized("Move to Top Level")) {
                                viewModel.moveToTopLevel(id: item.id)
                            }
                        }
                        ForEach(viewModel.availableSubmenus, id: \.id) { sub in
                            if sub.id != item.id {
                                Button(String(format: AppLocalization.localized("Move to %@"), sub.title)) {
                                    viewModel.moveToSubmenu(id: item.id, targetSubmenuId: sub.id)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .help(AppLocalization.localized("Move into Submenu"))

                    Button {
                        viewModel.deleteItem(id: item.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help(AppLocalization.localized("Delete Item"))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(viewModel.selectedItemId == item.id ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedItemId = item.id
                if item.kind == .submenu {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.previewActiveSubmenuId = item.id
                    }
                }
            }

            // Children recursion for submenus
            if item.kind == .submenu && item.isExpanded {
                ForEach(item.children) { child in
                    DesignerNodeRowView(item: child, level: level + 1, viewModel: viewModel)
                }
            }
        }
    }
}
