//
//  ActionServiceTests.swift
//  RClickTests
//
//  ActionService 单测：用 mock 的 PermissionProviding / ActionStateProviding
//  验证"未授权 + 用户取消"时文件操作被跳过。
//

import Foundation
import AppKit
import SwiftData
import Testing
@testable import RClick

@MainActor
final class ActionServiceTests {

    @MainActor
    private final class MockPermission: PermissionProviding {
        var hasAccessResult = false
        var promptResult: URL?
        var saveCalls: [URL] = []

        func hasAccess(to url: URL) -> Bool { hasAccessResult }
        func promptForPermission(for url: URL) async -> URL? { promptResult }
        func saveBookmark(for url: URL) { saveCalls.append(url) }
    }

    @MainActor
    private final class MockState: ActionStateProviding {
        var apps: [OpenWithApp] = []
        var actions: [RCAction] = []
        var newFiles: [NewFile] = []
        var cdirs: [CommonDir] = []
        var showCommonDirs = false

        func getAppItem(rid: String) -> OpenWithApp? { apps.first(where: { $0.id == rid }) }
        func getActionItem(rid: String) -> RCAction? {
            actions.first(where: { $0.id == rid }) ?? RCAction.all.first(where: { $0.id == rid })
        }
        func getFileType(rid: String) -> NewFile? { newFiles.first(where: { $0.id == rid }) }
    }

    @Test func deleteIsSkippedWhenAuthorizationIsCancelled() async throws {
        // 准备临时文件
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dummy.txt")
        try Data("x".utf8).write(to: file)

        let permission = MockPermission()
        permission.hasAccessResult = false   // 未授权
        permission.promptResult = nil        // 用户取消授权
        let service = ActionService(state: MockState(), permission: permission)

        await service.deleteFoldorFile([file.path], "ctx-items")

        // 未授权且用户取消 → 文件应保留
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func deleteProceedsWhenAuthorizationGranted() async throws {
        // 准备临时文件
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dummy.txt")
        try Data("x".utf8).write(to: file)

        let permission = MockPermission()
        permission.hasAccessResult = false   // 未授权，但...
        permission.promptResult = file.deletingLastPathComponent()  // ...用户授权了目录
        let service = ActionService(state: MockState(), permission: permission)

        await service.deleteFoldorFile([file.path], "ctx-items")

        // 授权后应执行删除 → 文件被移除
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func appEntityPersistsOpensNewInstance() throws {
        // in-memory 容器，避免触碰真实 App Group 库
        let container = try ModelContainer(
            for: AppEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        var app = OpenWithApp(appURL: URL(fileURLWithPath: "/Applications/Safari.app"))
        app.opensNewInstance = true
        context.insert(AppEntity(from: app, sortOrder: 0))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AppEntity>())
        #expect(fetched.first?.opensNewInstance == true)
    }
    @Test func fileTemplateSurvivesSaveAndReload() throws {
        let container = try ModelContainer(
            for: AppEntity.self, ActionEntity.self, NewFileTypeEntity.self, CommonDirEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let service = ConfigService(modelContext: container.mainContext)
        var file = NewFile(ext: ".txt", name: "Template", idx: 0, id: "stable-template-id")
        file.template = URL(fileURLWithPath: "/tmp/template with spaces.txt")
        file.openApp = URL(fileURLWithPath: "/Applications/TextEdit.app")
        try service.save(AppConfigData(newFiles: [file]))

        for _ in 0..<2 {
            let loaded = try #require(service.load().newFiles.first)
            #expect(loaded.id == file.id)
            #expect(loaded.template == file.template)
            #expect(loaded.openApp == file.openApp)
            try service.save(AppConfigData(newFiles: [loaded]))
        }
    }

    @Test func copyPathAndCopyNameWriteToPasteboard() {
        let permission = MockPermission()
        let service = ActionService(state: MockState(), permission: permission)

        service.copyPath(["/Users/tester/Documents/file.txt"])
        #expect(NSPasteboard.general.string(forType: .string) == "/Users/tester/Documents/file.txt")

        service.copyName(["/Users/tester/Documents/file.txt", "/Users/tester/Downloads/archive.zip"])
        #expect(NSPasteboard.general.string(forType: .string) == "file.txt\narchive.zip")
    }

    @Test func createSymlinkCreatesValidLink() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-symlink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceFile = dir.appendingPathComponent("source.txt")
        try Data("source content".utf8).write(to: sourceFile)

        let permission = MockPermission()
        permission.hasAccessResult = true
        let service = ActionService(state: MockState(), permission: permission)

        await service.createSymlink([sourceFile.path])

        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let symlink = try #require(contents.first(where: { $0.lastPathComponent != "source.txt" }))
        let dest = try FileManager.default.destinationOfSymbolicLink(atPath: symlink.path)
        #expect(dest == sourceFile.path)
    }

    @Test func calculateHashComputesSha256AndMd5() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-hash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("sample.txt")
        try Data("hello".utf8).write(to: file)

        let permission = MockPermission()
        permission.hasAccessResult = true
        let service = ActionService(state: MockState(), permission: permission)

        await service.calculateHash([file.path], algorithm: .sha256)
        #expect(NSPasteboard.general.string(forType: .string) == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")

        await service.calculateHash([file.path], algorithm: .md5)
        #expect(NSPasteboard.general.string(forType: .string) == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test func actionHandlerDispatchesNewActions() async {
        let permission = MockPermission()
        let state = MockState()
        let service = ActionService(state: state, permission: permission)

        await service.actionHandler(rid: "copy-name", target: ["/Users/tester/Documents/readme.md"], trigger: "ctx-items")
        #expect(NSPasteboard.general.string(forType: .string) == "readme.md")
    }

    @Test func customScriptExecutesWithVariablesAndWritesToClipboard() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rclick-script-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let testFile = dir.appendingPathComponent("testdoc.txt")
        try Data("test content".utf8).write(to: testFile)

        let customAction = RCAction(
            id: "custom-echo",
            name: "Echo Test",
            enabled: true,
            idx: 99,
            icon: "terminal",
            script: "echo Result: $NAME in $DIR",
            runInBackground: true
        )

        let state = MockState()
        state.actions = [customAction]
        let service = ActionService(state: state, permission: MockPermission())

        await service.actionHandler(rid: customAction.id, target: [testFile.path], trigger: "ctx-items")

        let clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(clipboardContent.contains("Result: testdoc.txt in \(dir.path)"))
    }

    @Test func customActionEntityPersistsScriptFields() throws {
        let container = try ModelContainer(
            for: ActionEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let action = RCAction(
            id: "custom-script-id",
            name: "Test Script",
            enabled: true,
            idx: 0,
            icon: "terminal",
            script: "echo $PATH",
            runInBackground: true
        )

        context.insert(ActionEntity(from: action))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ActionEntity>())
        let saved = try #require(fetched.first)
        #expect(saved.id == "custom-script-id")
        #expect(saved.script == "echo $PATH")
        #expect(saved.runInBackground == true)
    }

}
