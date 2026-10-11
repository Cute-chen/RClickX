//
//  PermissionChecker.swift
//  RClick
//
//  辅助功能与访达扩展权限检查及系统设置导航模块
//

import AppKit
@preconcurrency import ApplicationServices
import Foundation
import OSLog
import SwiftUI

// MARK: - Logger

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RClick",
    category: "PermissionChecker"
)

// MARK: - 权限检查器

/// 提供辅助功能与系统扩展权限的检测和准确定位打开
public class PermissionChecker {

    /// 打开访达扩展管理设置界面。
    ///
    /// macOS 26/27 中 `FIFinderSyncController.showExtensionManagementInterface()`
    /// 可能会把用户带到“文件提供程序”分类，而 RClickX 使用的是 Finder Sync
    /// 扩展。优先打开“登录项与扩展”的总扩展列表，避免用户误入错误分类。
    @MainActor
    public static func openFinderExtensionSettings() {
        // macOS 26/27: 通用 > 登录项与扩展 > 扩展
        let candidates: [String] = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension?ExtensionItems",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            // macOS 15/26 的兼容入口
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            // macOS 13/14 (Ventura/Sonoma)「隐私与安全性 > 扩展」
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Extensions",
            // macOS Monterey (12) 及更早版本
            "x-apple.systempreferences:com.apple.preference.extensions?FinderSync",
            "x-apple.systempreferences:com.apple.preference.extensions"
        ]

        for path in candidates {
            if let url = URL(string: path), NSWorkspace.shared.open(url) {
                bringSystemSettingsToFront()
                return
            }
        }

        bringSystemSettingsToFront()
    }

    /// 打开辅助功能权限设置
    @MainActor
    public static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systemsettings:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for path in candidates {
            if let url = URL(string: path), NSWorkspace.shared.open(url) {
                bringSystemSettingsToFront()
                return
            }
        }
        if let settingsUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systemsettings") {
            NSWorkspace.shared.open(settingsUrl)
            bringSystemSettingsToFront()
        }
    }

    /// 激活系统设置应用，确保窗口浮到最前
    @MainActor
    public static func bringSystemSettingsToFront() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systemsettings").first {
                app.activate(options: [.activateIgnoringOtherApps])
            } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    /// 检查辅助功能权限
    /// - Returns: 如果有辅助功能权限则返回 true
    public static func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
