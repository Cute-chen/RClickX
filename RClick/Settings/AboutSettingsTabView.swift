//
//  AboutSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import Foundation
import SwiftUI

struct AboutSettingsTabView: View {
    @EnvironmentObject var updateManager: UpdateManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader
                updateCard
                communityCard
                openSourceCard
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await updateManager.loadStarCount()
        }
    }

    // MARK: - 1. 顶部品牌与应用标识

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

            VStack(spacing: 6) {
                Text("RClickX")
                    .font(.system(size: 22, weight: .bold))

                HStack(spacing: 6) {
                    Text(String(format: AppLocalization.localized("Version %@ (%@)"), getAppVersion(), getBuildVersion()))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }

            Text(appLocalized: "A next-generation Finder context menu enhancer for macOS, providing zero-configuration productivity actions and fast application launchers.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    // MARK: - 2. 软件更新卡片

    private var updateCard: some View {
        SettingsCard(
            title: AppLocalization.localized("Software Update"),
            icon: "arrow.triangle.2.circlepath",
            iconColor: .blue
        ) {
            SettingsCardRow(
                icon: updateStatus.icon,
                iconColor: updateStatus.color,
                title: updateStatus.title,
                subtitle: updateStatus.subtitle
            ) {
                HStack(spacing: 10) {
                    if updateManager.isChecking {
                        ProgressView().controlSize(.small)
                    }

                    if updateStatus.isProminent {
                        Button(updateStatus.actionTitle) {
                            handleUpdateAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(updateManager.isChecking)
                    } else {
                        Button(updateStatus.actionTitle) {
                            handleUpdateAction()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(updateManager.isChecking)
                    }
                }
            }
        }
    }

    private func handleUpdateAction() {
        switch updateStatus.action {
        case .check:
            Task { await updateManager.checkForUpdates(force: true) }
        case .details:
            updateManager.showUpdateDetails()
        }
    }

    private struct UpdateStatus {
        enum Action { case check, details }

        let title: String
        let subtitle: String?
        let icon: String
        let color: Color
        let actionTitle: String
        let action: Action
        var isProminent: Bool = false
    }

    private var updateStatus: UpdateStatus {
        if updateManager.isChecking {
            return UpdateStatus(
                title: AppLocalization.localized("Checking for updates..."),
                subtitle: AppLocalization.localized("Connecting to update server..."),
                icon: "arrow.triangle.2.circlepath",
                color: .secondary,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check,
                isProminent: false
            )
        }
        if let release = updateManager.availableUpdate {
            return UpdateStatus(
                title: AppLocalization.localized("New Version Available"),
                subtitle: String(format: AppLocalization.localized("Version %@ is ready to install"), release.version),
                icon: "arrow.down.circle.fill",
                color: .blue,
                actionTitle: AppLocalization.localized("View Details…"),
                action: .details,
                isProminent: true
            )
        }
        if updateManager.updateError != nil {
            return UpdateStatus(
                title: AppLocalization.localized("Failed to Check for Updates"),
                subtitle: AppLocalization.localized("Unable to check for updates right now"),
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check,
                isProminent: false
            )
        }
        if updateManager.isUpToDate {
            return UpdateStatus(
                title: AppLocalization.localized("Up to Date"),
                subtitle: AppLocalization.localized("The current version is already up to date."),
                icon: "checkmark.circle.fill",
                color: .green,
                actionTitle: AppLocalization.localized("Check for Updates"),
                action: .check,
                isProminent: false
            )
        }
        return UpdateStatus(
            title: AppLocalization.localized("Not checked yet"),
            subtitle: AppLocalization.localized("Check GitHub Releases for the latest version"),
            icon: "arrow.triangle.2.circlepath",
            color: .secondary,
            actionTitle: AppLocalization.localized("Check for Updates"),
            action: .check,
            isProminent: false
        )
    }

    // MARK: - 3. 社区与支持卡片

    private var communityCard: some View {
        SettingsCard(
            title: AppLocalization.localized("Community & Support"),
            icon: "bubble.left.and.bubble.right",
            iconColor: .purple
        ) {
            VStack(spacing: 8) {
                SettingsCardRow(
                    iconImage: "github",
                    iconColor: .primary,
                    title: AppLocalization.localized("RClickX on GitHub"),
                    subtitle: AppLocalization.localized("Star the project on GitHub to support development")
                ) {
                    HStack(spacing: 8) {
                        if let stars = updateManager.starCount {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow)
                                Text(stars.formatted(.number.notation(.compactName)))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }

                        Button(AppLocalization.localized("Star on GitHub")) {
                            updateManager.openRepositoryPage()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider().opacity(0.4)

                SettingsCardRow(
                    icon: "exclamationmark.bubble",
                    iconColor: .green,
                    title: AppLocalization.localized("Feedback & Issues"),
                    subtitle: AppLocalization.localized("Report bugs, request features, or share suggestions")
                ) {
                    Button(AppLocalization.localized("Open Issues")) {
                        updateManager.openIssuesPage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - 4. 开源协议与致谢卡片

    private var openSourceCard: some View {
        SettingsCard(
            title: AppLocalization.localized("Open Source & Acknowledgments"),
            icon: "doc.text",
            iconColor: .teal
        ) {
            VStack(spacing: 8) {
                SettingsCardRow(
                    icon: "scroll",
                    iconColor: .blue,
                    title: AppLocalization.localized("GNU General Public License v3"),
                    subtitle: AppLocalization.localized("Free and open source software. No warranty provided.")
                ) {
                    Button(AppLocalization.localized("View License")) {
                        openLicensePage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.4)

                SettingsCardRow(
                    icon: "link",
                    iconColor: .blue,
                    title: AppLocalization.localized("Based on RClick"),
                    subtitle: AppLocalization.localized("Original project created by Li Xu (wflixu)")
                ) {
                    Button(AppLocalization.localized("Original Project")) {
                        if let url = URL(string: "https://github.com/wflixu/RClick") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.4)

                SettingsCardRow(
                    icon: "hammer",
                    iconColor: .indigo,
                    title: AppLocalization.localized("Maintained by Cute-chen"),
                    subtitle: AppLocalization.localized("Modular architecture, menu designer, and macOS adaptations")
                ) {
                    Button(AppLocalization.localized("View Source")) {
                        updateManager.openRepositoryPage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func openLicensePage() {
        guard let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") else { return }
        NSWorkspace.shared.open(url)
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return AppLocalization.localized("Unknown")
    }

    func getBuildVersion() -> String {
        if let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return buildVersion
        }
        return AppLocalization.localized("Unknown")
    }
}

#Preview {
    AboutSettingsTabView()
        .environmentObject(UpdateManager(owner: "Cute-chen", repo: "RClickX", currentVersion: "1.0.0"))
}
