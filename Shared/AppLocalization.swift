//
//  AppLocalization.swift
//  RClick
//
//  Created by Codex on 2026/7/3.
//

import AppKit
import Combine
import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return AppLocalization.localized("Follow System")
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }
}

@MainActor
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    @Published public var currentLanguage: AppLanguage {
        didSet {
            applyLanguage(currentLanguage)
        }
    }

    /// 用于触发关联 SwiftUI 视图层级刷新
    @Published public var refreshID: UUID = UUID()

    public var locale: Locale {
        switch currentLanguage {
        case .system:
            let code = AppLocalization.currentLanguageCode()
            return Locale(identifier: code)
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }

    private init() {
        let suite = UserDefaults(suiteName: "group.com.cutechen.rclickx")
        let raw = suite?.string(forKey: "APP_LANGUAGE") ?? UserDefaults.standard.string(forKey: "APP_LANGUAGE") ?? AppLanguage.system.rawValue
        let resolved = AppLanguage(rawValue: raw) ?? .system
        self.currentLanguage = resolved
        if resolved == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    public func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
    }

    private func applyLanguage(_ language: AppLanguage) {
        let suite = UserDefaults(suiteName: "group.com.cutechen.rclickx")
        suite?.set(language.rawValue, forKey: "APP_LANGUAGE")
        UserDefaults.standard.set(language.rawValue, forKey: "APP_LANGUAGE")

        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .zhHans:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case .en:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }

        refreshID = UUID()
        objectWillChange.send()
    }
}

// `nonisolated` because lookup is thread-safe and the default main-actor isolation
// makes it unreachable from `LocalizedError.errorDescription`, which has to stay
// nonisolated.
nonisolated enum AppLocalization {
    static let tableName = "Localizable"
    private static let appGroupSuiteName = "group.com.cutechen.rclickx"
    private static let appLanguageKey = "APP_LANGUAGE"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var bundleCache: [String: Bundle] = [:]

    /// 获取当前生效的语言代码（优先读取 App Group/UserDefaults，跟随系统时按系统首选语言适配）
    static func currentLanguageCode() -> String {
        let suite = UserDefaults(suiteName: appGroupSuiteName)
        let saved = suite?.string(forKey: appLanguageKey) ?? UserDefaults.standard.string(forKey: appLanguageKey) ?? AppLanguage.system.rawValue
        if saved == AppLanguage.zhHans.rawValue || saved == AppLanguage.en.rawValue {
            return saved
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.lowercased().hasPrefix("zh") {
            return AppLanguage.zhHans.rawValue
        }
        return AppLanguage.en.rawValue
    }

    /// 获取对应语言的 Bundle
    static func localizedBundle() -> Bundle {
        let lang = currentLanguageCode()
        lock.lock()
        defer { lock.unlock() }

        if let cached = bundleCache[lang] {
            return cached
        }

        for bundle in [Bundle.main, Bundle(for: LanguageManager.self)] {
            if let path = bundle.path(forResource: lang, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundleCache[lang] = bundle
                return bundle
            }
        }
        return .main
    }

    static func localized(_ key: String) -> String {
        let bundle = localizedBundle()
        // 使用哨兵值避免当英文 key == value 时误触发降级导致被回退为系统中文
        let notFoundSentinel = "\u{0}"
        let result = bundle.localizedString(forKey: key, value: notFoundSentinel, table: tableName)
        if result == notFoundSentinel {
            return key
        }
        return result
    }
}

extension Text {
    init(appLocalized key: String) {
        self.init(AppLocalization.localized(key))
    }
}
