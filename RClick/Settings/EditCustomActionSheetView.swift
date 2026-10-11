//
//  EditCustomActionSheetView.swift
//  RClick
//
//  Created by Claude on 2026/10/11.
//

import SwiftUI
import AppKit

struct EditCustomActionSheetView: View {
    let action: RCAction?
    let onSave: (RCAction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var icon: String
    @State private var script: String
    @State private var runInBackground: Bool

    private let quickIcons = [
        "terminal", "play.circle.fill", "bolt.fill", "sparkles",
        "wrench.and.screwdriver", "wand.and.stars", "curlybraces", "doc.text.magnifyingglass",
        "arrow.triangle.2.circlepath", "gearshape.fill", "link", "photo.fill"
    ]

    init(action: RCAction?, onSave: @escaping (RCAction) -> Void) {
        self.action = action
        self.onSave = onSave
        _name = State(initialValue: action?.name ?? "")
        _icon = State(initialValue: action?.icon ?? "terminal")
        _script = State(initialValue: action?.script ?? "")
        _runInBackground = State(initialValue: action?.runInBackground ?? true)
    }

    var isEditing: Bool { action != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: isEditing ? "slider.horizontal.3" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appLocalized: isEditing ? "Edit Custom Action" : "New Custom Action")
                        .font(.headline)
                    Text(appLocalized: "Create a custom Shell script to run on selected files or folders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 基本信息卡片
                    SettingsCard(title: AppLocalization.localized("Basic Information"), icon: "tag", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appLocalized: "Action Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField(AppLocalization.localized("e.g., Run Python Script / Compress Image"), text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(appLocalized: "Icon (SF Symbol)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    TextField("SF Symbol", text: $icon)
                                        .textFieldStyle(.roundedBorder)

                                    Image(systemName: icon.isEmpty ? "questionmark" : icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                        .frame(width: 30, height: 26)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
                                }

                                // 推荐图标快速挑选
                                HStack(spacing: 6) {
                                    ForEach(quickIcons, id: \.self) { sym in
                                        Button {
                                            icon = sym
                                        } label: {
                                            Image(systemName: sym)
                                                .font(.system(size: 11))
                                                .frame(width: 22, height: 22)
                                                .background(icon == sym ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                                                .foregroundStyle(icon == sym ? Color.accentColor : Color.secondary)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    // 2. 运行模式卡片
                    SettingsCard(title: AppLocalization.localized("Execution Mode"), icon: "gearshape.2", iconColor: .purple) {
                        Picker(AppLocalization.localized("Mode"), selection: $runInBackground) {
                            Text(appLocalized: "⚡️ Background Silent (Outputs copy to clipboard)").tag(true)
                            Text(appLocalized: "🖥 Terminal Window (Interactive execution)").tag(false)
                        }
                        .pickerStyle(.radioGroup)
                    }

                    // 3. 脚本内容卡片
                    SettingsCard(title: AppLocalization.localized("Shell Script"), icon: "terminal", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            // 快捷插入变量按钮
                            HStack(spacing: 6) {
                                Text(appLocalized: "Insert Variable:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Group {
                                    variableChip("$PATH", tooltip: "Full path of selected target")
                                    variableChip("$DIR", tooltip: "Directory of selected target")
                                    variableChip("$NAME", tooltip: "File name with extension")
                                    variableChip("$STEM", tooltip: "File name without extension")
                                    variableChip("$EXT", tooltip: "Extension without dot")
                                    variableChip("$FILES", tooltip: "All selected targets quoted")
                                }
                            }

                            // 脚本代码编辑框
                            TextEditor(text: $script)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 120)
                                .padding(6)
                                .background(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                )

                            // 说明
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appLocalized: "Supported Variables:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                Text("• $PATH: \(AppLocalization.localized("Selected file/directory full path"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("• $DIR: \(AppLocalization.localized("Directory containing the target"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("• $NAME: \(AppLocalization.localized("File name (e.g. sample.png)"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("• $STEM: \(AppLocalization.localized("File name without extension (e.g. sample)"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("• $EXT: \(AppLocalization.localized("File extension (e.g. png)"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("• $FILES: \(AppLocalization.localized("All selected files quoted with spaces"))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Actions
            HStack {
                Button(AppLocalization.localized("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(AppLocalization.localized("Save")) {
                    saveAction()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 580, height: 620)
    }

    private func variableChip(_ variable: String, tooltip: String) -> some View {
        Button {
            script += (script.isEmpty || script.hasSuffix(" ") ? "" : " ") + variable
        } label: {
            Text(variable)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(AppLocalization.localized(tooltip))
    }

    private func saveAction() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "terminal" : icon

        let finalAction = RCAction(
            id: action?.id ?? UUID().uuidString,
            name: trimmedName,
            enabled: action?.enabled ?? true,
            idx: action?.idx ?? 0,
            icon: trimmedIcon,
            script: trimmedScript,
            runInBackground: runInBackground
        )

        onSave(finalAction)
        dismiss()
    }
}
