//
//  MenuDesignerTests.swift
//  RClickTests
//
//  Unit tests for the Visual Menu Designer models, tree operations, and conversions.
//

import AppKit
import Foundation
import Testing
@testable import RClick

@MainActor
struct MenuDesignerTests {

    private func makeTestState() -> AppState {
        let state = AppState(inExt: true)
        state.apps = [
            OpenWithApp(id: "app-vscode", appURL: URL(fileURLWithPath: "/Applications/Visual Studio Code.app")),
            OpenWithApp(id: "app-warp", appURL: URL(fileURLWithPath: "/Applications/Warp.app"))
        ]
        state.actions = [
            RCAction(id: "copy-path", name: "Copy Path", enabled: true, idx: 0, icon: "doc.on.doc"),
            RCAction(id: "calc-hash", name: "Calculate Hash", enabled: false, idx: 1, icon: "number")
        ]
        state.newFiles = [
            NewFile(ext: ".txt", name: "Text File", enabled: true, idx: 0, icon: "doc.text", id: "new-txt")
        ]
        state.cdirs = [
            CommonDir(id: "dir-docs", name: "Documents", url: URL(fileURLWithPath: "/Users/test/Documents"), icon: "folder")
        ]
        state.showCommonDirs = true
        state.foldActionsMenu = false
        return state
    }

    @Test func roundTripConvertsMenuNodeToDesignerItemAndBack() {
        let state = makeTestState()

        // 1. Separator
        let sepNode = MenuNode(type: .separator)
        let sepItem = DesignerItem.from(node: sepNode, state: state)
        #expect(sepItem.kind == .separator)
        #expect(sepItem.toMenuNode() == sepNode)

        // 2. Leaf Item
        let leafNode = MenuNode(
            type: .item,
            title: "Custom Title",
            icon: "star.fill",
            itemType: .action,
            id: "copy-path"
        )
        let leafItem = DesignerItem.from(node: leafNode, state: state)
        #expect(leafItem.kind == .item)
        #expect(leafItem.referenceId == "copy-path")
        #expect(leafItem.displayTitle == "Custom Title")
        #expect(leafItem.displayIcon == "star.fill")
        #expect(leafItem.toMenuNode() == leafNode)

        // 3. Submenu with children
        let subNode = MenuNode(
            type: .submenu,
            title: "Tools",
            icon: "wrench",
            children: [leafNode, sepNode]
        )
        let subItem = DesignerItem.from(node: subNode, state: state)
        #expect(subItem.kind == .submenu)
        #expect(subItem.children.count == 2)
        #expect(subItem.children[0].referenceId == "copy-path")
        #expect(subItem.children[1].kind == .separator)
        #expect(subItem.toMenuNode() == subNode)
    }

    @Test func makeDefaultItemsBuildsRichStartingTree() {
        let state = makeTestState()
        let items = DesignerItem.makeDefaultItems(state: state)

        #expect(!items.isEmpty)
        // Should contain apps
        #expect(items.contains(where: { $0.kind == .item && $0.itemType == .app }))
        // Should contain separator
        #expect(items.contains(where: { $0.kind == .separator }))
        // Should contain enabled action
        #expect(items.contains(where: { $0.kind == .item && $0.itemType == .action }))
        // Should contain New File submenu
        #expect(items.contains(where: { $0.kind == .submenu && $0.icon == "doc.badge.plus" }))
        // Should contain Common Dirs submenu
        #expect(items.contains(where: { $0.kind == .submenu && $0.icon == "folder" }))
    }

    @Test func viewModelTreeOperationsAddReorderAndRemoveItems() {
        let state = makeTestState()
        let vm = MenuDesignerViewModel()
        vm.load(using: state)

        let initialCount = vm.items.count

        // Add a new top-level submenu
        vm.addSubmenu(title: "My Custom Group", icon: "folder")
        #expect(vm.items.count == initialCount + 1)
        let createdSubmenu = vm.items.last!
        #expect(createdSubmenu.displayTitle == "My Custom Group")

        // Add an item into that submenu
        vm.addItem(
            type: .action,
            referenceId: "copy-path",
            title: "Copy Path",
            icon: "doc.on.doc",
            toSubmenu: createdSubmenu.id
        )

        let reloadedSubmenu = vm.items.first(where: { $0.id == createdSubmenu.id })!
        #expect(reloadedSubmenu.children.count == 1)
        #expect(reloadedSubmenu.children[0].referenceId == "copy-path")

        // Move the submenu up
        let lastIndex = vm.items.count - 1
        vm.moveUp(id: createdSubmenu.id)
        #expect(vm.items[lastIndex - 1].id == createdSubmenu.id)

        // Delete the submenu
        vm.deleteItem(id: createdSubmenu.id)
        #expect(!vm.items.contains(where: { $0.id == createdSubmenu.id }))
    }

    @Test func viewModelMoveBetweenSubmenuAndTopLevel() {
        let vm = MenuDesignerViewModel()
        vm.items = []

        vm.addSubmenu(title: "Group A", icon: "folder")
        let groupAId = vm.items[0].id

        vm.addItem(
            type: .action,
            referenceId: "test-act",
            title: "Action Item",
            icon: "gear",
            toSubmenu: nil
        )
        let itemAId = vm.items[1].id

        // Move item into Group A
        vm.moveToSubmenu(id: itemAId, targetSubmenuId: groupAId)
        #expect(vm.items.count == 1) // only group A left at top level
        #expect(vm.items[0].children.count == 1)
        #expect(vm.items[0].children[0].id == itemAId)

        // Move item back to top level
        vm.moveToTopLevel(id: itemAId)
        #expect(vm.items.count == 2)
        #expect(vm.items[0].children.isEmpty)
        #expect(vm.items[1].id == itemAId)
    }

