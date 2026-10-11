//
//  ActionService.swift
//  RClick
//
//  文件操作 / 动作执行服务。从原 AppDelegate 迁移而来，是主 app 的"动作执行层"。
//  依赖 AppState（只读状态）与 PermissionService（经协议注入，可 mock 单测）。
//  注意：第一版不过度拆分，用私有方法 + MARK 分组（FileActions / AppActions / FinderActions / SystemActions）。
//

import AppKit
import ApplicationServices
import CryptoKit
import Foundation
import os.log

@MainActor
final class ActionService {
    @AppLog(category: "ActionService")
    private var logger

    private let state: ActionStateProviding
    private let permission: PermissionProviding

    init(state: ActionStateProviding, permission: PermissionProviding) {
        self.state = state
        self.permission = permission
    }

    // MARK: - SystemActions & Developer Tools

    /// 复制完整路径到剪贴板（支持多选换行拼接）
    func copyPath(_ target: [String]) {
        let paths = target.compactMap { $0.removingPercentEncoding ?? $0 }
        guard !paths.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    /// 复制文件名到剪贴板（支持多选换行拼接）
    func copyName(_ target: [String]) {
        let names = target.compactMap { item -> String? in
            let path = item.removingPercentEncoding ?? item
            return URL(fileURLWithPath: path).lastPathComponent
        }
        guard !names.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(names.joined(separator: "\n"), forType: .string)
    }

    /// 在终端中打开当前目录（优先识别 Ghostty、Warp、iTerm2，兜底系统 Terminal）
    func openTerminal(_ target: [String]) async {
        guard let first = target.first else { return }
        let path = first.removingPercentEncoding ?? first
        let targetURL = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir)
        let folderURL = (exists && isDir.boolValue) ? targetURL : targetURL.deletingLastPathComponent()

        if !permission.hasAccess(to: folderURL) {
            guard await permission.promptForPermission(for: folderURL) != nil else {
                logger.warning("用户取消授权，跳过打开终端：\(folderURL.path)")
                return
            }
        }

        let terminalURL = detectTerminalAppURL()
        logger.info("Opening terminal \(terminalURL.lastPathComponent) at \(folderURL.path)")

        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([folderURL], withApplicationAt: terminalURL, configuration: config) { _, error in
            if let error {
                self.logger.error("Failed to open terminal: \(error.localizedDescription)")
            }
        }
    }

