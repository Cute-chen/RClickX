//
//  DesignerItem.swift
//  RClick
//
//  Visual Menu Designer Tree Data Model and Conversions
//

import AppKit
import Foundation
import SwiftUI

/// Identifiable tree item representation for the Visual Menu Designer.
struct DesignerItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: MenuNode.Kind
    var itemType: MenuItemType?
    var referenceId: String?
    var title: String
    var icon: String
    var customTitle: String?
    var customIcon: String?
    var appURL: URL?
    var children: [DesignerItem] = []
    var isExpanded: Bool = true
    var isEnabledInSettings: Bool = true

    var displayTitle: String {
        if let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return title
    }

    var displayIcon: String {
        if let custom = customIcon?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return icon
    }

    var typeBadge: String {
        switch kind {
        case .separator:
            return AppLocalization.localized("Separator")
        case .submenu:
            return AppLocalization.localized("Submenu")
        case .item:
            switch itemType {
            case .action:
                return AppLocalization.localized("Action")
            case .app:
                return AppLocalization.localized("App")
            case .newFile:
                return AppLocalization.localized("New File")
            case .commonDir:
                return AppLocalization.localized("Folder")
            case .none:
                return AppLocalization.localized("Item")
            }
        }
    }

    var typeBadgeColor: Color {
        switch kind {
        case .separator:
            return .secondary
        case .submenu:
            return .purple
        case .item:
            switch itemType {
            case .action:
                return .orange
            case .app:
                return .indigo
            case .newFile:
                return .green
            case .commonDir:
                return .teal
            case .none:
                return .blue
            }
        }
    }
}

// MARK: - MenuNode Conversions

extension DesignerItem {
    /// Recursively converts a MenuNode into a DesignerItem, resolving display metadata from AppState.
    @MainActor
    static func from(node: MenuNode, state: AppState) -> DesignerItem {
        switch node.type {
        case .separator:
            return DesignerItem(
                kind: .separator,
                title: AppLocalization.localized("Separator"),
                icon: "minus"
            )

        case .submenu:
            let rawTitle = node.title ?? AppLocalization.localized("Submenu")
            let rawIcon = node.icon ?? "folder"
            let kids = (node.children ?? []).map { DesignerItem.from(node: $0, state: state) }
            return DesignerItem(
                kind: .submenu,
                title: rawTitle,
                icon: rawIcon,
                customTitle: node.title,
                customIcon: node.icon,
                children: kids
            )

        case .item:
            let itemType = node.itemType
            let refId = node.id ?? node.appPath ?? node.fileExtension
            var resolvedTitle = ""
            var resolvedIcon = "gear"
            var appUrl: URL?
            var isEnabled = true

            if let itemType = itemType, let refId = refId {
                switch itemType {
                case .action:
                    if let act = state.actions.first(where: { $0.id == refId }) {
                        resolvedTitle = act.displayName
                        resolvedIcon = act.icon
                        isEnabled = act.enabled
                    }
                case .app:
                    if let app = state.apps.first(where: { $0.id == refId || $0.url.path == refId }) {
                        resolvedTitle = app.name
                        resolvedIcon = "app"
                        appUrl = app.url
                    }
                case .newFile:
                    if let nf = state.newFiles.first(where: { $0.id == refId || $0.ext == refId }) {
                        resolvedTitle = nf.displayName
                        resolvedIcon = nf.icon
                        isEnabled = nf.enabled
                    }
                case .commonDir:
                    if let cd = state.cdirs.first(where: { $0.id == refId }) {
                        resolvedTitle = cd.displayName
                        resolvedIcon = cd.icon
                        isEnabled = state.showCommonDirs
                    }
                }
            }

            if resolvedTitle.isEmpty {
                resolvedTitle = node.title ?? refId ?? AppLocalization.localized("Item")
            }

            return DesignerItem(
                kind: .item,
                itemType: itemType,
                referenceId: refId,
                title: resolvedTitle,
                icon: resolvedIcon,
                customTitle: node.title,
                customIcon: node.icon,
                appURL: appUrl,
                isEnabledInSettings: isEnabled
            )
        }
    }

    /// Converts back to a MenuNode for JSON serialization and MenuService application.
    func toMenuNode() -> MenuNode {
        switch kind {
        case .separator:
            return MenuNode(type: .separator)

        case .submenu:
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = trimmedTitle.isEmpty ? AppLocalization.localized("Submenu") : trimmedTitle
            let finalIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            return MenuNode(
                type: .submenu,
                title: finalTitle,
                icon: finalIcon.isEmpty ? nil : finalIcon,
                children: children.map { $0.toMenuNode() }
            )

        case .item:
            let overrideTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalOverrideTitle = (overrideTitle?.isEmpty ?? true) ? nil : overrideTitle
            let overrideIcon = customIcon?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalOverrideIcon = (overrideIcon?.isEmpty ?? true) ? nil : overrideIcon

            return MenuNode(
                type: .item,
                title: finalOverrideTitle,
                icon: finalOverrideIcon,
                itemType: itemType,
                id: referenceId
            )
        }
    }

