//
//  GeneralSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/10.
//

import AppKit
import Cocoa
import FinderSync
import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsTabView: View {
    @AppLog(category: "settings-general")
    private var logger

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true
    @AppStorage(Key.showInDock, store: .group) private var showInDock = true
    @ObservedObject private var bookmarkManager = AppState.shared.bookmarkManager
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var finderSyncStatus: PermissionStatus = .unknown
    @State private var accessibilityStatus: PermissionStatus = .unknown
    @State private var showFolderPermissionsSheet = false
    @State private var isMainControlsExpanded = true
    @State private var isPermissionsExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // MARK: - 1. 主要控制卡片
                SettingsCard(
                    title: AppLocalization.localized("Main Controls"),
                    icon: "gearshape",
                    iconColor: .blue,
                    trailing: {
                        disclosureIndicator(isExpanded: isMainControlsExpanded)
                    },
                    headerAction: {
                        toggleSection($isMainControlsExpanded)
                    }
                ) {
                    if isMainControlsExpanded {
                        VStack(spacing: 8) {
                            SettingsCardRow(
                                icon: "arrow.clockwise.circle",
                                iconColor: .blue,
                                title: AppLocalization.localized("Launch at login"),
                                subtitle: AppLocalization.localized("Automatically start RClickX when your Mac turns on")
                            ) {
                                LaunchAtLogin.Toggle(compact: true) {
                                    EmptyView()
                                }
                            }

                            Divider().opacity(0.4)

                            SettingsCardRow(
                                icon: "menubar.rectangle",
                                iconColor: .blue,
                                title: AppLocalization.localized("Show icon in menu bar"),
                                subtitle: AppLocalization.localized("Show RClickX icon in the top macOS menu bar for quick access")
                            ) {
                                Toggle("", isOn: $showMenuBarExtra)
                                    .labelsHidden()
                            }

                            Divider().opacity(0.4)

                            SettingsCardRow(
                                icon: "dock.rectangle",
                                iconColor: .blue,
                                title: AppLocalization.localized("Show icon in Dock"),
                                subtitle: AppLocalization.localized("Show RClickX in the Dock for quick access")
                            ) {
                                Toggle("", isOn: $showInDock)
                                    .labelsHidden()
                            }

                            Divider().opacity(0.4)

                            SettingsCardRow(
                                icon: "globe",
                                iconColor: .blue,
                                title: AppLocalization.localized("Language"),
                                subtitle: AppLocalization.localized("Choose your preferred display language")
                            ) {
                                Picker("", selection: Binding(
                                    get: { languageManager.currentLanguage },
                                    set: { languageManager.setLanguage($0) }
                                )) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }
                        }
                        .padding(.top, 10)
                    }
                }

                // MARK: - 2. 系统权限卡片
                SettingsCard(
                    title: AppLocalization.localized("Permissions"),
                    icon: "checkmark.shield",
                    iconColor: .green,
                    subtitle: AppLocalization.localized("Permissions required by enabled features"),
                    trailing: {
                        disclosureIndicator(isExpanded: isPermissionsExpanded)
                    },
                    headerAction: {
                        toggleSection($isPermissionsExpanded)
                    }
                ) {
                    if isPermissionsExpanded {
                        VStack(spacing: 8) {
                            SettingsCardRow(
                                icon: finderSyncStatus.icon,
                                iconColor: finderSyncStatus.color,
                                title: AppLocalization.localized("Finder Extension"),
                                subtitle: AppLocalization.localized("Required to show RClickX in Finder menus")
                            ) {
                                HStack(spacing: 8) {
                                    StatusPill(
                                        text: finderSyncStatus == .enabled ? AppLocalization.localized("Enabled") : AppLocalization.localized("Action Required"),
                                        color: finderSyncStatus.color
                                    )
                                    Button(AppLocalization.localized("Settings…")) {
                                        openFinderExtensionSettings()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            Divider().opacity(0.4)

                            SettingsCardRow(
                                icon: "folder.badge.gearshape",
                                iconColor: .orange,
                                title: AppLocalization.localized("Folder Permissions"),
                                subtitle: String(format: AppLocalization.localized("%d directories pre-authorized"), bookmarkManager.authorizedDirectories.count)
                            ) {
                                Button(AppLocalization.localized("Manage…")) {
                                    showFolderPermissionsSheet = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Divider().opacity(0.4)

                            SettingsCardRow(
                                icon: accessibilityStatus.icon,
                                iconColor: accessibilityStatus.color,
                                title: AppLocalization.localized("Accessibility"),
                                subtitle: AppLocalization.localized("Optional for Finder actions that trigger a rename")
                            ) {
                                HStack(spacing: 8) {
                                    StatusPill(
                                        text: accessibilityStatus == .enabled ? AppLocalization.localized("Enabled") : AppLocalization.localized("Optional"),
                                        color: accessibilityStatus.color
                                    )
                                    Button(AppLocalization.localized("Settings…")) {
                                        openAccessibilitySettings()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }

                // MARK: - 3. 设置与备份管理卡片
                SettingsCard(
                    title: AppLocalization.localized("Settings Management"),
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .gray
                ) {
                    VStack(spacing: 8) {
                        SettingsCardRow(
                            icon: "arrow.down.doc",
                            iconColor: .gray,
                            title: AppLocalization.localized("Backup Configuration"),
                            subtitle: AppLocalization.localized("Export or restore your RClickX configuration file")
                        ) {
                            HStack(spacing: 8) {
                                Button(AppLocalization.localized("Export…")) {
                                    exportSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(AppLocalization.localized("Import…")) {
                                    importSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Divider().opacity(0.4)

                        SettingsCardRow(
                            icon: "doc.text",
                            iconColor: .gray,
                            title: AppLocalization.localized("Diagnostic Logs"),
                            subtitle: AppLocalization.localized("Export troubleshooting logs for debugging")
                        ) {
                            Button(AppLocalization.localized("Export Logs…")) {
                                exportLogs()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Divider().opacity(0.4)

                        HStack {
                            Spacer()
                            Button(AppLocalization.localized("Reset All Settings…")) {
                                resetAllSettings()
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            updatePermissionStatus()
        }
        .onForeground {
            updatePermissionStatus()
        }
        .onChange(of: showInDock) { _, newValue in
            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
            if newValue {
                if let appIcon = NSImage(named: "AppIcon") ?? NSImage(named: "Logo") {
                    NSApplication.shared.applicationIconImage = appIcon
                }
            }
        }
        .sheet(isPresented: $showFolderPermissionsSheet) {
            FolderPermissionsSheetView(bookmarkManager: bookmarkManager)
        }
    }

    private func disclosureIndicator(isExpanded: Bool) -> some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }

    private func toggleSection(_ isExpanded: Binding<Bool>) {
        withAnimation(.easeInOut(duration: 0.16)) {
            isExpanded.wrappedValue.toggle()
        }
    }

    // MARK: - 权限状态检测

    private func updatePermissionStatus() {
        Task { @MainActor in
            let finderEnabled = await Task.detached(priority: .userInitiated) {
                FIFinderSyncController.isExtensionEnabled
            }.value
            let axEnabled = PermissionChecker.hasAccessibilityPermission()
            finderSyncStatus = finderEnabled ? .enabled : .disabled
            accessibilityStatus = axEnabled ? .enabled : .disabled
        }
    }

    // MARK: - 权限设置打开

    private func openFinderExtensionSettings() {
        PermissionChecker.openFinderExtensionSettings()
    }

    private func openAccessibilitySettings() {
        PermissionChecker.openAccessibilitySettings()
    }

    // MARK: - 设置管理

    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.propertyList]
        savePanel.nameFieldStringValue = "RClick_Settings.plist"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            // TODO: 实现设置导出逻辑
            logger.info("导出设置到：\(url.path)")
        }
    }

    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.propertyList]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            // TODO: 实现设置导入逻辑
            logger.info("从以下路径导入设置：\(url.path)")
        }
    }

    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "RClick_Log.txt"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            // TODO: 实现日志导出逻辑
            logger.info("导出日志到：\(url.path)")
        }
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localized("Reset All Settings?")
        alert.informativeText = AppLocalization.localized("This will delete all custom configurations and restore the defaults. This action cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalization.localized("Reset"))
        alert.addButton(withTitle: AppLocalization.localized("Cancel"))
        alert.buttons[0].hasDestructiveAction = true

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // TODO: 实现重置逻辑
            logger.info("重置所有设置")
        }
    }
}

// MARK: - 权限状态枚举

enum PermissionStatus {
    case enabled
    case disabled
    case unknown

    var icon: String {
        switch self {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "circle"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .gray
        case .unknown:
            return .yellow
        }
    }

    var description: String {
        switch self {
        case .enabled:
            return AppLocalization.localized("Authorized")
        case .disabled:
            return AppLocalization.localized("Not Authorized")
        case .unknown:
            return AppLocalization.localized("Unknown")
        }
    }
}
