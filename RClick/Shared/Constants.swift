//
//  Constants.swift
//  RClick
//
//  Created by 李旭 on 2024/9/25.
//

import Foundation


public enum Constants {
    static let HomedirPath = Utils.getRealHomeDir()
    /// The identifier for the settings window.
    static let settingsWindowID = "rclick-settings"
    /// The identifier for the onboarding window.
    static let onboardingWindowID = "rclick-onboarding"
    static let protectedDirs = [
        HomedirPath + "/Desktop/",
        HomedirPath + "/Desktop/danger/",
        HomedirPath + "/Applications/",
        "/Applications/",
        "/System/",
        "/Library/",
        "/Users/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/var/"
    ]
    static let appName = "RClickX"
    static let suitName = "group.com.cutechen.rclickx"
    static let mainAppBundleID = "com.cutechen.rclickx"
    static let extensionBundleID = "com.cutechen.rclickx.FinderSyncExt"

}
