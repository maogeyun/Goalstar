# Goalstar 上线发布清单

## v2.0 产品闭环

- [x] 五 Tab 导航：今日 / 目标 / 专注 / 数据 / 我的
- [x] 今日三态：空态 / 主态 / 全部完成
- [x] 首次安装无演示数据（默认昵称「朋友」；DEBUG 可用 `-seedDemo` 注入样例）
- [x] 任务勾选、专注倒计时与记录
- [x] FAB 创建目标/任务，空态默认打开「新建目标」
- [x] 任务播放 → 专注页联动，专注完成自动勾选任务
- [x] 数据页指标来自 SwiftData 真实聚合
- [x] 明日预览 Sheet
- [x] **锁屏 / 主屏 Widget「今日三件事」**（可勾选任务）
- [x] **专注 Live Activity**（锁屏 / Dynamic Island）
- [x] **本地推送提醒**（任务可配置时间）
- [x] **昵称编辑**（UserProfile，仅本机保存）
- [x] App 内隐私政策 + `docs/privacy-policy.html`
- [x] PrivacyInfo.xcprivacy 已编入工程
- [x] **Goalstar Pro 终身买断**（StoreKit 2 Non-Consumable，免费版最多 3 个进行中目标）

## 工程与构建

```bash
# 有 tools/xcodegen 或已 brew install xcodegen 时：
xcodegen generate
# 模拟器编译校验（不签名；使用默认 DerivedData，勿写进仓库）
xcodebuild -project Goalstar.xcodeproj -scheme Goalstar \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# 真机 / Archive（需 Automatic Signing + App Group 已在 Developer Portal 配置）
./scripts/verify-release.sh
```

- Bundle ID: `com.goalstar.native`
- Widget: `com.goalstar.native.widgets`
- App Group: `group.com.goalstar.native`
- 存储：本机 SwiftData（无 CloudKit / iCloud 同步）
- 最低系统: iOS 17.0
- 版本: MARKETING_VERSION **2.0** (CURRENT_PROJECT_VERSION 2)
- IAP: `com.goalstar.native.pro.lifetime`（Non-Consumable，本地测试见 `Goalstar/Configuration.storekit`）

## Developer Portal 必做

1. 为 `com.goalstar.native` 开启 **App Groups**（本期为本地通知，无需 Push Notifications / iCloud）
2. 为 `com.goalstar.native.widgets` 开启 **App Groups**（同一 `group.com.goalstar.native`）
3. **Team `A47KHX4UCC`：在 Identifiers 为两个 App ID 勾选 App Group `group.com.goalstar.native`，并重新生成/下载 Provisioning Profile。** 若 entitlements 声明了该 Group 但 profile 未包含，真机会在启动时 SIGKILL（无 Swift 栈）；模拟器不强制校验。代码层无法捕获该 SIGKILL，仅能在 Group 容器不可用时回退到 Application Support。
4. Xcode 中对两 target 使用 Automatic Signing（Team `A47KHX4UCC`）

## App Store Connect 待办

1. **Archive**：Xcode → Product → Archive → Distribute App
2. **截图**：按 [docs/app-store-screenshots.md](./docs/app-store-screenshots.md) 拍摄（6.9 寸竖屏 6 张；Widget / Live Activity 可选）
3. **元数据**
   - 名称：Goalstar
   - 副标题：把每一天画进自己的星图
   - 版本：2.0
   - 分类：效率 / 生活方式
4. **隐私政策 URL**：托管 `docs/privacy-policy.html`
5. **App 隐私问卷**：仅本机存储（不要勾选 iCloud 用户内容）；不追踪；本地通知；内购由 Apple 处理
6. **Paid Applications Agreement**：在 App Store Connect 签署付费应用协议
7. **内购商品**：创建 Non-Consumable `com.goalstar.native.pro.lifetime`（终身 Pro），价格在 ASC 配置
8. **提交 IAP 审核**（可与 App 版本一起）
9. **付费墙截图**：含价格、购买与恢复购买按钮（商店可选，审核备注必附；详见截图说明）

## 已知后续（非本期）

- 远程 APNs 推送服务
- 深色模式完整适配
- iCloud CloudKit 多设备同步（本期为本机存储）

## 提交前自检

- [ ] 删除 App 重装：今日为空态，昵称「朋友」，无演示目标/任务
- [ ] 真机安装：主 App + Widget Extension
- [ ] 添加锁屏 Widget，勾选任务后 App 内同步
- [ ] 开始专注 → Live Activity 出现；暂停 / 完成行为正确
- [ ] 修改昵称后今日问候更新，重启保留
- [ ] 开启任务提醒，到点收到本地通知
- [ ] Archive 含 `GoalstarWidgets.appex` 与 `PrivacyInfo.xcprivacy`
- [ ] 付费墙能显示 App Store 价格；购买 / 恢复购买后 Pro 生效
- [ ] 免费版第 4 个进行中目标会提示并打开升级页