    private func detectTerminalAppURL() -> URL {
        let candidates = [
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
            "com.googlecode.iterm2",
            "com.apple.Terminal"
        ]
        for bundleId in candidates {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return url
            }
        }
        return URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    }

    private var isTestingEnvironment: Bool {
        NSClassFromString("XCTest") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
        guard !isTestingEnvironment else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: AppLocalization.localized("OK"))
        alert.runModal()
    }

    /// 在代码编辑器中打开（优先识别 Cursor、VS Code、Zed、Sublime Text）
    func openCodeEditor(_ target: [String]) async {
        guard let editorURL = detectCodeEditorURL() else {
            showAlert(
                title: AppLocalization.localized("No Code Editor Found"),
                message: AppLocalization.localized("Please install Cursor, VS Code, Zed, or Sublime Text to use this action.")
            )
            return
        }

        for item in target {
            let path = item.removingPercentEncoding ?? item
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            let accessURL = (exists && isDir.boolValue) ? url : url.deletingLastPathComponent()

            if !permission.hasAccess(to: accessURL) {
                guard await permission.promptForPermission(for: accessURL) != nil else {
                    continue
                }
            }

            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: editorURL, configuration: config) { _, error in
                if let error {
                    self.logger.error("Failed to open code editor: \(error.localizedDescription)")
                }
            }
        }
    }

    private func detectCodeEditorURL() -> URL? {
        let candidates = [
            "com.todesktop.230313mzl4wgnlh", // Cursor
            "com.microsoft.VSCode",          // VS Code
            "dev.zed.Zed",                   // Zed
            "com.sublimetext.4"              // Sublime Text
        ]
        for bundleId in candidates {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return url
            }
        }
        let fallbackPaths = [
            "/Applications/Cursor.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/Zed.app",
            "/Applications/Sublime Text.app"
        ]
        for p in fallbackPaths {
            if FileManager.default.fileExists(atPath: p) {
                return URL(fileURLWithPath: p)
            }
        }
        return nil
    }

    /// 创建标准 Unix 软链接（符号链接）并自动在访达中选中
    func createSymlink(_ target: [String]) async {
        let fm = FileManager.default
        var createdURLs: [URL] = []

        for item in target {
            let path = item.removingPercentEncoding ?? item
            let sourceURL = URL(fileURLWithPath: path)
            let parentURL = sourceURL.deletingLastPathComponent()

            if !permission.hasAccess(to: parentURL) {
                guard await permission.promptForPermission(for: parentURL) != nil else {
                    logger.warning("用户取消授权，跳过创建软链接：\(path)")
                    continue
                }
            }

            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir)
            guard exists else { continue }

            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let symlinkSuffix = AppLocalization.localized("symlink")

            var candidateName = ext.isEmpty ? "\(baseName) \(symlinkSuffix)" : "\(baseName) \(symlinkSuffix).\(ext)"
            var candidateURL = parentURL.appendingPathComponent(candidateName)
            var counter = 2

            while fm.fileExists(atPath: candidateURL.path) {
                candidateName = ext.isEmpty ? "\(baseName) \(symlinkSuffix) \(counter)" : "\(baseName) \(symlinkSuffix) \(counter).\(ext)"
                candidateURL = parentURL.appendingPathComponent(candidateName)
                counter += 1
            }

            do {
                try fm.createSymbolicLink(at: candidateURL, withDestinationURL: sourceURL)
                createdURLs.append(candidateURL)
                logger.info("Successfully created symlink at: \(candidateURL.path) -> \(sourceURL.path)")
            } catch {
                logger.error("Failed to create symlink: \(error.localizedDescription)")
                showAlert(
                    title: AppLocalization.localized("Failed to Create Symlink"),
                    message: error.localizedDescription,
                    style: .warning
                )
            }
        }

        if !createdURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(createdURLs)
        }
    }

    enum HashAlgorithm {
        case sha256
        case md5
    }

    /// 计算文件哈希并复制到剪贴板，弹出提示反馈
    func calculateHash(_ target: [String], algorithm: HashAlgorithm) async {
        guard let first = target.first else { return }
        let path = first.removingPercentEncoding ?? first
        let fileURL = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
            showAlert(
                title: AppLocalization.localized("Notice"),
                message: AppLocalization.localized("Please select a file to calculate hash.")
            )
            return
        }

        let parentURL = fileURL.deletingLastPathComponent()
        if !permission.hasAccess(to: parentURL) {
            guard await permission.promptForPermission(for: parentURL) != nil else {
                return
            }
        }

        do {
            let hashHex = try computeHash(of: fileURL, algorithm: algorithm)
            let algoName = algorithm == .sha256 ? "SHA256" : "MD5"

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(hashHex, forType: .string)

            showAlert(
                title: String(format: AppLocalization.localized("%@ Hash Copied"), algoName),
                message: String(format: AppLocalization.localized("File: %@\n%@: %@\n\nThe hash has been copied to your clipboard."), fileURL.lastPathComponent, algoName, hashHex)
            )
        } catch {
            logger.error("Failed to compute hash: \(error.localizedDescription)")
            showAlert(
                title: AppLocalization.localized("Error Computing Hash"),
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    private func computeHash(of fileURL: URL, algorithm: HashAlgorithm) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let bufferSize = 64 * 1024 // 64 KB streaming buffer
        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                if data.isEmpty { return false }
                hasher.update(data: data)
                return true
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()

        case .md5:
            var hasher = Insecure.MD5()
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: bufferSize)
                if data.isEmpty { return false }
                hasher.update(data: data)
                return true
            }) {}
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    // MARK: - AppActions

    /// 用指定应用打开选中文件/目录（沙盒门控：先 hasAccess，失败兜底再授权重试）
    func openApp(rid: String, target: [String]) async {
        guard let rcitem = state.getAppItem(rid: rid) else {
            logger.warning("when openapp, but not have app \(rid)")
            return
        }

        let appUrl = rcitem.url
        logger.debug("openApp: rid=\(rid) app=\(appUrl.path) target=\(target) opensNewInstance=\(rcitem.opensNewInstance)")

        for dirPath in target {
            let decodedPath = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: decodedPath)
            await openWithApp(url, appUrl: appUrl, opensNewInstance: rcitem.opensNewInstance)
        }
    }

    private func openWithApp(_ url: URL, appUrl: URL, opensNewInstance: Bool) async {
        let logger = self.logger  // 捕获 Sendable logger，供完成回调使用
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let accessURL = (exists && isDir.boolValue) ? url : url.deletingLastPathComponent()

        // 门控先行：未授权先弹窗，避免"只是打开一个文件"也要用户授权整个父目录的弹窗偏重
        if !permission.hasAccess(to: accessURL) {
            guard await permission.promptForPermission(for: accessURL) != nil else {
                logger.warning("用户取消授权，跳过打开：\(url.path)")
                return
            }
        }

        let config = NSWorkspace.OpenConfiguration()
        // 以新实例打开（浏览器类 app 会新开窗口而非新 tab）
        config.createsNewApplicationInstance = opensNewInstance
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config) { [weak self] runningApp, error in
            guard let self else { return }
            if let error {
                // 失败兜底：再弹授权并重试一次
                Task { @MainActor in
                    await self.openRetryAfterPermission(url: url, appUrl: appUrl, accessURL: accessURL, opensNewInstance: opensNewInstance, firstError: error)
                }
            } else if let runningApp {
                logger.debug("Successfully opened with application: \(runningApp.localizedName ?? "Unknown")")
            }
        }
    }

    private func openRetryAfterPermission(url: URL, appUrl: URL, accessURL: URL, opensNewInstance: Bool, firstError: Error) async {
        let logger = self.logger  // 捕获 Sendable logger
        guard await permission.promptForPermission(for: accessURL) != nil else {
            logger.error("打开失败且用户取消授权：\(url.path) — \(firstError.localizedDescription)")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = opensNewInstance
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config) { _, retryError in
            if let retryError {
                logger.error("重试打开仍失败：\(url.path) — \(retryError.localizedDescription)")
            }
        }
    }

    /// 打开常用目录（沙盒门控：目录需已授权，B4 之后添加时即存 bookmark，此处为兜底）
    func openCommonDirs(target: [String]) async {
        logger.debug("开始打开常用目录，目标路径：\(target)")

        for dirPath in target {
            let path = dirPath.removingPercentEncoding ?? dirPath
            let url = URL(fileURLWithPath: path, isDirectory: true)

            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过打开目录：\(path)")
                    continue
                }
            }
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - FileActions

    /// 动作分发入口
    func actionHandler(rid: String, target: [String], trigger: String) async {
        guard let rcitem = state.getActionItem(rid: rid) else {
            logger.warning("when actionHandler, but not have action \(rid)")
            return
        }

        switch rcitem.id {
        case "copy-path":
            copyPath(target)
        case "copy-name":
            copyName(target)
        case "open-terminal":
            await openTerminal(target)
        case "open-editor":
            await openCodeEditor(target)
        case "create-symlink":
            await createSymlink(target)
        case "calc-sha256":
            await calculateHash(target, algorithm: .sha256)
        case "calc-md5":
            await calculateHash(target, algorithm: .md5)
        case "delete-direct":
            await deleteFoldorFile(target, trigger)
        case "unhide":
            await unhideFilesAndDirs(target, trigger)
        case "hide":
            await hideFilesAndDirs(target, trigger)
        case "airdrop":
            await showAirDrop(target, trigger)
        default:
            if let script = rcitem.script, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await executeCustomScript(action: rcitem, target: target, trigger: trigger)
            } else {
                logger.warning("no action id matched: \(rcitem.id)")
            }
        }
    }

    /// 执行自定义 Shell 脚本动作（支持占位符 $PATH, $DIR, $NAME, $STEM, $EXT, $FILES）
    func executeCustomScript(action: RCAction, target: [String], trigger: String) async {
        guard let scriptTemplate = action.script, !scriptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let cleanPaths = target.compactMap { $0.removingPercentEncoding ?? $0 }
        let firstPath = cleanPaths.first ?? ""
        let targetURL = firstPath.isEmpty ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: firstPath)

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir)
        let workingDirURL = (exists && isDir.boolValue) ? targetURL : targetURL.deletingLastPathComponent()

        let name = targetURL.lastPathComponent
        let stem = targetURL.deletingPathExtension().lastPathComponent
        let ext = targetURL.pathExtension
        let quotedFiles = cleanPaths.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: " ")

        var script = scriptTemplate
        script = script.replacingOccurrences(of: "$PATH", with: firstPath)
        script = script.replacingOccurrences(of: "$DIR", with: workingDirURL.path)
        script = script.replacingOccurrences(of: "$NAME", with: name)
        script = script.replacingOccurrences(of: "$STEM", with: stem)
        script = script.replacingOccurrences(of: "$EXT", with: ext)
        script = script.replacingOccurrences(of: "$FILES", with: quotedFiles.isEmpty ? "\"\(firstPath)\"" : quotedFiles)

        logger.info("Executing custom script action [\(action.displayName)]: \(script)")

        if action.runInBackground {
            await executeScriptInBackground(script: script, workingDir: workingDirURL, actionName: action.displayName)
        } else {
            await executeScriptInTerminal(script: script, workingDir: workingDirURL, actionName: action.displayName)
        }
    }

    private func executeScriptInBackground(script: String, workingDir: URL, actionName: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", script]
        process.currentDirectoryURL = workingDir

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (env["PATH"] ?? "") + ":/usr/local/bin:/opt/homebrew/bin"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errorOutput = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                logger.info("Custom action [\(actionName)] succeeded. Output: \(output)")
                if !output.isEmpty {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(output, forType: .string)
                }
                showAlert(
                    title: String(format: AppLocalization.localized("Action Succeeded: %@"), actionName),
                    message: output.isEmpty
                        ? AppLocalization.localized("Command executed successfully.")
                        : String(format: AppLocalization.localized("Output (copied to clipboard):\n%@"), output),
                    style: .informational
                )
            } else {
                logger.error("Custom action [\(actionName)] failed (code \(process.terminationStatus)): \(errorOutput)")
                showAlert(
                    title: String(format: AppLocalization.localized("Action Failed: %@"), actionName),
                    message: errorOutput.isEmpty
                        ? String(format: AppLocalization.localized("Process exited with status %d"), process.terminationStatus)
                        : errorOutput,
                    style: .warning
                )
            }
        } catch {
            logger.error("Failed to run custom action process: \(error.localizedDescription)")
            showAlert(
                title: String(format: AppLocalization.localized("Action Error: %@"), actionName),
                message: error.localizedDescription,
                style: .critical
            )
        }
    }

    private func executeScriptInTerminal(script: String, workingDir: URL, actionName: String) async {
        let escapedDir = workingDir.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

        let appleScriptSource = """
        tell application "Terminal"
            activate
            do script "cd \\"\(escapedDir)\\" && \(escapedScript)"
        end tell
        """

        if let appleScript = NSAppleScript(source: appleScriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                logger.error("Failed to execute Terminal script: \(String(describing: error))")
            }
        }
    }

    func showAirDrop(_ target: [String], _ trigger: String) async {
        logger.info("---- showAirDrop trigger:\(trigger)")
        let fm = FileManager.default
        var fileURLs: [URL] = []

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be shared. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item
            logger.info("airdrop path \(decodedPath)")

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be shared: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图分享受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: decodedPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    logger.warning("不能通过 AirDrop 分享文件夹：\(decodedPath)")
                    let alert = NSAlert()
                    alert.messageText = AppLocalization.localized("Notice")
                    alert.informativeText = String(format: AppLocalization.localized("Folders cannot be shared via AirDrop: %@"), decodedPath)
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: AppLocalization.localized("OK"))
                    alert.runModal()
                    continue
                } else {
                    // 确保有文件所在目录的访问权限
                    let fileURL = URL(fileURLWithPath: decodedPath)
                    let dirURL = fileURL.deletingLastPathComponent()
                    if !permission.hasAccess(to: dirURL) {
                        guard await permission.promptForPermission(for: dirURL) != nil else {
                            logger.warning("用户取消授权，跳过 AirDrop：\(decodedPath)")
                            continue
                        }
                    }
                    fileURLs.append(fileURL)
                }
            }
        }

        if !fileURLs.isEmpty {
            if let airDropService = NSSharingService(named: .sendViaAirDrop) {
                airDropService.perform(withItems: fileURLs)
                logger.info("已通过 AirDrop 分享文件：\(fileURLs.map { $0.path }.joined(separator: ", "))")
            } else {
                logger.warning("无法获取 AirDrop 服务")
            }
        }
    }

    func unhideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始取消隐藏文件和目录，目标路径：\(target)")
        if let dirPath = target.first {
            let fileManager = FileManager.default
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过取消隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = false
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功取消隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("取消隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }

            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                var targetURL = url
                try targetURL.setResourceValues(resourceValues)
                logger.info("成功取消隐藏主目录：\(path)")
            } catch {
                logger.error("取消隐藏主目录失败：\(path): \(error)")
            }
            logger.info("取消隐藏操作完成，共处理目录：\(path)")
        }
    }

    func hideFilesAndDirs(_ target: [String], _ trigger: String) async {
        logger.info("开始隐藏文件和目录，目标路径：\(target), 触发器：\(trigger)")
        let fileManager = FileManager.default

        if trigger == "ctx-container", let dirPath = target.first {
            let path = dirPath.removingPercentEncoding ?? dirPath
            logger.info("处理主目录：\(path)")
            let url = URL(fileURLWithPath: path)

            // 确保有目录的访问权限
            if !permission.hasAccess(to: url) {
                guard await permission.promptForPermission(for: url) != nil else {
                    logger.warning("用户取消授权，跳过隐藏：\(path)")
                    return
                }
            }

            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants])
                for case var fileURL in contents {
                    if Utils.isProtectedFolder(fileURL.path) {
                        logger.warning("跳过受保护的文件路径：\(fileURL.path)")
                        continue
                    }
                    do {
                        var resourceValues = URLResourceValues()
                        resourceValues.isHidden = true
                        try fileURL.setResourceValues(resourceValues)
                        logger.info("成功隐藏：\(fileURL.path)")
                    } catch {
                        logger.error("隐藏失败：\(fileURL.path): \(error)")
                    }
                }
            } catch {
                logger.error("获取目录内容失败：\(error)")
            }
        } else if trigger == "ctx-items" {
            for dirPath in target {
                let path = dirPath.removingPercentEncoding ?? dirPath
                logger.info("处理路径：\(path)")
                let url = URL(fileURLWithPath: path)

                if Utils.isProtectedFolder(path) {
                    logger.warning("跳过受保护的文件路径：\(path)")
                    continue
                }

                // 确保有文件所在目录的访问权限
                let dirURL = url.deletingLastPathComponent()
                if !permission.hasAccess(to: dirURL) {
                    guard await permission.promptForPermission(for: dirURL) != nil else {
                        logger.warning("用户取消授权，跳过隐藏：\(path)")
                        continue
                    }
                }

                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = true
                    var targetURL = url
                    try targetURL.setResourceValues(resourceValues)
                    logger.info("成功隐藏：\(path)")
                } catch {
                    logger.error("隐藏失败：\(path): \(error)")
                }
            }
        }
        logger.info("隐藏操作完成")
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) async {
        logger.info("---- deleteFoldorFile trigger:\(trigger)")
        let fm = FileManager.default

        if trigger == "ctx-container" {
            let alert = NSAlert()
            alert.messageText = AppLocalization.localized("Warning")
            alert.informativeText = AppLocalization.localized("The current folder cannot be deleted. Please select files or subfolders instead.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: AppLocalization.localized("OK"))
            alert.runModal()
            return
        }

        for item in target {
            let decodedPath = item.removingPercentEncoding ?? item

            if Utils.isProtectedFolder(decodedPath) {
                let alert = NSAlert()
                alert.messageText = AppLocalization.localized("Warning")
                alert.informativeText = String(format: AppLocalization.localized("Protected system folders cannot be deleted: %@"), decodedPath)
                alert.alertStyle = .warning
                alert.addButton(withTitle: AppLocalization.localized("OK"))
                alert.runModal()
                logger.warning("试图删除受保护的系统文件夹，操作已被阻止：\(decodedPath)")
                continue
            }

            // 确保有父目录的访问权限
            let url = URL(fileURLWithPath: decodedPath)
            let dirURL = url.deletingLastPathComponent()
            if !permission.hasAccess(to: dirURL) {
                guard await permission.promptForPermission(for: dirURL) != nil else {
                    logger.warning("用户取消授权，跳过删除：\(decodedPath)")
                    continue
                }
            }

            do {
                try fm.removeItem(atPath: decodedPath)
            } catch {
                logger.error("delete \(target) file run error \(error)")
            }
        }
    }

    // MARK: - NewFileActions

    func createFile(rid: String, target: [String]) async {
        guard let dirPath = targetDirectoryForNewFile(target) else {
            logger.warning("when createFile, but not have target directory")
            return
        }

        let dirURL = URL(fileURLWithPath: dirPath)

        // 确保有目标目录的访问权限
        if !permission.hasAccess(to: dirURL) {
            guard await permission.promptForPermission(for: dirURL) != nil else {
                logger.warning("用户取消授权，跳过创建文件")
                return
            }
        }

        if rid == NewFileMenuItem.customFileId {
            let filePath = getUniqueFilePath(dir: dirPath, ext: "")
            let fileURL = URL(fileURLWithPath: filePath)
            do {
                try Data().write(to: fileURL)
                logger.info("created editable file: \(fileURL.path)")
                revealInFinderAndRename(fileURL)
            } catch {
                logger.error("create editable file error: \(error.localizedDescription)")
            }
            return
        }

        guard let rcitem = state.getFileType(rid: rid) else {
            logger.warning("when createFile, but not have fileType \(rid) ")
            return
        }

        let ext = rcitem.ext
        logger.info("create file dir:\(dirPath) -- ext \(ext)")
        let filePath = getUniqueFilePath(dir: dirPath, ext: ext)
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let fileManager = FileManager.default

            if let templateUrl = rcitem.template {
                try fileManager.copyItem(at: templateUrl, to: fileURL)
                logger.info("已成功复制模板到目标路径：\(fileURL.path)")
            } else {
                if let defaultTemplateURL = Bundle.main.url(forResource: "template", withExtension: ext.replacingOccurrences(of: ".", with: "")) {
                    logger.info("使用模板创建文件，模板路径：\(defaultTemplateURL.path)")
                    try fileManager.copyItem(at: defaultTemplateURL, to: fileURL)
                    logger.info("已成功复制模板到目标路径：\(fileURL.path)")
                } else {
                    logger.warning("模板文件不存在：\(ext)")
                    try Data().write(to: fileURL)
                }
            }
            revealInFinderAndRename(fileURL)
        } catch let error as NSError {
            switch error.domain {
            case NSCocoaErrorDomain:
                switch error.code {
                case NSFileNoSuchFileError:
                    logger.error("文件不存在：\(filePath)")
                case NSFileWriteOutOfSpaceError:
                    logger.error("磁盘空间不足")
                case NSFileWriteNoPermissionError:
                    logger.error("没有写入权限：\(filePath)")
                default:
                    logger.error("创建文件错误：\(error.localizedDescription) (错误码：\(error.code))")
                }
            default:
                logger.error("未处理的错误：\(error.localizedDescription) (错误码：\(error.code))")
            }
        }
    }

    // MARK: - 辅助

    /// 生成目录内唯一的文件名（避免重名冲突）
    func getUniqueFilePath(dir: String, ext: String) -> String {
        let fileManager = FileManager.default
        let dirURL = URL(fileURLWithPath: dir.hasSuffix("/") ? String(dir.dropLast()) : dir)
        let baseFileName = AppLocalization.localized("Untitled")
        var filePath = dirURL.appendingPathComponent("\(baseFileName)\(ext)").path
        var counter = 1

        while fileManager.fileExists(atPath: filePath) {
            let newFileName = "\(baseFileName)\(counter)"
            filePath = dirURL.appendingPathComponent("\(newFileName)\(ext)").path
            counter += 1
        }

        return filePath
    }

    /// 解析新建文件的目标目录（目录直接用；文件取父目录）
    private func targetDirectoryForNewFile(_ target: [String]) -> String? {
        guard let rawPath = target.first else { return nil }
        let path = rawPath.removingPercentEncoding ?? rawPath
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return path
            }
            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        return path
    }

    /// 在 Finder 中选中新文件并触发重命名（需要辅助功能权限）
    private func revealInFinderAndRename(_ fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [logger] in
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            guard AXIsProcessTrustedWithOptions(options) else {
                logger.warning("Accessibility permission is required to trigger Finder rename for \(fileURL.path)")
                return
            }

            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let keyCodeReturn: CGKeyCode = 36
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeReturn, keyDown: false)
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }
}
