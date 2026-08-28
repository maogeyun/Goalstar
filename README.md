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

## 上线发布

详见 [RELEASE.md](./RELEASE.md)（v2.0：Widget、Live Activity、iCloud、本地通知、昵称编辑）。

## 结构

- `Goalstar/App` — 入口与 Tab 根
- `Goalstar/Views` — 今日 / 目标 / 专注 / 数据 / 我的
- `Goalstar/Components` — 卡片、进度环、TabBar、FAB、创建 Sheet
- `Goalstar/Domain` — AppStore（打卡、专注计时、创建、Live Activity）
- `Goalstar/Services` — LiveActivityManager、NotificationScheduler
- `Goalstar/Persistence` — SwiftData + App Group + CloudKit
- `GoalstarWidgets` — 锁屏/主屏 Widget + Live Activity UI + App Intent
- `Shared` — Theme / Models / Formatters / AppConstants / FocusActivityAttributes


## 设计来源

https://www.figma.com/design/pfP8yOzq3pxVAkW2VuJH9P/Goalstar?node-id=0-1