    @Test func itemCustomizationUpdatesDisplayAndJSON() {
        let vm = MenuDesignerViewModel()
        vm.items = []

        vm.addItem(
            type: .action,
            referenceId: "copy-path",
            title: "Copy Path",
            icon: "doc.on.doc"
        )
        let itemId = vm.items[0].id

        vm.updateCustomization(id: itemId, customTitle: "快捷复制路径", customIcon: "link.circle.fill")
        #expect(vm.items[0].displayTitle == "快捷复制路径")
        #expect(vm.items[0].displayIcon == "link.circle.fill")

        let json = vm.jsonRepresentation()
        #expect(json.contains("快捷复制路径"))
        #expect(json.contains("link.circle.fill"))
    }

    @Test func menuPresetCasesAndProperties() {
        let presets = MenuPreset.allCases
        #expect(presets.count == 3)
        #expect(presets.contains(.general))
        #expect(presets.contains(.developer))
        #expect(presets.contains(.office))

        for preset in presets {
            #expect(!preset.title.isEmpty)
            #expect(!preset.badgeText.isEmpty)
            #expect(!preset.subtitle.isEmpty)
            #expect(!preset.icon.isEmpty)
            #expect(!preset.featureTags.isEmpty)
            #expect(preset.gradientColors.count == 2)
        }
    }

    @Test func menuPresetConfigureStateAndMakeItems() {
        let state = makeTestState()

        // 1. General preset
        let generalPreset = MenuPreset.general
        generalPreset.configureState(state)
        let generalItems = generalPreset.makeItems(state: state)
        #expect(!generalItems.isEmpty)
        #expect(generalItems.contains(where: { $0.displayTitle == AppLocalization.localized("New File") }))
        let generalNodes = generalItems.map { $0.toMenuNode() }
        #expect(!generalNodes.isEmpty)

        // 2. Developer preset
        let devPreset = MenuPreset.developer
        devPreset.configureState(state)
        let devItems = devPreset.makeItems(state: state)
        #expect(!devItems.isEmpty)
        #expect(devItems.contains(where: { $0.displayTitle == AppLocalization.localized("New File") }))
        #expect(devItems.contains(where: { $0.displayTitle == AppLocalization.localized("Developer Tools") || $0.referenceId == "terminal" }))

        // 3. Office preset
        let officePreset = MenuPreset.office
        officePreset.configureState(state)
        let officeItems = officePreset.makeItems(state: state)
        #expect(!officeItems.isEmpty)
        #expect(officeItems.contains(where: { $0.displayTitle == AppLocalization.localized("New File") }))
        #expect(officeItems.contains(where: { $0.referenceId == "airdrop" || $0.referenceId == "copy-path" }))
    }

    @Test func menuPresetApplyToViewModel() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempMenuURL = tempDir.appendingPathComponent("custom_menu.json")
        MenuService.customMenuURLOverride = tempMenuURL
        defer {
            MenuService.customMenuURLOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        let state = makeTestState()
        let vm = MenuDesignerViewModel()

        MenuPreset.developer.apply(to: state, in: vm)
        #expect(!vm.items.isEmpty)
        let json = vm.jsonRepresentation()
        #expect(!json.isEmpty)
        #expect(json.starts(with: "["))
    }

    @Test func menuBackupAndRestoreFlow() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempMenuURL = tempDir.appendingPathComponent("custom_menu.json")
        MenuService.customMenuURLOverride = tempMenuURL
        defer {
            MenuService.customMenuURLOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        let state = makeTestState()
        let vm = MenuDesignerViewModel()

        // 1. Initial items (general)
        MenuPreset.general.apply(to: state, in: vm)
        let initialItemsCount = vm.items.count

        // 2. Switch to developer (triggers auto backup)
        MenuPreset.developer.apply(to: state, in: vm)
        #expect(vm.hasBackup)

        // 3. Restore backup
        let restored = vm.restoreBackup(using: state)
        #expect(restored)
        #expect(vm.items.count == initialItemsCount)
    }

    @Test func restoringBackupReenablesFileTypesDisabledByTheNextPreset() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempMenuURL = tempDir.appendingPathComponent("custom_menu.json")
        MenuService.customMenuURLOverride = tempMenuURL
        defer {
            MenuService.customMenuURLOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        let state = makeTestState()
        state.newFiles = [
            NewFile(ext: ".json", name: "JSON", enabled: true, idx: 0, id: "json"),
            NewFile(ext: ".docx", name: "DOCX", enabled: true, idx: 1, id: "docx")
        ]
        let vm = MenuDesignerViewModel()
        vm.items = [DesignerItem(
            kind: .submenu,
            title: "New File",
            icon: "doc.badge.plus",
            children: [
                DesignerItem(kind: .item, itemType: .newFile, referenceId: "json", title: "JSON", icon: "curlybraces"),
                DesignerItem(kind: .item, itemType: .newFile, referenceId: "docx", title: "DOCX", icon: "doc.richtext.fill")
            ]
        )]
        vm.saveAndApply(using: state)

        // Developer preset disables DOCX; the backup still contains both file types.
        MenuPreset.developer.apply(to: state, in: vm)
        #expect(state.newFiles.first(where: { $0.id == "json" })?.enabled == true)
        #expect(state.newFiles.first(where: { $0.id == "docx" })?.enabled == false)

        #expect(vm.restoreBackup(using: state))
        #expect(state.newFiles.first(where: { $0.id == "json" })?.enabled == true)
        #expect(state.newFiles.first(where: { $0.id == "docx" })?.enabled == true)
        #expect(vm.items.flatMap(\.children).map(\.referenceId) == ["json", "docx"])
    }
}
