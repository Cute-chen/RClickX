//
//  MenuBarView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    let messager = Messager.shared

    var body: some View {
        VStack {
            Button(action: actionOnboarding) {
                Image(systemName: "sparkles")
                Text(appLocalized: "Getting Started")
            }

            Button(action: actionSettings) {
                Image(systemName: "gearshape")
                Text(appLocalized: "Settings")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button(action: actionQuit) {
                Image(systemName: "xmark.square")
                Text(appLocalized: "Quit")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .id(languageManager.refreshID)
    }

    @MainActor
    private func actionOnboarding() {
        WindowManager.shared.showOnboarding(appState: AppState.shared)
    }

    @MainActor
    private func actionSettings() {
        WindowManager.shared.showSettings(appState: AppState.shared)
    }

    @MainActor
    private func actionQuit() {
        messager.sendQuitNotification()

        // 等一拍让菜单栏弹出面板收起，再退出。
        //
        // 这里唯一的抛出是任务被取消；用户点的是"退出"，不该因为一次取消就被留在这里，
        // 所以显式吞掉取消、继续走完 —— 而不是让错误悄悄丢掉（这条警告说的正是后者）。
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            NSApplication.shared.terminate(self)
        }
    }
}

#Preview {
    MenuBarView()
}
