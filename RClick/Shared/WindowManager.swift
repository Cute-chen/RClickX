//
//  WindowManager.swift
//  RClick
//
//  Created for RClickX window management and routing
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private init() {}

    func showOnboarding(appState: AppState) {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeFirstResponder(nil)
            return
        }

        let view = OnboardingView()
            .environmentObject(appState)
            .defaultAppStorage(.group)
            .environment(\.locale, LanguageManager.shared.locale)

        let hostingController = NSHostingController(rootView: view)
        hostingController.view.focusRingType = .none
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier(Constants.onboardingWindowID)
        window.title = AppLocalization.localized("Getting Started")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 680, height: 640))
        window.isReleasedWhenClosed = false
        window.center()
        self.onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nil)
    }

    func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
    }

    func showSettings(appState: AppState = .shared, updateManager: UpdateManager = .shared) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeFirstResponder(nil)
            return
        }

        struct SettingsContainer: View {
            @ObservedObject var appState: AppState
            @ObservedObject var updateManager: UpdateManager
            @ObservedObject var languageManager = LanguageManager.shared

            var body: some View {
                SettingsView()
                    .environmentObject(appState)
                    .environmentObject(updateManager)
                    .defaultAppStorage(.group)
                    .environment(\.locale, languageManager.locale)
                    .modelContainer(SharedDataManager.sharedModelContainer)
                    .frame(minWidth: 1000, minHeight: 600)
                    .sheet(isPresented: $updateManager.showUpdateSheet) {
                        UpdateView(updateManager: updateManager)
                    }
            }
        }

        let container = SettingsContainer(appState: appState, updateManager: updateManager)
        let hostingController = NSHostingController(rootView: container)
        hostingController.view.focusRingType = .none
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier(Constants.settingsWindowID)
        window.title = AppLocalization.localized("Settings")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1120, height: 660))
        window.isReleasedWhenClosed = false
        window.center()
        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nil)
    }

    func closeSettings() {
        settingsWindow?.orderOut(nil)
        settingsWindow?.close()
    }
}
