//
//  MenuDesignerSheets.swift
//  RClick
//
//  Dialogs & Sheets for adding items, creating submenus, and customizing nodes.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Add Item Sheet

struct AddItemSheetView: View {
    @ObservedObject var viewModel: MenuDesignerViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: Category = .all
    @State private var searchText: String = ""
    @State private var targetParentId: UUID?

    // Quick creation & editing states
    @State private var showSelectApp = false
    @State private var editingApp: OpenWithApp?

    @State private var showCreateActionSheet = false
    @State private var editingAction: RCAction?

    @State private var editingFile: NewFile?

    @State private var showSelectFolder = false

    @State private var itemPendingDelete: PaletteEntry?
    @State private var showDeleteConfirmation = false

    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case apps = "Apps"
        case actions = "Actions"
        case newFile = "New File"
        case commonDir = "Folders"
        var id: String { rawValue }
    }

    struct PaletteEntry: Identifiable {
        let id: String
        let type: MenuItemType
        let name: String
        let icon: String
        let appURL: URL?
        let isEnabled: Bool
        let canEdit: Bool
        let canDelete: Bool
        let subtitle: String?
    }

    private var paletteEntries: [PaletteEntry] {
        var list: [PaletteEntry] = []

        if selectedCategory == .all || selectedCategory == .apps {
            for app in appState.apps {
                list.append(PaletteEntry(
                    id: app.id,
                    type: .app,
                    name: app.name,
                    icon: "app",
                    appURL: app.url,
                    isEnabled: true,
                    canEdit: true,
                    canDelete: true,
                    subtitle: app.arguments.isEmpty ? nil : app.arguments.joined(separator: " ")
                ))
            }
        }

        if selectedCategory == .all || selectedCategory == .actions {
            for act in appState.actions {
                list.append(PaletteEntry(
                    id: act.id,
                    type: .action,
                    name: act.displayName,
                    icon: act.icon,
                    appURL: nil,
                    isEnabled: act.enabled,
                    canEdit: act.isCustomScript,
                    canDelete: act.isCustomScript,
                    subtitle: act.isCustomScript ? (act.script ?? "Shell Script") : nil
                ))
            }
        }

        if selectedCategory == .all || selectedCategory == .newFile {
            for nf in appState.newFiles {
                list.append(PaletteEntry(
                    id: nf.id,
                    type: .newFile,
                    name: nf.displayName,
                    icon: nf.icon,
                    appURL: nil,
                    isEnabled: nf.enabled,
                    canEdit: true,
                    canDelete: true,
                    subtitle: ".\(nf.ext)"
                ))
            }
        }

        if selectedCategory == .all || selectedCategory == .commonDir {
            for cd in appState.cdirs {
                list.append(PaletteEntry(
                    id: cd.id,
                    type: .commonDir,
                    name: cd.displayName,
                    icon: cd.icon,
                    appURL: nil,
                    isEnabled: appState.showCommonDirs,
                    canEdit: false,
                    canDelete: true,
                    subtitle: cd.url.path
                ))
            }
        }

        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appLocalized: "Add Item to Menu")
                        .font(.headline)
                    Text(appLocalized: "Select an item to add to your menu, or create new apps and custom scripts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(AppLocalization.localized("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Filters & Actions Bar
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Picker("", selection: $selectedCategory) {
                        ForEach(Category.allCases) { cat in
                            Text(appLocalized: cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Target Submenu Selector
                    Picker(AppLocalization.localized("Add to:"), selection: $targetParentId) {
                        Text(appLocalized: "Top Level").tag(nil as UUID?)
                        ForEach(viewModel.availableSubmenus, id: \.id) { sub in
                            Text(sub.title).tag(sub.id as UUID?)
                        }
                    }
                    .frame(width: 180)
                }

                HStack(spacing: 10) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(AppLocalization.localized("Search items…"), text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Context-dependent Quick Action Button
                    switch selectedCategory {
                    case .all:
                        Menu {
                            Button {
                                showSelectApp = true
                            } label: {
                                Label(AppLocalization.localized("Add External App…"), systemImage: "plus.app")
                            }
                            Button {
                                showCreateActionSheet = true
                            } label: {
                                Label(AppLocalization.localized("New Script Action…"), systemImage: "terminal")
                            }
                            Button {
                                editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                            } label: {
                                Label(AppLocalization.localized("New File Template…"), systemImage: "doc.badge.plus")
                            }
                            Button {
                                showSelectFolder = true
                            } label: {
                                Label(AppLocalization.localized("Add Common Folder…"), systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Label(AppLocalization.localized("New / Import…"), systemImage: "plus")
                        }
                        .menuStyle(.borderedButton)

                    case .apps:
                        Button {
                            showSelectApp = true
                        } label: {
                            Label(AppLocalization.localized("Add External App…"), systemImage: "plus.app")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    case .actions:
                        Button {
                            showCreateActionSheet = true
                        } label: {
                            Label(AppLocalization.localized("New Script Action…"), systemImage: "terminal")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)

                    case .newFile:
                        HStack(spacing: 6) {
                            Button(AppLocalization.localized("Restore Defaults")) {
                                appState.resetFiletypeItems()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                editingFile = NewFile(ext: "", name: "", idx: appState.newFiles.count)
                            } label: {
                                Label(AppLocalization.localized("New File Template…"), systemImage: "doc.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                    case .commonDir:
                        Button {
                            showSelectFolder = true
                        } label: {
                            Label(AppLocalization.localized("Add Common Folder…"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // Palette Items List
            List {
                if paletteEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(appLocalized: "No matching items found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(paletteEntries) { entry in
                        HStack(spacing: 10) {
                            if let url = entry.appURL {
                                Image(nsImage: IconCache.shared.icon(for: url))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: entry.icon.isEmpty ? "gear" : entry.icon)
                                    .font(.system(size: 15))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.name)
                                        .font(.system(size: 13, weight: .medium))

                                    if !entry.isEnabled {
                                        Text(appLocalized: "Auto-enabled")
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.12))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }

                                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // Controls: Edit, Delete, Add to Menu
                            HStack(spacing: 8) {
                                if entry.canEdit {
                                    Button {
                                        editEntry(entry)
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(AppLocalization.localized("Edit Item"))
                                }

                                if entry.canDelete {
                                    Button {
                                        itemPendingDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(AppLocalization.localized("Delete Item"))
                                }

                                Button {
                                    viewModel.addItem(
                                        type: entry.type,
                                        referenceId: entry.id,
                                        title: entry.name,
                                        icon: entry.icon,
                                        appURL: entry.appURL,
                                        toSubmenu: targetParentId
                                    )
                                } label: {
                                    Label(AppLocalization.localized("Add"), systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .frame(width: 580, height: 480)
        .onAppear {
            targetParentId = viewModel.targetParentSubmenuId
        }
        .fileImporter(
            isPresented: $showSelectApp,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let url = files.first {
                    let appItem = OpenWithApp(appURL: url)
                    appState.addApp(item: appItem)
                    Messager.shared.sendRunningNotification()
                    viewModel.addItem(
                        type: .app,
                        referenceId: appItem.id,
                        title: appItem.name,
                        icon: "app",
                        appURL: appItem.url,
                        toSubmenu: targetParentId
                    )
                }
            case .failure(let error):
                print(error)
            }
        }
        .fileImporter(
            isPresented: $showSelectFolder,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let commonDir = CommonDir(id: UUID().uuidString, name: url.lastPathComponent, url: url, icon: iconForDirectory(url: url))
                    if !appState.cdirs.contains(where: { $0.url == commonDir.url }) {
                        appState.bookmarkManager.saveBookmark(for: url)
                        appState.cdirs.append(commonDir)
                        appState.sync()
                        Messager.shared.sendRunningNotification()
                        viewModel.addItem(
                            type: .commonDir,
                            referenceId: commonDir.id,
                            title: commonDir.displayName,
                            icon: commonDir.icon,
                            appURL: nil,
                            toSubmenu: targetParentId
                        )
                    }
                }
            case .failure(let error):
                print(error)
            }
        }
        .sheet(isPresented: $showCreateActionSheet) {
            EditCustomActionSheetView(action: nil) { newAction in
                appState.addAction(newAction)
                Messager.shared.sendRunningNotification()
                viewModel.addItem(
                    type: .action,
                    referenceId: newAction.id,
                    title: newAction.displayName,
                    icon: newAction.icon,
                    appURL: nil,
                    toSubmenu: targetParentId
                )
            }
        }
        .sheet(item: $editingAction) { action in
            EditCustomActionSheetView(action: action) { updatedAction in
                appState.updateAction(updatedAction)
                Messager.shared.sendRunningNotification()
            }
        }
        .sheet(item: $editingApp) { app in
            EditAppSheetView(app: app, appState: appState)
        }
        .sheet(item: $editingFile) { file in
            EditFileTypeSheetView(file: file, appState: appState)
        }
        .alert(
            Text(String(format: AppLocalization.localized("Delete \"%@\"?"), itemPendingDelete?.name ?? "")),
            isPresented: $showDeleteConfirmation
        ) {
            Button(AppLocalization.localized("Delete"), role: .destructive) {
                if let entry = itemPendingDelete {
                    deleteEntry(entry)
                }
            }
            Button(AppLocalization.localized("Cancel"), role: .cancel) {}
        } message: {
            Text(appLocalized: "This will remove the item from your library.")
        }
    }

    private func editEntry(_ entry: PaletteEntry) {
        switch entry.type {
        case .app:
            if let app = appState.apps.first(where: { $0.id == entry.id }) {
                editingApp = app
            }
        case .action:
            if let action = appState.actions.first(where: { $0.id == entry.id }) {
                editingAction = action
            }
        case .newFile:
            if let file = appState.newFiles.first(where: { $0.id == entry.id }) {
                editingFile = file
            }
        default:
            break
        }
    }

    private func deleteEntry(_ entry: PaletteEntry) {
        switch entry.type {
        case .app:
            if let index = appState.apps.firstIndex(where: { $0.id == entry.id }) {
                appState.deleteApp(index: index)
                Messager.shared.sendRunningNotification()
                viewModel.removeNodesReferencing(referenceId: entry.id)
            }
        case .action:
            appState.deleteAction(id: entry.id)
            Messager.shared.sendRunningNotification()
            viewModel.removeNodesReferencing(referenceId: entry.id)
        case .newFile:
            appState.deleteNewFile(id: entry.id)
            Messager.shared.sendRunningNotification()
            viewModel.removeNodesReferencing(referenceId: entry.id)
        case .commonDir:
            if let index = appState.cdirs.firstIndex(where: { $0.id == entry.id }) {
                appState.cdirs.remove(at: index)
                appState.sync()
                Messager.shared.sendRunningNotification()
                viewModel.removeNodesReferencing(referenceId: entry.id)
            }
        }
    }
}

// MARK: - Add Submenu Sheet

struct AddSubmenuSheetView: View {
    @ObservedObject var viewModel: MenuDesignerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var icon: String = "folder"
    @State private var targetParentId: UUID?

    private let popularSymbols = [
        "folder", "folder.badge.gearshape", "terminal", "chevron.left.forwardslash.chevron.right",
        "doc.badge.plus", "ellipsis.circle", "star", "bolt", "wrench.and.screwdriver",
        "tag", "tray", "cube", "link", "archivebox", "sparkles", "gearshape"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(appLocalized: "Add Submenu")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Title Field
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLocalized: "Submenu Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(AppLocalization.localized("e.g. Developer Tools"), text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Parent Selector
                if !viewModel.availableSubmenus.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appLocalized: "Parent Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $targetParentId) {
                            Text(appLocalized: "Top Level").tag(nil as UUID?)
                            ForEach(viewModel.availableSubmenus, id: \.id) { sub in
                                Text(sub.title).tag(sub.id as UUID?)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Icon Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text(appLocalized: "Submenu Icon (SF Symbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: icon.isEmpty ? "folder" : icon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("SF Symbol Name", text: $icon)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Quick Popular Symbols Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(popularSymbols, id: \.self) { sym in
                            Button {
                                icon = sym
                            } label: {
                                Image(systemName: sym)
                                    .font(.system(size: 14))
                                    .frame(width: 28, height: 28)
                                    .background(icon == sym ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(icon == sym ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(AppLocalization.localized("Create Submenu")) {
                    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.addSubmenu(
                        title: cleanTitle.isEmpty ? AppLocalization.localized("Submenu") : cleanTitle,
                        icon: icon,
                        toSubmenu: targetParentId
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380, height: 350)
        .onAppear {
            targetParentId = viewModel.targetParentSubmenuId
        }
    }
}

// MARK: - Edit Item Sheet

struct EditItemSheetView: View {
    let item: DesignerItem
    @ObservedObject var viewModel: MenuDesignerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var customTitle: String = ""
    @State private var customIcon: String = ""

    private let popularSymbols = [
        "terminal", "chevron.left.forwardslash.chevron.right", "doc.text", "curlybraces",
        "link", "bolt", "star", "gearshape", "folder", "doc.badge.plus", "trash", "tag"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(appLocalized: "Edit Menu Item")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                // Title Section
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(appLocalized: "Title Override")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !customTitle.isEmpty {
                            Button(AppLocalization.localized("Reset")) {
                                customTitle = ""
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }

                    TextField(item.title, text: $customTitle)
                        .textFieldStyle(.roundedBorder)
                    Text(String(format: AppLocalization.localized("Default: %@"), item.title))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Icon Section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(appLocalized: "Icon Override (SF Symbol)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !customIcon.isEmpty {
                            Button(AppLocalization.localized("Reset")) {
                                customIcon = ""
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }

                    HStack {
                        let activeIcon = customIcon.isEmpty ? item.icon : customIcon
                        Image(systemName: activeIcon.isEmpty ? "gear" : activeIcon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField(item.icon.isEmpty ? "SF Symbol Name" : item.icon, text: $customIcon)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Popular symbols
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(popularSymbols, id: \.self) { sym in
                            Button {
                                customIcon = sym
                            } label: {
                                Image(systemName: sym)
                                    .font(.system(size: 13))
                                    .frame(width: 28, height: 28)
                                    .background(customIcon == sym ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(AppLocalization.localized("Save")) {
                    viewModel.updateCustomization(
                        id: item.id,
                        customTitle: customTitle,
                        customIcon: customIcon
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380, height: 340)
        .onAppear {
            customTitle = item.customTitle ?? ""
            customIcon = item.customIcon ?? ""
        }
    }
}

// MARK: - Raw JSON Sheet

struct RawJsonSheetView: View {
    @ObservedObject var viewModel: MenuDesignerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("custom_menu.json", systemImage: "curlybraces")
                    .font(.headline)
                Spacer()
                Button(AppLocalization.localized("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text(appLocalized: "This is the JSON generated from your visual menu layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                Text(viewModel.jsonRepresentation())
                    .font(.system(size: 11, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.jsonRepresentation(), forType: .string)
                } label: {
                    Label(AppLocalization.localized("Copy to Clipboard"), systemImage: "doc.on.doc")
                }

                Spacer()
            }
        }
        .padding()
        .frame(width: 480, height: 420)
    }
}

// MARK: - Preset Card Component

struct PresetCardView: View {
    let preset: MenuPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Top header: Icon + Title + Selection Indicator
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? preset.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? preset.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                        )

                    Text(preset.title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(preset.accentColor)
                    }
                }

                Text(preset.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 28, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? preset.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? preset.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheetView: View {
    @ObservedObject var viewModel: MenuDesignerViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: MenuPreset = .general

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 5) {
                Text(AppLocalization.localized("Select Menu Preset"))
                    .font(.system(size: 16, weight: .bold))

                Text(AppLocalization.localized("Choose a curated right-click menu tailored to your workflow. You can customize it further at any time."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 18)
            .padding(.horizontal, 20)

            // Preset Cards Gallery (横向三列卡片)
            HStack(spacing: 10) {
                ForEach(MenuPreset.allCases) { preset in
                    PresetCardView(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        onSelect: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedPreset = preset
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

            // 预设内容结构预览区域（简洁清晰列表，无过度嵌套）
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.localized("Included Actions"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(selectedPreset.previewSections.enumerated()), id: \.offset) { index, sec in
                        if index > 0 {
                            Divider().opacity(0.4)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: sec.icon)
                                .font(.system(size: 12.5))
                                .foregroundStyle(selectedPreset.accentColor)
                                .frame(width: 18)

                            Text(sec.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)

                            Text("·")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)

                            Text(sec.details)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            // 底部提示小字
            Text(AppLocalization.localized("Applying a preset replaces the menu layout. Your previous layout is automatically backed up and can be restored at any time."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Divider().opacity(0.4)

            // Footer Buttons
            HStack(alignment: .center) {
                Button(AppLocalization.localized("Cancel"), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                if viewModel.hasBackup {
                    Button {
                        if viewModel.restoreBackup(using: appState) {
                            dismiss()
                        }
                    } label: {
                        Label(AppLocalization.localized("Restore Previous Configuration"), systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    selectedPreset.apply(to: appState, in: viewModel)
                    dismiss()
                } label: {
                    Text(String(format: AppLocalization.localized("Apply \"%@\" Preset"), selectedPreset.title))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 620, height: 460)
    }
}
