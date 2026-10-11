<p align="center">
  <a href="https://github.com/Cute-chen/RClickX/releases">
    <img src="./RClick/Assets.xcassets/AppIcon.appiconset/AppIcon@1x.png" alt="RClickX logo" width="128">
  </a>
</p>

<h1 align="center">RClickX</h1>

<p align="center">面向 macOS Finder 的右键菜单增强工具</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-6.x-ED523F.svg?style=flat" alt="Swift"></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/SwiftUI-✓-orange" alt="SwiftUI"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B-green" alt="macOS 14.0+"></a>
  <a href="https://developer.apple.com/xcode/"><img src="https://img.shields.io/badge/Xcode-16.4%2B-blue" alt="Xcode 16.4+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="GPLv3 license"></a>
</p>

RClickX 把常用的文件操作、应用启动器、新建文件模板和常用目录集中到 Finder 上下文菜单中，并提供可视化菜单编排和权限管理界面。

> **二次开发声明**<br>
> 本项目基于李旭（[@wflixu](https://github.com/wflixu)）的 [RClick](https://github.com/wflixu/RClick) 二次开发，保留原项目的开源说明与致谢，并根据 GPLv3 要求发布修改后的代码。RClickX 与原项目是两个独立项目。

## 📸 产品预览

### 可视化菜单设计器

RClickX 的核心界面：编排应用、动作、文件模板与常用目录，右侧实时预览 Finder 菜单，完成后点击「应用到访达」。

<p align="center">
  <a href="./img/设计页.png">
    <img src="./img/设计页.png" alt="RClickX 可视化菜单设计器与菜单预览" width="860">
  </a>
</p>

<p align="center"><sub>点击图片查看原图</sub></p>

<details>
<summary>查看三种工作流预设</summary>

<table>
  <tr>
    <td width="50%" align="center">
      <a href="./img/通用预设.png"><img src="./img/通用预设.png" alt="RClickX 通用预设" width="430"></a><br>
      <sub><b>通用预设</b> · 适合日常文件操作</sub>
    </td>
    <td width="50%" align="center">
      <a href="./img/开发者预设.png"><img src="./img/开发者预设.png" alt="RClickX 开发者预设" width="430"></a><br>
      <sub><b>开发者预设</b> · 终端、代码模板与开发工具</sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <a href="./img/办公预设.png"><img src="./img/办公预设.png" alt="RClickX 办公预设" width="430"></a><br>
      <sub><b>办公预设</b> · Office 文档与文件分享</sub>
    </td>
  </tr>
</table>

</details>

<details>
<summary>查看新手引导、通用设置与关于页</summary>

<table>
  <tr>
    <td width="50%" align="center">
      <a href="./img/新手引导页.png"><img src="./img/新手引导页.png" alt="RClickX 新手引导" width="360"></a><br>
      <sub><b>新手引导</b> · 启用扩展、授权目录、选择预设和语言</sub>
    </td>
    <td width="50%" align="center">
      <a href="./img/通用设置页.png"><img src="./img/通用设置页.png" alt="RClickX 通用设置" width="430"></a><br>
      <sub><b>通用设置</b> · 启动项、图标、语言和权限</sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <a href="./img/关于页.png"><img src="./img/关于页.png" alt="RClickX 关于页" width="430"></a><br>
      <sub><b>关于页</b> · 版本、更新检查和社区入口</sub>
    </td>
  </tr>
</table>

</details>

## ✨ 功能

- **开箱即用**：首次启动引导启用 Finder 扩展，并预先授权常用工作目录。
- **三种工作流预设**：提供通用、开发者和办公布局，可在新手引导或设计页中选择后继续自定义。
- **可视化菜单设计器**：拖拽调整顺序，创建多级子菜单和分隔线，自定义标题与 SF Symbols 图标，并实时预览菜单结构。
- **应用启动器**：自动识别已安装的 Ghostty、Warp、iTerm2、Terminal、Cursor、VS Code、Zed 和 Sublime Text。
- **文件操作**：复制文件名、复制完整路径、创建符号链接、计算 SHA-256；MD5 可作为独立动作启用。
- **新建文件**：从模板创建 `.txt`、`.json`、`.md`、`.docx`、`.pptx`、`.xlsx`、`.pages`、`.key` 和 `.numbers` 文件，也可以拖入现有文件创建模板。
- **系统辅助**：直接删除（绕过废纸篓）、AirDrop、隐藏/显示文件，以及快速访问常用目录。
- **按文件夹授权**：文件操作使用 macOS security-scoped bookmarks 保存授权，不依赖 Full Disk Access。
- **自动更新**：关于页面可以检查 GitHub Releases，并在有新版本时提示更新。
- **深色模式**：界面和 Finder 菜单图标适配 macOS 外观。

## 🏗 架构

| 组件 | 目录 | 职责 |
| --- | --- | --- |
| 主程序 | `RClick/` | SwiftUI 设置界面、状态管理、权限、配置持久化和文件操作 |
| Finder 扩展 | `FinderSyncExt/` | 在 Finder 中读取当前目标并渲染右键菜单 |
| 共享代码 | `Shared/` | 菜单模型、动作定义、本地化和进程间消息模型 |

两个进程通过 `DistributedNotificationCenter` 通信，配置和 SwiftData 数据通过 App Group 共享。扩展未运行或主程序未启动时，Finder 菜单会显示相应状态提示。

## 📦 安装

1. 从 [Releases](https://github.com/Cute-chen/RClickX/releases) 下载最新的 `RClickX-vX.Y.Z.dmg`。
2. 打开 DMG，将 **RClickX.app** 拖入 `Applications`。
3. 启动 RClickX，按新手向导启用 Finder 扩展。
4. 在设置中添加需要执行文件操作的文件夹。

### 首次打开时的安全性提示

首次从 GitHub 下载并打开 App 时，macOS 可能显示 **“无法验证开发者”** 或阻止应用打开。这是 Gatekeeper 对下载应用的安全检查，可以按以下步骤继续：

1. 打开 **系统设置 → 隐私与安全性**。
2. 在“安全性”区域点击 **仍要打开**。
3. 在随后出现的确认窗口中再次确认打开 RClickX。

macOS 的系统设置名称可能随版本变化。macOS 26/27 通常位于 **系统设置 → 通用 → 登录项与扩展 → 扩展 → Finder**；较早版本位于 **隐私与安全性 → 扩展 → Finder 扩展**。首次授权后，RClickX 会保存文件夹书签，后续操作无需重复选择同一目录。

### Homebrew Cask

仓库包含 Cask 配方 `Casks/rclickx.rb`。将它发布到自己的 tap 后，可以按 tap 名称安装；配方尚未发布到 tap 前，建议使用 GitHub Release DMG。

## 🔧 从源码构建

### 环境要求

- macOS 14.0 或更高版本
- Xcode 16.4 或更高版本
- Apple Silicon 构建脚本默认使用 `arm64`
- Finder 扩展正常运行需要有效的开发者签名；未签名构建适合编译和单元测试验证

```bash
git clone https://github.com/Cute-chen/RClickX.git
cd RClickX
open RClick.xcodeproj
```

无签名环境下验证编译和测试：

```bash
xcodebuild build \
  -project RClick.xcodeproj \
  -scheme RClick \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY='' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project RClick.xcodeproj \
  -scheme RClick \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY='' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

本地生成 DMG、ZIP 和 SHA-256 校验文件：

```bash
./scripts/build-dmg.sh --config Release
```

产物默认写入 `dist/`。未提供签名身份时使用 ad-hoc 签名，不能替代 Developer ID 签名和公证。

## 🧩 自定义菜单

在 **设置 → 设计** 中添加、排序或分组菜单项，完成后点击 **应用到访达**。设计页还可以查看生成的 `custom_menu.json`；该文件用于存储顶层项目、嵌套子菜单、分隔线和自定义标题。完整字段和示例见 [examples/README.md](examples/README.md)。

## 🌐 语言

README 与应用界面支持简体中文和英文。在新手引导或 **设置 → 通用 → 界面语言** 中选择 **跟随系统、简体中文或 English**。跟随系统时，中文系统使用简体中文，其他系统语言使用英文。

## 👥 致谢

- 原项目作者：李旭（[@wflixu](https://github.com/wflixu)）— [RClick](https://github.com/wflixu/RClick)
- 菜单树与外置卷监听：[@Juns-g](https://github.com/Juns-g)
- 法语、西班牙语与字符串目录贡献：[@Dam0rt](https://github.com/Dam0rt)、[@EliasMatDev](https://github.com/EliasMatDev)、[@P013onEr](https://github.com/P013onEr)
- Finder 监听稳定性修复：[@shoal-rat](https://github.com/shoal-rat)
- 其他代码与构建改进：[@chunyang-wen](https://github.com/chunyang-wen)、[@stors789](https://github.com/stors789)

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request。提交前请阅读 [贡献指南](CONTRIBUTING.md)、[安全策略](SECURITY.md)、[行为准则](CODE_OF_CONDUCT.md) 和 [更新记录](CHANGELOG.md)。

## 📜 开源协议

RClickX 按 [GNU General Public License v3.0](LICENSE) 发布。分发修改后的版本时，请保留 GPLv3 文本、原项目版权与致谢信息，并清楚标注修改内容。
