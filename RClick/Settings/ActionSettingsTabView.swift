//
//  ActionSettingsTabView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/9.
//

import SwiftUI
import AppKit

struct ActionSettingsTabView: View {
    @EnvironmentObject var appState: AppState

    @State private var editingAction: RCAction?
    @State private var actionToDelete: RCAction?
    @State private var showCreateSheet = false

    let messager = Messager.shared

    var customActions: [RCAction] {
        appState.actions.filter { $0.isCustomScript }
    }

    var builtInActions: [RCAction] {
        appState.actions.filter { !$0.isCustomScript }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // MARK: - 1. 菜单行为卡片
                SettingsCard(
                    title: AppLocalization.localized("Menu Behavior"),
                    icon: "slider.horizontal.3",
                    iconColor: .blue
                ) {
                    SettingsCardRow(
                        icon: "folder.badge.gearshape",
                        iconColor: .blue,
                        title: AppLocalization.localized("Collapse actions menu"),
                        subtitle: AppLocalization.localized("Place action items inside an 'Actions' submenu in Finder")
                    ) {
                        Toggle("", isOn: $appState.foldActionsMenu)
                            .labelsHidden()
                            .onChange(of: appState.foldActionsMenu) {
                                NotificationCenter.default.post(name: .menuConfigShouldUpdate, object: nil)
                            }
                    }
                }

                // MARK: - 2. 自定义脚本动作卡片
                SettingsCard(
                    title: AppLocalization.localized("Custom Shell Actions"),
                    icon: "terminal",
                    iconColor: .orange,
                    subtitle: AppLocalization.localized("Extend Finder with your own bash/zsh shell scripts")
                ) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label(AppLocalization.localized("Add Custom Action"), systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } content: {
                    if customActions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.top, 8)

                            Text(appLocalized: "No Custom Shell Actions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(appLocalized: "Click 'Add Custom Action' to create scripts with $PATH, $DIR, and $FILES variables.")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(customActions) { action in
                                HStack(spacing: 10) {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.orange)
                                        .frame(width: 26, height: 26)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(action.displayName)
                                                .font(.system(size: 13, weight: .medium))

                                            StatusPill(
                                                text: action.runInBackground ? AppLocalization.localized("Background") : AppLocalization.localized("Terminal"),
                                                color: action.runInBackground ? .purple : .blue,
                                                icon: action.runInBackground ? "bolt.fill" : "terminal"
                                            )
                                        }

                                        if let script = action.script {
                                            Text(script)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    // Action buttons
                                    HStack(spacing: 12) {
                                        Button {
                                            editingAction = action
                                        } label: {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(.borderless)
                                        .help(AppLocalization.localized("Edit Action"))

                                        Button {
                                            actionToDelete = action
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .help(AppLocalization.localized("Delete Action"))

                                        Toggle("", isOn: Binding(
                                            get: { action.enabled },
                                            set: { newValue in
                                                var updated = action
                                                updated.enabled = newValue
                                                appState.updateAction(updated)
                                                messager.sendRunningNotification()
                                            }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .labelsHidden()
                                    }
                                }
                                .padding(10)
                                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                if action.id != customActions.last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }

                // MARK: - 3. 内置动作列表卡片
                SettingsCard(
                    title: AppLocalization.localized("Built-in Actions"),
                    icon: "bolt.square",
                    iconColor: .indigo,
                    subtitle: AppLocalization.localized("Configure which system actions appear in your Finder menu")
                ) {
                    Button(AppLocalization.localized("Restore Defaults")) {
                        appState.resetActionItems()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                } content: {
                    VStack(spacing: 0) {
                        ForEach(Array(builtInActions.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.indigo)
                                    .frame(width: 24, height: 24)
                                    .background(Color.indigo.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))

                                Text(item.displayName)
                                    .font(.system(size: 13, weight: .medium))

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { item.enabled },
                                    set: { newValue in
                                        var updated = item
                                        updated.enabled = newValue
                                        appState.updateAction(updated)
                                        messager.sendRunningNotification()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            }
                            .padding(.vertical, 8)

                            if index < builtInActions.count - 1 {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        // Sheets
        .sheet(isPresented: $showCreateSheet) {
            EditCustomActionSheetView(action: nil) { newAction in
                appState.addAction(newAction)
                messager.sendRunningNotification()
            }
        }
        .sheet(item: $editingAction) { action in
            EditCustomActionSheetView(action: action) { updatedAction in
                appState.updateAction(updatedAction)
                messager.sendRunningNotification()
            }
        }
        .confirmationDialog(
            AppLocalization.localized("Delete Custom Action"),
            isPresented: Binding(
                get: { actionToDelete != nil },
                set: { if !$0 { actionToDelete = nil } }
            ),
            presenting: actionToDelete
        ) { action in
            Button(AppLocalization.localized("Delete"), role: .destructive) {
                appState.deleteAction(id: action.id)
                messager.sendRunningNotification()
            }
            Button(AppLocalization.localized("Cancel"), role: .cancel) {
                actionToDelete = nil
            }
        } message: { action in
            Text(String(format: AppLocalization.localized("Are you sure you want to delete \"%@\"? This action cannot be undone."), action.displayName))
        }
    }
}
