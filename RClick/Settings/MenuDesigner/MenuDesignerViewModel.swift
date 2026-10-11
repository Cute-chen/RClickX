//
//  MenuDesignerViewModel.swift
//  RClick
//
//  State and Business Logic for the Visual Menu Designer
//

import AppKit
import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class MenuDesignerViewModel: ObservableObject {
    @AppLog(category: "MenuDesigner")
    private var logger

    @Published var items: [DesignerItem] = []
    @Published var selectedItemId: UUID?
    @Published var previewActiveSubmenuId: UUID?
    @Published var isPreviewDarkMode: Bool = false

    @Published var showAddItemSheet: Bool = false
    @Published var showAddSubmenuSheet: Bool = false
    @Published var itemToEdit: DesignerItem?
    @Published var showRawJsonSheet: Bool = false

    @Published var targetParentSubmenuId: UUID?
    @Published var saveToast: String?
    @Published var errorMessage: String?

    private var initialSnapshotJson: String = ""

    var hasUnsavedChanges: Bool {
        jsonRepresentation() != initialSnapshotJson
    }

    /// List of all submenus currently in the tree (for "Add to" or "Move into" options)
    var availableSubmenus: [(id: UUID, title: String)] {
        var result: [(UUID, String)] = []
        func collect(from list: [DesignerItem]) {
            for item in list where item.kind == .submenu {
                result.append((item.id, item.displayTitle))
                collect(from: item.children)
            }
        }
        collect(from: items)
        return result
    }

    /// Total count of all items across root and submenus (excluding separators)
    var totalItemCount: Int {
        func countItems(in list: [DesignerItem]) -> Int {
            list.reduce(0) { acc, item in
                let selfCount = item.kind == .separator ? 0 : 1
                return acc + selfCount + countItems(in: item.children)
            }
        }
        return countItems(in: items)
    }

    // MARK: - Loading & Initialization

    private var isLoaded = false

    func loadIfNeeded(using state: AppState) {
        guard !isLoaded else { return }
        load(using: state)
    }

    func load(using state: AppState) {
        isLoaded = true
        guard let url = MenuService.defaultCustomMenuURL else {
            items = DesignerItem.makeDefaultItems(state: state)
            takeSnapshot()
            return
        }

        if FileManager.default.fileExists(atPath: url.path) {
            let payload = MenuService.makePayload(from: state)
            do {
                if let loadedNodes = try CustomMenu.load(from: url, config: payload) {
                    items = loadedNodes.map { DesignerItem.from(node: $0, state: state) }
                    takeSnapshot()
                    return
                }
            } catch {
                logger.warning("Could not load custom menu: \(error.localizedDescription). Falling back to defaults.")
            }
        }

        // Default layout
        items = DesignerItem.makeDefaultItems(state: state)
        takeSnapshot()
    }

    private func takeSnapshot() {
        initialSnapshotJson = jsonRepresentation()
    }

    // MARK: - Tree Modifications

    func addItem(
        type: MenuItemType,
        referenceId: String,
        title: String,
        icon: String,
        appURL: URL? = nil,
        toSubmenu parentId: UUID? = nil
    ) {
        let newItem = DesignerItem(
            kind: .item,
            itemType: type,
            referenceId: referenceId,
            title: title,
            icon: icon,
            appURL: appURL
        )
        insert(newItem, intoSubmenu: parentId ?? targetParentSubmenuId)
    }

    func addSubmenu(title: String, icon: String, toSubmenu parentId: UUID? = nil) {
        let newSubmenu = DesignerItem(
            kind: .submenu,
            title: title,
            icon: icon.isEmpty ? "folder" : icon,
            children: []
        )
        insert(newSubmenu, intoSubmenu: parentId ?? targetParentSubmenuId)
    }

    func addSeparator(toSubmenu parentId: UUID? = nil) {
        let separator = DesignerItem(
            kind: .separator,
            title: AppLocalization.localized("Separator"),
            icon: "minus"
        )
        insert(separator, intoSubmenu: parentId ?? targetParentSubmenuId)
    }

    private func insert(_ item: DesignerItem, intoSubmenu parentId: UUID?) {
        if let parentId = parentId {
            _ = updateNode(id: parentId, in: &items) { parent in
                parent.children.append(item)
                parent.isExpanded = true
            }
        } else {
            items.append(item)
        }
    }

    func deleteItem(id: UUID) {
        if previewActiveSubmenuId == id {
            previewActiveSubmenuId = nil
        }
        if selectedItemId == id {
            selectedItemId = nil
        }
        _ = removeNode(id: id, from: &items)
    }

    func moveUp(id: UUID) {
        _ = moveNode(id: id, direction: .up, in: &items)
    }

    func moveDown(id: UUID) {
        _ = moveNode(id: id, direction: .down, in: &items)
    }

    func toggleExpand(id: UUID) {
        _ = updateNode(id: id, in: &items) { node in
            node.isExpanded.toggle()
        }
    }

    func updateCustomization(id: UUID, customTitle: String?, customIcon: String?) {
        _ = updateNode(id: id, in: &items) { node in
            node.customTitle = (customTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : customTitle
            node.customIcon = (customIcon?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? nil : customIcon
        }
    }

    func moveToTopLevel(id: UUID) {
        guard let item = extractNode(id: id, from: &items) else { return }
        items.append(item)
    }

    func moveToSubmenu(id: UUID, targetSubmenuId: UUID) {
        guard id != targetSubmenuId else { return }
        guard let item = extractNode(id: id, from: &items) else { return }
        _ = updateNode(id: targetSubmenuId, in: &items) { target in
            target.children.append(item)
            target.isExpanded = true
        }
    }

    // MARK: - Save, Apply & Reset

    func saveAndApply(using state: AppState) {
        guard let url = MenuService.defaultCustomMenuURL else {
            errorMessage = AppLocalization.localized("The shared configuration folder is unavailable.")
            return
        }

        // Auto-heal referenced items in AppState so validation succeeds seamlessly
        autoHealAppState(using: state)

        do {
            let nodes = items.map { $0.toMenuNode() }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(nodes)

            try data.write(to: url, options: .atomic)

            try RCRuntime.shared.menuService.applyCustomMenu(at: url, config: MenuService.makePayload(from: state))
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
            Messager.shared.sendRunningNotification()

            takeSnapshot()
            saveToast = AppLocalization.localized("Applied Successfully")
            errorMessage = nil

            // Auto dismiss toast after 2.5 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self.saveToast = nil
            }
        } catch {
            logger.error("Failed to save and apply custom menu: \(error.localizedDescription)")
            errorMessage = CustomMenuDiagnostics.message(for: error)
        }
    }

    func restoreDefaultLayout(using state: AppState) {
        guard let url = MenuService.defaultCustomMenuURL else {
            errorMessage = AppLocalization.localized("The shared configuration folder is unavailable.")
            return
        }

        do {
            try MenuService.removeCustomMenu(at: url)
            RCRuntime.shared.menuService.discardAppliedCustomMenu()
            NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
            Messager.shared.sendRunningNotification()

            items = DesignerItem.makeDefaultItems(state: state)
            takeSnapshot()
            saveToast = AppLocalization.localized("Restored Default Layout")
            errorMessage = nil

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self.saveToast = nil
            }
        } catch {
            errorMessage = CustomMenuDiagnostics.message(for: error)
        }
    }

    /// Whether a backup snapshot of a previous menu layout exists.
    var hasBackup: Bool {
        guard let backupUrl = MenuService.defaultCustomMenuBackupURL else { return false }
        return FileManager.default.fileExists(atPath: backupUrl.path)
    }

    /// Restores the menu configuration saved before the last preset or reset was applied.
    @discardableResult
    func restoreBackup(using state: AppState) -> Bool {
        guard let backupUrl = MenuService.defaultCustomMenuBackupURL,
              FileManager.default.fileExists(atPath: backupUrl.path) else {
            return false
        }
        do {
            // Validate the backup against every configured item first. The current
            // preset may have disabled a file type that the backup references; using
            // the filtered payload here would fail before the auto-heal step below.
            let backupData = try Data(contentsOf: backupUrl)
            let rawNodes = try JSONDecoder().decode([MenuNode].self, from: backupData)
            let completePayload = MenuService.makePayload(from: state, includeDisabledItems: true)
            _ = try CustomMenu.decode(backupData, config: completePayload)

            autoHealAppState(for: rawNodes, using: state)

            let payload = MenuService.makePayload(from: state)
            let restoredNodes = try CustomMenu.decode(backupData, config: payload)
            items = restoredNodes.map { DesignerItem.from(node: $0, state: state) }
            saveAndApply(using: state)
            // Keep the newly enabled references after a restore. Otherwise the next
            // refresh would disable them again and invalidate the restored layout.
            state.sync()
            saveToast = AppLocalization.localized("Restored Previous Configuration")
            errorMessage = nil
            return true
        } catch {
            logger.error("Failed to restore backup: \(error)")
            errorMessage = CustomMenuDiagnostics.message(for: error)
        }
        return false
    }

    /// Automatically enables any actions or file types referenced in the custom menu.
    private func autoHealAppState(using state: AppState) {
        func scan(list: [DesignerItem]) {
            for item in list {
                if item.kind == .item, let type = item.itemType, let refId = item.referenceId {
                    switch type {
                    case .action:
                        if let index = state.actions.firstIndex(where: { $0.id == refId }), !state.actions[index].enabled {
                            state.actions[index].enabled = true
                        }
                    case .newFile:
                        if let index = state.newFiles.firstIndex(where: { $0.id == refId || $0.ext == refId }), !state.newFiles[index].enabled {
                            state.newFiles[index].enabled = true
                        }
                    case .commonDir:
                        if !state.showCommonDirs {
                            state.showCommonDirs = true
                        }
                    case .app:
                        break
                    }
                }
                scan(list: item.children)
            }
        }
        scan(list: items)
    }

    /// Enables references found in a raw backup before resolving it against the
    /// current (possibly preset-filtered) payload.
    private func autoHealAppState(for nodes: [MenuNode], using state: AppState) {
        func normalizeExtension(_ value: String) -> String {
            value.trimmingCharacters(in: CharacterSet(charactersIn: ". \t")).lowercased()
        }

        func scan(_ nodes: [MenuNode]) {
            for node in nodes {
                if node.type == .item, let itemType = node.itemType {
                    switch itemType {
                    case .action:
                        if let id = node.id,
                           let index = state.actions.firstIndex(where: { $0.id == id }) {
                            state.actions[index].enabled = true
                        }
                    case .newFile:
                        let reference = node.id ?? node.fileExtension
                        if let reference,
                           let index = state.newFiles.firstIndex(where: {
                               $0.id == reference || normalizeExtension($0.ext) == normalizeExtension(reference)
                           }) {
                            state.newFiles[index].enabled = true
                        }
                    case .commonDir:
                        if let id = node.id, state.cdirs.contains(where: { $0.id == id }) {
                            state.showCommonDirs = true
                        }
                    case .app:
                        break
                    }
                }
                if let children = node.children {
                    scan(children)
                }
            }
        }
        scan(nodes)
    }

    func jsonRepresentation() -> String {
        let nodes = items.map { $0.toMenuNode() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(nodes),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    // MARK: - Recursive Helpers

    private enum MoveDirection { case up, down }

    private func moveNode(id: UUID, direction: MoveDirection, in list: inout [DesignerItem]) -> Bool {
        if let idx = list.firstIndex(where: { $0.id == id }) {
            switch direction {
            case .up:
                if idx > 0 {
                    list.swapAt(idx, idx - 1)
                    return true
                }
            case .down:
                if idx < list.count - 1 {
                    list.swapAt(idx, idx + 1)
                    return true
                }
            }
            return false
        }

        for i in 0..<list.count {
            if list[i].kind == .submenu {
                if moveNode(id: id, direction: direction, in: &list[i].children) {
                    return true
                }
            }
        }
        return false
    }

    private func removeNode(id: UUID, from list: inout [DesignerItem]) -> Bool {
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list.remove(at: idx)
            return true
        }
        for i in 0..<list.count {
            if list[i].kind == .submenu {
                if removeNode(id: id, from: &list[i].children) {
                    return true
                }
            }
        }
        return false
    }

    private func extractNode(id: UUID, from list: inout [DesignerItem]) -> DesignerItem? {
        if let idx = list.firstIndex(where: { $0.id == id }) {
            return list.remove(at: idx)
        }
        for i in 0..<list.count {
            if list[i].kind == .submenu {
                if let found = extractNode(id: id, from: &list[i].children) {
                    return found
                }
            }
        }
        return nil
    }

    private func updateNode(id: UUID, in list: inout [DesignerItem], action: (inout DesignerItem) -> Void) -> Bool {
        if let idx = list.firstIndex(where: { $0.id == id }) {
            action(&list[idx])
            return true
        }
        for i in 0..<list.count {
            if list[i].kind == .submenu {
                if updateNode(id: id, in: &list[i].children, action: action) {
                    return true
                }
            }
        }
        return false
    }

    /// Removes any nodes in the menu tree that reference a specific item ID.
    func removeNodesReferencing(referenceId: String) {
        func removeIn(list: inout [DesignerItem]) {
            list.removeAll { $0.referenceId == referenceId }
            for i in 0..<list.count {
                if list[i].kind == .submenu {
                    removeIn(list: &list[i].children)
                }
            }
        }
        removeIn(list: &items)
    }
}
