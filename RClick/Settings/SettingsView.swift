//
//  SettingsView.swift
//  RClick
//
//  Created by 李旭 on 2024/4/4.
//

import AppKit
import SwiftUI

enum Tabs: String, CaseIterable, Identifiable {
    case menuDesigner = "Designer"
    case general = "General"
    case about = "About"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .menuDesigner: "rectangle.3.group"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }

    /// 每个 tab 图标对应的圆角色块颜色
    var iconColor: Color {
        switch self {
        case .menuDesigner: .purple
        case .general: .blue
        case .about: .gray
        }
    }
}

struct SettingsView: View {
    @StateObject private var menuDesignerViewModel = MenuDesignerViewModel()
    @State private var selectedTab: Tabs = .menuDesigner
    @State private var isSidebarVisible: Bool = true
    @EnvironmentObject var appState: AppState
    @ObservedObject private var languageManager = LanguageManager.shared
    @State var showSelectApp = false

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            // 顶部品牌区：图标 + 名字 + 版本号
            VStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                Text("RClickX")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("v\(self.getAppVersion())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // tab 垂直排列，间距完全由代码控制（无原生 List 隐藏 inset）
            VStack(spacing: 4) {
                ForEach(Tabs.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(width: 180)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @State private var hoveredTab: Tabs? = nil

    /// 侧边栏单个 tab：直接调用 macOS 原生系统级材质（.regularMaterial / .ultraThinMaterial，底层为 NSVisualEffectView）
    private func sidebarButton(_ tab: Tabs) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab
        return Button {
            guard selectedTab != tab else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                // 原生图标底色
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tab.iconColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(appLocalized: tab.rawValue)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary : Color.secondary))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    // macOS 原生磨砂玻璃材质（直接调用系统 NSVisualEffectView 引擎）
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tab.iconColor.opacity(0.18))
                        }
                } else if isHovered {
                    // macOS 原生超轻薄磨砂玻璃材质悬停反馈
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredTab = hovering ? tab : nil
            }
        }
    }

    @ViewBuilder var detailView: some View {
        // 右侧内容：按需挂载当前选中的 Tab 视图，彻底消除侧边栏折叠/展开多 Tab 并发布局计算带来的卡顿掉帧
        Group {
            switch selectedTab {
            case .menuDesigner:
                MenuDesignerTabView(viewModel: menuDesignerViewModel)
            case .general:
                GeneralSettingsTabView()
            case .about:
                AboutSettingsTabView()
            }
        }
        .id(languageManager.refreshID)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                self.sidebar
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Divider()
                    .transition(.opacity)
            }

            self.detailView
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusEffectDisabled()
        .navigationTitle(AppLocalization.localized(selectedTab.rawValue))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help(isSidebarVisible ? AppLocalization.localized("Hide Sidebar") : AppLocalization.localized("Show Sidebar"))
                .keyboardShortcut("s", modifiers: [.command, .control])
                .focusEffectDisabled()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            menuDesignerViewModel.loadIfNeeded(using: appState)
        }
        // A failed write used to be invisible: the change stayed on screen but was
        // never stored, so the only way to notice was losing it on the next launch.
        .alert(
            Text(appLocalized: "Settings could not be saved"),
            isPresented: Binding(
                get: { appState.lastSaveError != nil },
                set: { if !$0 { appState.clearSaveError() } }
            )
        ) {
            Button(AppLocalization.localized("OK"), role: .cancel) { appState.clearSaveError() }
        } message: {
            Text(appState.lastSaveError ?? "")
        }
    }

    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return AppLocalization.localized("Unknown")
    }
}


#Preview {
    SettingsView()
}
