# Goalstar (Native SwiftUI)

纯 SwiftUI 实现的 Goalstar iOS 应用，按 Figma「设计稿」页视觉还原。

## 要求

- Xcode 16+
- iOS 17+
- 可选：`xcodegen`（`brew install xcodegen`，或本仓库 `tools/xcodegen`）用于从 `project.yml` 重新生成工程

## 运行

```bash
open Goalstar.xcodeproj
# 或（使用 Xcode 默认 DerivedData，勿在仓库内指定 -derivedDataPath）
xcodebuild -project Goalstar.xcodeproj -scheme Goalstar \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Bundle ID：`com.goalstar.native`（Widget：`com.goalstar.native.widgets`）

## Cloud Agent / Linux 开发环境

本仓库带有 `.cursor/environment.json` 与 `.cursor/install.sh`，用于在 Cursor Cloud Agent（Linux）
上自动安装开源 Swift 工具链（Swift 6.1.2）。

**注意**：Goalstar 是原生 iOS / SwiftUI 应用。完整编译与运行需要 macOS + Xcode + iOS 模拟器，
以及 Apple 专有框架（SwiftUI、SwiftData、UIKit、WidgetKit、ActivityKit、AppIntents、StoreKit、
UserNotifications）。这些在 Linux 上都不存在，因此 Cloud Agent 无法在此构建或运行完整 App。

Linux 上的 Swift 工具链可用于：

- 编辑器智能提示（`sourcekit-lsp`）
- 全仓库 Swift 语法校验（`swiftc -parse`）
- 编译并运行与平台无关（仅依赖可移植 `Foundation`）的纯逻辑源码

```bash
# 语法校验单个文件
swiftc -parse Goalstar/Views/TodayView.swift

# 编译并运行可移植逻辑源码（示例）
swiftc -o /tmp/smoke Shared/GSIconName.swift Goalstar/Domain/ProEntitlement.swift main.swift
```

## 上线发布

详见 [RELEASE.md](./RELEASE.md)（v2.0：Widget、Live Activity、本地通知、昵称编辑、Pro 终身买断）。

## 结构

- `Goalstar/App` — 入口与 Tab 根
- `Goalstar/Views` — 今日 / 目标 / 专注 / 数据 / 我的
- `Goalstar/Components` — 卡片、进度环、TabBar、FAB、创建 Sheet
- `Goalstar/Domain` — AppStore（打卡、专注计时、创建、Live Activity）
- `Goalstar/Services` — LiveActivityManager、NotificationScheduler
- `Goalstar/Persistence` — SwiftData + App Group（本机存储）
- `GoalstarWidgets` — 锁屏/主屏 Widget + Live Activity UI + App Intent
- `Shared` — Theme / Models / Formatters / AppConstants / FocusActivityAttributes


## 设计来源

https://www.figma.com/design/pfP8yOzq3pxVAkW2VuJH9P/Goalstar?node-id=0-1
