//
//  OnboardingView.swift
//  RClick
//
//  新手引导向导：首次启动或扩展未启用时，一步引导用户完成访达扩展、全盘授权与人群预设
//

import AppKit
import Combine
import FinderSync
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var bookmarkManager = AppState.shared.bookmarkManager
    @ObservedObject private var languageManager = LanguageManager.shared

    @AppStorage("hasCompletedOnboarding", store: .group) private var hasCompletedOnboarding = false
    @State private var isExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var accessibilityStatus: PermissionStatus = .unknown
    @State private var showFolderPermissionsSheet = false
    @State private var selectedPreset: MenuPreset = .general

    private let startupDiskURL = URL(fileURLWithPath: "/", isDirectory: true)

    private var isStartupDiskAuthorized: Bool {
        let target = startupDiskURL.resolvingSymlinksInPath()
        return bookmarkManager.authorizedDirectories.contains { BookmarkManager.covers($0, target) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部标题、Logo 与右上角语言切换
            headerView
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider().opacity(0.4)

            // 引导卡片列表
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 权限卡片与通用设置页保持一致
                    extensionCard

                    folderPermissionsCard

                    accessibilityCard

                    // 选择适合你的预设方案
                    presetSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            Divider().opacity(0.4)

            // 底部操作栏
            footerView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .id(languageManager.refreshID)
        .frame(width: 680, height: 640)
        .onAppear {
            checkStatus()
        }
        .sheet(isPresented: $showFolderPermissionsSheet) {
            FolderPermissionsSheetView(bookmarkManager: bookmarkManager)
        }
        // 每秒自动刷新系统扩展开启状态，用户在系统设置里勾选后无需手动刷新即可感知
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            checkStatus()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)

                Text(AppLocalization.localized("Welcome to RClickX"))
                    .font(.system(size: 22, weight: .bold))

                Text(AppLocalization.localized("Easily enhance your macOS Finder context menu with zero-configuration efficiency tools."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .frame(maxWidth: .infinity)

            // 语言切换下拉
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
            .frame(width: 120)
        }
    }

    private var extensionCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isExtensionEnabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: isExtensionEnabled ? "checkmark.seal.fill" : "puzzlepiece.extension")
                    .font(.system(size: 20))
                    .foregroundStyle(isExtensionEnabled ? Color.green : Color.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(AppLocalization.localized("Finder Extension"))
                        .font(.system(size: 14, weight: .semibold))

                    Text(isExtensionEnabled ? AppLocalization.localized("Enabled") : AppLocalization.localized("Action Required"))
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isExtensionEnabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundStyle(isExtensionEnabled ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }

                Text(AppLocalization.localized("Required by macOS to show right-click items in Finder. Toggle \"RClickX\" in Finder Extensions."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !isExtensionEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text(AppLocalization.localized("Tip: Open General > Login Items & Extensions > Extensions, then turn on RClickX under Finder."))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                openFinderExtensionSettings()
            } label: {
                Text(isExtensionEnabled ? AppLocalization.localized("View Settings") : AppLocalization.localized("Open Settings"))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var folderPermissionsCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isStartupDiskAuthorized ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: isStartupDiskAuthorized ? "checkmark.circle.fill" : "internaldrive")
                    .font(.system(size: 20))
                    .foregroundStyle(isStartupDiskAuthorized ? Color.green : Color.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(AppLocalization.localized("Folder Permissions"))
                        .font(.system(size: 14, weight: .semibold))

                    if isStartupDiskAuthorized {
                        Text(AppLocalization.localized("Full Disk Authorized"))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    } else if !bookmarkManager.authorizedDirectories.isEmpty {
                        Text(String(format: AppLocalization.localized("%d directories pre-authorized"), bookmarkManager.authorizedDirectories.count))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(AppLocalization.localized("Authorize folders to let RClick create, delete, and manage files in them."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isStartupDiskAuthorized {
                Label(AppLocalization.localized("Authorized"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 6) {
                    Button {
                        authorizeStartupDisk()
                    } label: {
                        Text(AppLocalization.localized("Authorize Startup Disk (/)"))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Menu {
                        Button {
                            authorizeHomeDirectory()
                        } label: {
                            Label(AppLocalization.localized("Authorize Home Directory (~)"), systemImage: "house")
                        }

                        Button {
                            addCustomFolder()
                        } label: {
                            Label(AppLocalization.localized("Choose a folder"), systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .help(AppLocalization.localized("More Authorization Options"))
                }
            }

            Button(AppLocalization.localized("Manage…")) {
                showFolderPermissionsSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var accessibilityCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accessibilityStatus == .enabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: accessibilityStatus == .enabled ? "checkmark.circle.fill" : "figure.wave.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(accessibilityStatus == .enabled ? Color.green : Color.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(AppLocalization.localized("Accessibility"))
                        .font(.system(size: 14, weight: .semibold))

                    Text(accessibilityStatus == .enabled ? AppLocalization.localized("Enabled") : AppLocalization.localized("Optional"))
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((accessibilityStatus == .enabled ? Color.green : Color.orange).opacity(0.15))
                        .foregroundStyle(accessibilityStatus == .enabled ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }

                Text(AppLocalization.localized("Optional for Finder actions that trigger a rename"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(AppLocalization.localized("Settings…")) {
                PermissionChecker.openAccessibilitySettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppLocalization.localized("Presets"))
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text(selectedPreset.title)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(selectedPreset.accentColor.opacity(0.12))
                    .foregroundStyle(selectedPreset.accentColor)
                    .clipShape(Capsule())
            }

            Text(AppLocalization.localized("Choose a curated right-click menu tailored to your workflow. You can customize it further at any time."))
                .font(.caption)
                .foregroundStyle(.secondary)

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
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var footerView: some View {
        HStack {
            Text(AppLocalization.localized("💡 You can reopen this guide anytime from the menu bar icon."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                HStack(spacing: 6) {
                    Text(AppLocalization.localized("Get Started"))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Actions

    private func checkStatus() {
        let enabled = FIFinderSyncController.isExtensionEnabled
        if enabled != isExtensionEnabled {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExtensionEnabled = enabled
            }
        }
        accessibilityStatus = PermissionChecker.hasAccessibilityPermission() ? .enabled : .disabled
    }

    private func openFinderExtensionSettings() {
        PermissionChecker.openFinderExtensionSettings()
    }

    private func authorizeStartupDisk() {
        Task { @MainActor in
            _ = await bookmarkManager.addDirectory(startingAt: startupDiskURL)
        }
    }

    private func authorizeHomeDirectory() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        Task { @MainActor in
            _ = await bookmarkManager.addDirectory(startingAt: homeURL)
        }
    }

    private func addCustomFolder() {
        Task { @MainActor in
            _ = await bookmarkManager.addDirectory()
        }
    }

    @MainActor
    private func finishOnboarding() {
        selectedPreset.apply(to: appState)
        hasCompletedOnboarding = true
        dismiss()
        WindowManager.shared.closeOnboarding()
    }
}
