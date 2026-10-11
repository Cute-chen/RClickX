//
//  RClickApp.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//
import AppKit
import ApplicationServices
import Foundation
import SwiftUI
import SwiftData

import FinderSync
import os.log

extension NSNotification.Name {
    static let menuConfigShouldUpdate = NSNotification.Name("RClick.menuConfigShouldUpdate")
}

@main
struct RClickApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Key.showMenuBarExtra, store: .group) private var showMenuBarExtra = true

    @Environment(\.openWindow) var openWindow

    @AppLog(category: "main")
    private var logger
    let messager = Messager.shared

    @StateObject var appState = AppState.shared

    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        // MenuBarExtra 独立驻留状态栏，不定义默认 Window 场景，彻底消除冷启动窗口闪烁
        MenuBarExtra(
            "RClickX", image: "MenuBar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
                .environment(\.locale, languageManager.locale)
                .environmentObject(updateManager)
        }
        .defaultAppStorage(.group)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppDelegate")
    private var logger

    /// 惰性求值：`AppState.shared` 会一路构造到 `ModelContext(sharedModelContainer)`，
    /// 所以必须等 `init` 里 `bootstrap()` 成功之后才碰它。写成默认值属性会在 init 体
    /// 之前求值，正好把顺序反过来。
    lazy var appState: AppState = .shared
    var pluginRunning: Bool = false
    var heartBeatCount = 0

    let messager = Messager.shared
    var showMenuBarExtra = UserDefaults.group.bool(forKey: Key.showMenuBarExtra)
    var showInDock = UserDefaults.group.bool(forKey: Key.showInDock)
    var settingsWindow: NSWindow!

    override init() {
        super.init()

        // 先把共享库打开：失败就带着原因退出，而不是等到 AppState 构造时才崩。
        // 这是启动路径上唯一一处主动打开容器的地方，其余访问都指望它先跑过。
        do {
            try SharedDataManager.bootstrap()
        } catch {
            StartupFailure.presentAndExit(error)
        }
    }

    // MARK: - 重连机制状态

    /// 最大重试次数
    private let maxRunningMessageRetryCount: Int = 6

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("applicationDidFinishLaunching called")

        // 监听菜单配置更新通知（设置页 toggle 动作时触发）
        NotificationCenter.default.addObserver(
            forName: .menuConfigShouldUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sendMenuConfigurationUpdate()
            }
        }

        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        // 显式设置应用 Dock 图标，防止 macOS LaunchServices 缓存导致 Dock 图标未刷新
        if let appIcon = NSImage(named: "AppIcon") ?? NSImage(named: "Logo") {
            NSApplication.shared.applicationIconImage = appIcon
        }

        // 首次启动默认注册登录项，同时保留之后用户手动关闭的选择。
        configureLaunchAtLoginDefault()

        // 执行数据准备与通信就绪
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 确保 AppState 数据最新并立即广播至访达扩展
            appState.refresh()
            sendMenuConfigurationUpdate()
            messager.sendRunningNotification()

            // 只在首次启动完成前自动弹出新手引导。访达扩展是否开启由引导页展示，
            // 不应在用户完成引导后影响后续启动，否则每次启动都会重复打开窗口。
            let hasCompletedOnboarding = UserDefaults.group.bool(forKey: "hasCompletedOnboarding")
            if !hasCompletedOnboarding {
                WindowManager.shared.showOnboarding(appState: self.appState)
            }

            // Preload icons for all apps to improve performance
            Task { @MainActor in
                IconCache.shared.preloadIcons(for: appState.apps.map { $0.url })
            }

            // Register message handlers using type-safe API
            logger.info("Registering message handlers")
            messager.onExtensionMessage(.click) { [weak self] data in
                guard let self = self else { return }
                if let event: ClickEventPayload = messager.decodeSignedData(data) {
                    // 确认收到，供扩展判断主程序可通信性（操作成败另议）
                    messager.sendActionAck()
                    Task { @MainActor in
                        await self.handleClickEvent(event)
                    }
                } else {
                    logger.warning("Invalid click event data")
                }
            }

            messager.onExtensionMessage(.heartbeat) { [weak self] _ in
                guard let self = self else { return }
                logger.debug("Received heartbeat from extension")
                pluginRunning = true
                sendMenuConfigurationUpdate()
            }

            // 处理 Extension 请求菜单配置
            messager.onExtensionMessage(.requestConfig) { [weak self] _ in
                guard let self = self else { return }
                logger.info("Received menu config request from extension")
                self.sendMenuConfigurationUpdate()
            }

            // 启动心跳超时检测
            startHeartbeatMonitoring()
            // 启动 running 消息重试机制
            startRunningMessageRetry()

            sendObserveDirMessage()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendQuitNotification()
        logger.info("applicationWillTerminate")
    }

    /// 迁移旧的"开机登录"设置，并为新安装启用默认值。
    /// 用户在设置页关闭后，配置标记会阻止后续启动再次覆盖这个选择。
    private func configureLaunchAtLoginDefault() {
        let legacyKey = "launchAtLogin"
        let legacyDefaults = UserDefaults.standard
        let defaults = UserDefaults.group

        if legacyDefaults.object(forKey: legacyKey) != nil {
            if legacyDefaults.bool(forKey: legacyKey), !LaunchAtLogin.isEnabled {
                LaunchAtLogin.isEnabled = true
            }
            legacyDefaults.removeObject(forKey: legacyKey)
            defaults.set(true, forKey: Key.launchAtLoginConfigured)
            return
        }

        guard defaults.object(forKey: Key.launchAtLoginConfigured) == nil else { return }

        if !LaunchAtLogin.isEnabled {
            LaunchAtLogin.isEnabled = true
        }

        defaults.set(true, forKey: Key.launchAtLoginConfigured)
    }

    // MARK: - Message Handlers

    func sendObserveDirMessage() {
        let directories: [String] = []
        messager.sendRunningNotification(directories: directories)
        if !pluginRunning {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                sendObserveDirMessage()
            }
        }
    }

    func sendMenuConfigurationUpdate() {
        let config = RCRuntime.shared.menuService.buildConfig(from: appState)
        messager.sendMenuConfig(config)
        logger.debug("Sent menu configuration to extension: \(config.actions.count) actions, \(config.apps.count) apps")
    }

    func handleClickEvent(_ event: ClickEventPayload) async {
        logger.debug("Handling click event: \(event.itemId) type=\(event.itemType.rawValue) trigger=\(event.trigger.rawValue) target=\(event.target)")

        let actionService = RCRuntime.shared.actionService

        switch event.itemType {
        case .app:
            await actionService.openApp(rid: event.itemId, target: event.target)
        case .action:
            await actionService.actionHandler(rid: event.itemId, target: event.target, trigger: event.trigger.rawValue)
        case .newFile:
            await actionService.createFile(rid: event.itemId, target: event.target)
        case .commonDir:
            await actionService.openCommonDirs(target: event.target)
        }
    }

    // MARK: - 重连机制

    /// 心跳监控 Task（可取消）
    private var heartbeatMonitorTask: Task<Void, Never>?

    /// 启动心跳监控（15 秒超时检测）
    private func startHeartbeatMonitoring() {
        heartbeatMonitorTask?.cancel()
        heartbeatMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                if pluginRunning {
                    pluginRunning = false
                } else {
                    logger.warning("Heartbeat timeout detected, triggering reconnection")
                    performReconnection()
                }
            }
        }
    }

    /// 启动 running 消息重试机制（每 5 秒发送一次，持续 30 秒）
    private func startRunningMessageRetry() {
        Task { @MainActor in
            for retryCount in 0..<self.maxRunningMessageRetryCount {
                try? await Task.sleep(for: .seconds(5))
                guard !self.pluginRunning else { break }
                self.messager.sendRunningNotification()
                self.logger.debug("Sending running message retry \(retryCount + 1)/\(self.maxRunningMessageRetryCount)")
            }
            logger.debug("Running message retry completed")
        }
    }

    /// 执行重连：重置 pluginRunning 状态，等待心跳恢复
    @MainActor private func performReconnection() {
        logger.debug("Performing reconnection: requesting menu config from main app")
        pluginRunning = false
    }
}
