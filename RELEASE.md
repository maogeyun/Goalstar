# Goalstar 上线发布清单

## v2.0 产品闭环

- [x] 五 Tab 导航：今日 / 目标 / 专注 / 数据 / 我的
- [x] 今日三态：空态 / 主态 / 全部完成
- [x] 任务勾选、习惯打卡、专注倒计时与记录
- [x] FAB 创建目标/任务，空态默认打开「新建目标」
- [x] 任务播放 → 专注页联动，专注完成自动勾选任务
- [x] 数据页指标来自 SwiftData 真实聚合
- [x] 明日预览 Sheet
- [x] **锁屏 / 主屏 Widget「今日三件事」**（可勾选任务）
- [x] **专注 Live Activity**（锁屏 / Dynamic Island）
- [x] **iCloud CloudKit 同步**（SwiftData `.automatic` + App Group store）
- [x] **本地推送提醒**（任务 / 习惯可配置时间）
- [x] **昵称编辑**（UserProfile，随 iCloud 同步）
- [x] App 内隐私政策 + `docs/privacy-policy.html`
- [x] PrivacyInfo.xcprivacy 已编入工程

## 工程与构建

```bash
cd GoalstarNative
# 有 tools/xcodegen 或已 brew install xcodegen 时：
xcodegen generate
# 模拟器编译校验（不签名；使用默认 DerivedData，勿写进仓库）
xcodebuild -project Goalstar.xcodeproj -scheme Goalstar \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# 真机 / Archive（需 Automatic Signing + App Group / iCloud 能力已在 Developer Portal 配置）
./scripts/verify-release.sh
```

- Bundle ID: `com.goalstar.native`
- Widget: `com.goalstar.native.widgets`
- App Group: `group.com.goalstar.native`
- CloudKit: `iCloud.com.goalstar.native`
- 最低系统: iOS 17.0
- 版本: MARKETING_VERSION **2.0** (CURRENT_PROJECT_VERSION 1)

## Developer Portal 必做

1. 为 `com.goalstar.native` 开启 **App Groups**、**iCloud (CloudKit)**、**Push Notifications 非必需**（本期为本地通知）
2. 为 `com.goalstar.native.widgets` 开启 **App Groups**（同一 `group.com.goalstar.native`）
3. **Team `A47KHX4UCC`：在 Identifiers 为两个 App ID 勾选 App Group `group.com.goalstar.native`，并重新生成/下载 Provisioning Profile。** 若 entitlements 声明了该 Group 但 profile 未包含，真机会在启动时 SIGKILL（无 Swift 栈）；模拟器不强制校验。代码层无法捕获该 SIGKILL，仅能在 Group 容器不可用时回退到 Application Support。
4. 创建 CloudKit container `iCloud.com.goalstar.native`
5. Xcode 中对两 target 使用 Automatic Signing（Team `A47KHX4UCC`）

## App Store Connect 待办

1. **Archive**：Xcode → Product → Archive → Distribute App
2. **截图**：含 Widget / Live Activity 说明图（可选）
3. **元数据**
   - 名称：Goalstar
   - 副标题：把每一天画进自己的星图
   - 版本：2.0
   - 分类：效率 / 生活方式
4. **隐私政策 URL**：托管 `docs/privacy-policy.html`
5. **App 隐私问卷**：说明 iCloud 同步用户内容；不追踪；本地通知

## 已知后续（非本期）

- 远程 APNs 推送服务
- 深色模式完整适配
- 真机多设备 iCloud 冲突高级策略

## 提交前自检

- [ ] 真机安装：主 App + Widget Extension
- [ ] 添加锁屏 Widget，勾选任务后 App 内同步
- [ ] 开始专注 → Live Activity 出现；暂停 / 完成行为正确
- [ ] 修改昵称后今日问候更新，重启保留
- [ ] 开启任务提醒，到点收到本地通知
- [ ] 第二台设备（同 Apple ID）数据同步
- [ ] Archive 含 `GoalstarWidgets.appex` 与 `PrivacyInfo.xcprivacy`