    /// Creates standard initial items based on current AppState configuration.
    @MainActor
    static func makeDefaultItems(state: AppState) -> [DesignerItem] {
        var items: [DesignerItem] = []

        // Top Apps
        for app in state.apps {
            items.append(DesignerItem(
                kind: .item,
                itemType: .app,
                referenceId: app.id,
                title: app.name,
                icon: "app",
                appURL: app.url
            ))
        }

        let enabledActions = state.actions.filter(\.enabled)
        let enabledNewFiles = state.newFiles.filter(\.enabled)

        if !items.isEmpty && (!enabledActions.isEmpty || !enabledNewFiles.isEmpty) {
            items.append(DesignerItem(
                kind: .separator,
                title: AppLocalization.localized("Separator"),
                icon: "minus"
            ))
        }

        // Actions: if folded, put in submenu; else top-level
        if !enabledActions.isEmpty {
            if state.foldActionsMenu {
                let actionKids = enabledActions.map { act in
                    DesignerItem(
                        kind: .item,
                        itemType: .action,
                        referenceId: act.id,
                        title: act.displayName,
                        icon: act.icon
                    )
                }
                items.append(DesignerItem(
                    kind: .submenu,
                    title: AppLocalization.localized("Actions"),
                    icon: "bolt.square",
                    children: actionKids
                ))
            } else {
                for act in enabledActions {
                    items.append(DesignerItem(
                        kind: .item,
                        itemType: .action,
                        referenceId: act.id,
                        title: act.displayName,
                        icon: act.icon
                    ))
                }
            }
        }

        // New File submenu
        if !enabledNewFiles.isEmpty {
            let fileKids = enabledNewFiles.map { nf in
                DesignerItem(
                    kind: .item,
                    itemType: .newFile,
                    referenceId: nf.id,
                    title: nf.displayName,
                    icon: nf.icon
                )
            }
            items.append(DesignerItem(
                kind: .submenu,
                title: AppLocalization.localized("New File"),
                icon: "doc.badge.plus",
                children: fileKids
            ))
        }

        // Common Dirs submenu
        if state.showCommonDirs && !state.cdirs.isEmpty {
            let dirKids = state.cdirs.map { cd in
                DesignerItem(
                    kind: .item,
                    itemType: .commonDir,
                    referenceId: cd.id,
                    title: cd.displayName,
                    icon: cd.icon
                )
            }
            items.append(DesignerItem(
                kind: .submenu,
                title: AppLocalization.localized("Common Dirs"),
                icon: "folder",
                children: dirKids
            ))
        }

        return items
    }
}

// MARK: - Menu Presets for Personas

