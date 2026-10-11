//
//  ActionEntity.swift
//  RClick
//
//  Created by Claude on 2026/01/16.
//

import SwiftData
import Foundation

/// 动作实体 - 用于存储右键菜单动作配置
@Model
final class ActionEntity {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var script: String?
    var runInBackground: Bool = false

    init(id: String = UUID().uuidString,
         name: String,
         icon: String,
         isEnabled: Bool = true,
         sortOrder: Int = 0,
         script: String? = nil,
         runInBackground: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.script = script
        self.runInBackground = runInBackground
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 从 RCAction 转换
    convenience init(from action: RCAction) {
        self.init(
            id: action.id,
            name: action.name,
            icon: action.icon,
            isEnabled: action.enabled,
            sortOrder: action.idx,
            script: action.script,
            runInBackground: action.runInBackground
        )
    }

    // 预定义动作的工厂方法（默认开启高频动作）
    static func createDefaultActions() -> [ActionEntity] {
        return [
            ActionEntity(id: "copy-path", name: "Copy Path", icon: "doc.on.doc", isEnabled: true, sortOrder: 0),
            ActionEntity(id: "copy-name", name: "Copy File Name", icon: "doc.text", isEnabled: true, sortOrder: 1),
            ActionEntity(id: "open-terminal", name: "Open in Terminal", icon: "terminal", isEnabled: true, sortOrder: 2),
            ActionEntity(id: "open-editor", name: "Open in Code Editor", icon: "chevron.left.forwardslash.chevron.right", isEnabled: true, sortOrder: 3),
            ActionEntity(id: "create-symlink", name: "Create Symlink", icon: "link", isEnabled: true, sortOrder: 4),
            ActionEntity(id: "calc-sha256", name: "Calculate SHA256", icon: "number", isEnabled: true, sortOrder: 5),
            ActionEntity(id: "calc-md5", name: "Calculate MD5", icon: "number.circle", isEnabled: false, sortOrder: 6),
            ActionEntity(id: "delete-direct", name: "Delete Direct", icon: "trash", isEnabled: true, sortOrder: 7),
            ActionEntity(id: "airdrop", name: "AirDrop", icon: "paperplane", isEnabled: true, sortOrder: 8),
            ActionEntity(id: "hide", name: "Hide", icon: "eye.slash", isEnabled: false, sortOrder: 9),
            ActionEntity(id: "unhide", name: "Unhide", icon: "eye", isEnabled: false, sortOrder: 10),
        ]
    }
}