enum MenuPreset: String, CaseIterable, Identifiable {
    case general = "General"
    case developer = "Developer"
    case office = "Office"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: AppLocalization.localized("General")
        case .developer: AppLocalization.localized("Developer")
        case .office: AppLocalization.localized("Office")
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            AppLocalization.localized("Clean and essential tools for everyday Mac usage.")
        case .developer:
            AppLocalization.localized("Terminal shortcuts, code templates, and developer toolchain.")
        case .office:
            AppLocalization.localized("Complete Office document creation and file sharing workflows.")
        }
    }

    var icon: String {
        switch self {
        case .general: "sparkles"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .office: "briefcase.fill"
        }
    }

    var badgeText: String {
        switch self {
        case .general: AppLocalization.localized("Everyday")
        case .developer: AppLocalization.localized("Tech & Code")
        case .office: AppLocalization.localized("Productivity")
        }
    }

    var accentColor: Color {
        switch self {
        case .general: .blue
        case .developer: .orange
        case .office: .green
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .general: [.blue, .purple]
        case .developer: [.orange, .red]
        case .office: [.green, .teal]
        }
    }

    var featureTags: [String] {
        switch self {
        case .general:
            [
                AppLocalization.localized(".txt / .md"),
                AppLocalization.localized("Copy Path"),
                AppLocalization.localized("Toggle Hidden Files"),
                AppLocalization.localized("Empty Trash")
            ]
        case .developer:
            [
                AppLocalization.localized("Terminal & VS Code"),
                AppLocalization.localized(".sh / .py / .json"),
                AppLocalization.localized("SHA256 Hash"),
                AppLocalization.localized("POSIX Path")
            ]
        case .office:
            [
                AppLocalization.localized(".docx / .xlsx / .pptx"),
                AppLocalization.localized("AirDrop"),
                AppLocalization.localized("Work Folders"),
                AppLocalization.localized("Copy Path")
            ]
        }
    }

    var previewSections: [(icon: String, title: String, details: String)] {
        switch self {
        case .general:
            return [
                ("doc.badge.plus", AppLocalization.localized("New File"), "TXT, Markdown, Word (.docx), Excel (.xlsx), PPT (.pptx)"),
                ("bolt.circle", AppLocalization.localized("Actions"), AppLocalization.localized("Copy Path, Toggle Hidden Files, Empty Trash")),
                ("folder", AppLocalization.localized("Common Dirs"), AppLocalization.localized("Quick access to system and favorite folders"))
            ]
        case .developer:
            return [
                ("terminal", AppLocalization.localized("Terminal & IDE"), AppLocalization.localized("Open Terminal & VS Code")),
                ("doc.badge.plus", AppLocalization.localized("New File"), "Shell (.sh), Python (.py), JSON, Markdown, TXT"),
                ("wrench.and.screwdriver", AppLocalization.localized("Developer Tools"), AppLocalization.localized("POSIX Path, SHA256 Hash, Git Status, Hidden Files")),
                ("folder", AppLocalization.localized("Common Dirs"), AppLocalization.localized("Quick folder shortcuts"))
            ]
        case .office:
            return [
                ("doc.badge.plus", AppLocalization.localized("New File"), "Word (.docx), Excel (.xlsx), PPT (.pptx), Markdown, TXT"),
                ("paperplane", AppLocalization.localized("Collaboration & Sharing"), AppLocalization.localized("AirDrop, Copy Path, Empty Trash")),
                ("folder.badge.gearshape", AppLocalization.localized("Work Folders"), AppLocalization.localized("Quick access to workspace directories"))
            ]
        }
    }

    private static func normalizeExt(_ ext: String) -> String {
        ext.trimmingCharacters(in: CharacterSet(charactersIn: ". \t")).lowercased()
    }

    /// Configures state items (newFiles, actions, cdirs) to match the preset's intent.
    @MainActor
    func configureState(_ state: AppState) {
        switch self {
        case .general:
            let targetExts: Set<String> = ["txt", "md", "docx", "xlsx", "pptx"]
            for i in 0..<state.newFiles.count {
                let ext = Self.normalizeExt(state.newFiles[i].ext)
                let id = state.newFiles[i].id.lowercased()
                state.newFiles[i].enabled = targetExts.contains(ext) || targetExts.contains(id)
            }
            for i in 0..<state.actions.count {
                let id = state.actions[i].id
                state.actions[i].enabled = (id == "copy-path" || id == "copy-name" || id == "empty-trash" || id == "hide-files")
            }
            state.showCommonDirs = true

        case .developer:
            // Ensure .sh and .py exist in state.newFiles
            if !state.newFiles.contains(where: { Self.normalizeExt($0.ext) == "sh" || $0.id == "sh" }) {
                state.newFiles.append(NewFile(ext: ".sh", name: "Shell Script", idx: state.newFiles.count, icon: "terminal", id: "sh"))
            }
            if !state.newFiles.contains(where: { Self.normalizeExt($0.ext) == "py" || $0.id == "py" }) {
                state.newFiles.append(NewFile(ext: ".py", name: "Python Script", idx: state.newFiles.count, icon: "chevron.left.forwardslash.chevron.right", id: "py"))
            }
            let targetExts: Set<String> = ["sh", "py", "json", "md", "txt"]
            for i in 0..<state.newFiles.count {
                let ext = Self.normalizeExt(state.newFiles[i].ext)
                let id = state.newFiles[i].id.lowercased()
                state.newFiles[i].enabled = targetExts.contains(ext) || targetExts.contains(id)
            }
            for i in 0..<state.actions.count {
                let id = state.actions[i].id
                state.actions[i].enabled = (id == "terminal" || id == "vscode" || id == "copy-path" || id == "sha256" || id == "hide-files")
            }
            // Add Git Status script if not already present
            if !state.actions.contains(where: { $0.id == "git-status-script" }) {
                state.addAction(RCAction(
                    id: "git-status-script",
                    name: AppLocalization.localized("Git Status"),
                    enabled: true,
                    idx: state.actions.count,
                    icon: "arrow.triangle.branch",
                    script: "cd \"$DIR\" && git status",
                    runInBackground: false
                ))
            }
            state.showCommonDirs = true

        case .office:
            let targetExts: Set<String> = ["docx", "xlsx", "pptx", "md", "txt"]
            for i in 0..<state.newFiles.count {
                let ext = Self.normalizeExt(state.newFiles[i].ext)
                let id = state.newFiles[i].id.lowercased()
                state.newFiles[i].enabled = targetExts.contains(ext) || targetExts.contains(id)
            }
            for i in 0..<state.actions.count {
                let id = state.actions[i].id
                state.actions[i].enabled = (id == "airdrop" || id == "copy-path" || id == "copy-name" || id == "empty-trash")
            }
            state.showCommonDirs = true
        }
    }

    /// Generates the tailored DesignerItem hierarchy for this preset.
    @MainActor
    func makeItems(state: AppState) -> [DesignerItem] {
        var items: [DesignerItem] = []

        // Helper to get enabled new files with robust fallback
        func makeNewFileChildren() -> [DesignerItem] {
            var kids = state.newFiles.filter { $0.enabled }.map { nf in
                DesignerItem(kind: .item, itemType: .newFile, referenceId: nf.id, title: nf.displayName, icon: nf.icon)
            }
            if kids.isEmpty {
                kids = state.newFiles.prefix(4).map { nf in
                    DesignerItem(kind: .item, itemType: .newFile, referenceId: nf.id, title: nf.displayName, icon: nf.icon)
                }
            }
            return kids
        }

        switch self {
        case .general:
            // 1. New File Submenu (始终保留新建文件)
            let fileKids = makeNewFileChildren()
            if !fileKids.isEmpty {
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("New File"), icon: "doc.badge.plus", children: fileKids))
            }

            // 2. High-frequency actions
            if let act = state.actions.first(where: { $0.id == "copy-path" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "copy-name" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }

            items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))

            if let act = state.actions.first(where: { $0.id == "hide-files" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "empty-trash" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }

            // 3. Common Dirs Submenu
            let dirKids = state.cdirs.map { cd in
                DesignerItem(kind: .item, itemType: .commonDir, referenceId: cd.id, title: cd.displayName, icon: cd.icon)
            }
            if !dirKids.isEmpty {
                items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("Common Dirs"), icon: "folder", children: dirKids))
            }

        case .developer:
            // 1. Terminal & VS Code top-level
            if let act = state.actions.first(where: { $0.id == "terminal" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "vscode" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }

            items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))

            // 2. New File Submenu (代码与配置文件模板)
            let fileKids = makeNewFileChildren()
            if !fileKids.isEmpty {
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("New File"), icon: "doc.badge.plus", children: fileKids))
            }

            // 3. Developer Tools Submenu
            var devTools: [DesignerItem] = []
            if let act = state.actions.first(where: { $0.id == "copy-path" }) {
                devTools.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "sha256" }) {
                devTools.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "git-status-script" }) {
                devTools.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "hide-files" }) {
                devTools.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if !devTools.isEmpty {
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("Developer Tools"), icon: "wrench.and.screwdriver", children: devTools))
            }

            // 4. Common Dirs
            let dirKids = state.cdirs.map { cd in
                DesignerItem(kind: .item, itemType: .commonDir, referenceId: cd.id, title: cd.displayName, icon: cd.icon)
            }
            if !dirKids.isEmpty {
                items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("Common Dirs"), icon: "folder", children: dirKids))
            }

        case .office:
            // 1. New File Submenu (Office 文档与报告模板)
            let fileKids = makeNewFileChildren()
            if !fileKids.isEmpty {
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("New File"), icon: "doc.badge.plus", children: fileKids))
            }

            items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))

            // 2. Share & Action
            if let act = state.actions.first(where: { $0.id == "airdrop" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "copy-path" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }
            if let act = state.actions.first(where: { $0.id == "empty-trash" }) {
                items.append(DesignerItem(kind: .item, itemType: .action, referenceId: act.id, title: act.displayName, icon: act.icon))
            }

            // 3. Work Folders Submenu
            let dirKids = state.cdirs.map { cd in
                DesignerItem(kind: .item, itemType: .commonDir, referenceId: cd.id, title: cd.displayName, icon: cd.icon)
            }
            if !dirKids.isEmpty {
                items.append(DesignerItem(kind: .separator, title: AppLocalization.localized("Separator"), icon: "minus"))
                items.append(DesignerItem(kind: .submenu, title: AppLocalization.localized("Work Folders"), icon: "folder.badge.gearshape", children: dirKids))
            }
        }

        return items
    }

    /// Applies this preset to the app state, saves to custom menu and pushes to runtime.
    @MainActor
    func apply(to state: AppState, in viewModel: MenuDesignerViewModel? = nil) {
        MenuService.backupCurrentCustomMenu()
        configureState(state)
        let items = makeItems(state: state)

        if let vm = viewModel {
            vm.items = items
            vm.saveAndApply(using: state)
        } else {
            guard let url = MenuService.defaultCustomMenuURL else { return }
            do {
                let nodes = items.map { $0.toMenuNode() }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(nodes)
                try data.write(to: url, options: .atomic)
                try RCRuntime.shared.menuService.applyCustomMenu(at: url, config: MenuService.makePayload(from: state))
            } catch {
                print("Failed to apply preset: \(error)")
            }
        }

        state.sync()
        Messager.shared.sendRunningNotification()
        NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
    }
}
