# App Store 审核回复 — Guideline 2.1（Information Needed，新账号信息补充）

> 适用提交：Goalstar v2.0（Bundle ID `com.goalstar.native`）
> 反馈性质：**Information Needed**，不是功能性硬拒。审核团队因开发者账号审核历史较少，需要补充材料才能继续审核。**一次性把 7 条信息答全 + 内购随版本提交 + 提供真机录屏**即可推进。

---

## 0. 问题定性与关键事实

Goalstar 是一款**本地优先**的目标 / 任务 / 专注管理 App。核对代码后确认以下事实（决定了大量审核问题「不适用」）：

| 事项 | 结论 | 依据 |
| --- | --- | --- |
| 账号系统（注册 / 登录 / 账号删除） | **无** | 全仓库无 `URLSession`/登录/注册代码；`ProfileView` 的 `authCard/authStatus` 指的是**本地通知权限**，非账号 |
| 用户生成内容（分享 / 社交 / 他人可见） | **无** | 目标 / 任务 / 专注 / 昵称仅存本机 SwiftData，不上传、不互通 |
| 网络后端 / 第三方 SDK / 分析 / 广告 / 追踪 | **无** | 无任何网络请求、无三方依赖；`PrivacyInfo.xcprivacy` 中 Tracking=false、CollectedDataTypes 为空 |
| 外部服务 | **仅 Apple StoreKit（内购支付）** | `StoreKitManager.swift` |
| 内购 | 一次性买断 NonConsumable `com.goalstar.native.pro.lifetime`（Goalstar Pro 终身），解锁「无限进行中目标」，免费版最多 3 个 | `AppConstants.swift` / `Configuration.storekit` / `ProEntitlement.swift` |
| 区域差异 | **无**，功能全球一致 | 无地理围栏 / 区域内容分支 |
| 受监管行业 / 受保护第三方素材 | **不涉及** | 内容均为自有 |

> 因此：审核信里关于「账号 / 登录凭据 / UGC 举报屏蔽」的条目对本 App 均为 **N/A**，需明确回复「不适用」，避免审核方等待并二次退回。

---

## 1. 逐条回复（可直接粘贴到 App Store Connect 的 Reply，建议英文）

> 说明：Apple 审核以英文沟通最稳。以下每条给出「中文要点」+「英文可粘贴文本」。请把 **第 8 节的 Notes 全文** 同时填入 App Store Connect → App Review Information → Notes 字段。

### Q1. 真机功能录屏（最新系统，从启动开始，展示典型流程；含访问付费功能）
中文要点：录屏在真机 + 最新 iOS 上，从冷启动开始，覆盖创建目标/任务、勾选与专注计时、数据页，并演示进入付费墙 → 购买 → 恢复购买 → Pro 解锁。无账号、无 UGC，故不含相关片段。分镜见第 4 节。

> A screen recording captured on a physical iPhone running the latest iOS is attached. It starts from a cold launch and shows the typical flow: create a goal, add today's tasks, check off a task, run a focus timer, and view the Data tab. It also demonstrates accessing the paid feature: opening the Pro paywall (via **Profile → Goalstar Pro**, and via the free-tier limit prompt when creating a 4th active goal), the purchase flow, and **Restore Purchase**, ending with Pro unlocked (unlimited active goals). The app has **no account system and no user-generated/social content**, so registration/login/deletion and content reporting/blocking flows are **not applicable**.

### Q2. App 用途与目标用户
> **Purpose.** Goalstar is a local-first goal, task, and focus companion. Users set long-term goals, break them into daily tasks, check them off, run a focus timer, and see progress on a Data dashboard, with optional Home/Lock-Screen Widgets, a focus Live Activity, and local reminder notifications.
> **Problem it solves.** People struggle to keep long-term goals on track and lack a lightweight, private daily execution list with visible progress.
> **Target audience.** Individuals who want personal productivity and self-management — students, freelancers, and professionals — who prefer a privacy-friendly, on-device tool.
> **Value.** Simple daily planning, focus timing, progress visualization, and privacy (all data stays on device; no account, no tracking).

### Q3. 设置与访问主要功能的说明（含登录凭据 / 样例文件）
> **No login is required and no account is used**, so no demo credentials or sample files are needed. The app is fully usable immediately after install.
> - **Today tab:** create a goal or task via the **+ (FAB)**; tap a task to check it off.
> - **Goals tab:** view/manage active goals (free tier allows up to 3 active goals).
> - **Focus tab:** start a countdown focus session; finishing can auto-complete the linked task.
> - **Data tab:** aggregated stats from local data.
> - **Profile tab:** edit nickname, manage local notification permission, and open **Goalstar Pro**.
> - **Widgets / Live Activity / local notifications** are optional and configured on-device.

### Q4. 外部服务 / 工具 / 平台清单
> The app uses **only Apple StoreKit** for In-App Purchase (payment handled by Apple). There are **no third-party services**: no external data providers, no authentication service, no third-party payment processor, no AI services, and no analytics/advertising/tracking SDKs. All user content is stored locally on device using Apple SwiftData (no iCloud/CloudKit sync, no custom server).

### Q5. 区域差异
> The app's features and content are **identical across all regions**. There is no geofencing and no region-specific content. Only the In-App Purchase price is localized automatically by the App Store per storefront.

### Q6. 受监管行业 / 受保护第三方素材
> **Not applicable.** The app does not operate in a highly regulated industry and does not include protected third-party material. All content and assets are original/owned by us.

### Q7. 内购概览 + 如何导航到购买流程
> **What can be purchased.** A single non-consumable, one-time purchase — **Goalstar Pro (Lifetime)**, product ID `com.goalstar.native.pro.lifetime`. It unlocks **unlimited active goals** (the free tier is limited to 3 active goals). It is a one-time purchase, **not** an auto-renewing subscription, and is restorable on the same Apple ID.
> **How to reach the purchase flow.**
> 1. **Profile tab → "Goalstar Pro"** → the paywall shows the price, **"Purchase Lifetime Pro"**, and **"Restore Purchase"**.
> 2. Or, when creating a **4th active goal** on the free tier, the upgrade paywall is presented automatically.

---

## 2. 逐条修复 / 准备动作清单

| # | 动作 | 负责区域 | 关键点 |
| --- | --- | --- | --- |
| 1 | 录制真机录屏并上传到 ASC 回复 | 元数据 | 见第 4 节分镜；最新 iOS、从启动开始、含内购 |
| 2 | 将 Q1–Q7 + 第 8 节 Notes 填入 **App Review Information → Notes** | 元数据 | 供本次与后续提交复用 |
| 3 | **内购随版本一起提交**（Guideline 3.1.1） | ASC 配置 | 见第 3 节，**很可能是本次卡点之一** |
| 4 | 更新 App Store 截图为**真实使用界面**（Guideline 2.3.3） | 元数据 | 不能只放启动屏 / 标题图 / 空态 |
| 5 | 确认 **App Group 已在 Developer Portal 启用**并重签 profile | 工程 / 证书 | 否则审核真机启动即 **SIGKILL**，触发 2.1 崩溃退回，见第 5 节 |
| 6 | 签署 **Paid Applications Agreement** | ASC 账户 | 否则内购不可售、拉不到商品 |
| 7 | 用 **Sandbox 账号**真机自测购买 / 恢复 | 测试 | 复现审核环境 |

---

## 3. 内购必须随版本提交（Guideline 3.1.1）—— 重点

新 App **首次提交时，内购项目必须与 App 版本绑定并一起提交审核**，否则审核方看不到可售的内购，Q7 无法验证，且会触发 3.1.1。

操作：
1. App Store Connect →「功能 / App 内购买项目」创建 **Non-Consumable**，Product ID 必须与代码一致：`com.goalstar.native.pro.lifetime`。
2. 填写内购的**显示名称、描述、审核截图**（付费墙截图，含价格 + 购买 + 恢复购买按钮）。
3. 内购状态需为 **"Ready to Submit"**。
4. 在**本次 App 版本页面**，将该内购**加入本次提交**（版本页的 In-App Purchases 区块勾选/关联），与 App 二进制**一起提交**。
5. 已签署 Paid Applications Agreement，否则内购无法进入可售状态。

> 代码侧无需改动：`Configuration.storekit` 仅用于本地测试；真机 / 审核走 App Store Connect 的真实内购。ID 已与 `Shared/AppConstants.swift` 的 `proLifetimeProductID` 一致。

---

## 4. 真机录屏分镜脚本（建议 60–90 秒）

在真机（最新 iOS）上，**先删除旧安装再全新安装**，然后：

1. **冷启动**：点击桌面图标启动，展示启动屏 → 今日页（空态，昵称「朋友」）。
2. **创建目标**：点 **+** → 新建目标（填名称/emoji/天数）→ 保存，回到今日/目标页看到目标。
3. **创建任务并勾选**：+ → 新建今日任务 → 勾选完成（展示状态变化）。
4. **专注计时**：进入「专注」Tab → 开始一个短时专注 → 结束（可展示自动完成任务）。
5. **数据页**：切到「数据」Tab，展示真实聚合统计。
6. **访问付费功能（必需）**：
   - 路径 A：连续创建目标至第 4 个 → 自动弹出升级页；或
   - 路径 B：「我的」Tab → **Goalstar Pro** → 付费墙。
   - 展示**价格**、点击 **购买终身 Pro**（用 Sandbox 账号完成 Apple 支付弹窗）→ 购买成功 → 返回可见 Pro 已开通、目标数量限制解除。
   - 再展示 **恢复购买** 按钮（可选，说明换机可恢复）。
7. 结束录制。

> 注意：录屏中出现的都是真机真实界面；不要用模拟器、不要只录启动屏。

---

## 5. 真机崩溃隐患（Guideline 2.1 Bugs & crashes）—— 必查

`RELEASE.md` 与 `project.yml` 已明确：主 App 与 Widget 都声明了 App Group `group.com.goalstar.native`。**若 Team `A47KHX4UCC` 未在 Apple Developer → Identifiers 为两个 App ID 勾选该 App Group 并重新生成/下载 Provisioning Profile，真机会在启动时 SIGKILL（无 Swift 崩溃栈）。** 模拟器不强制校验，因此本地模拟器测试可能「看起来正常」，而审核真机直接闪退 → 触发 2.1 崩溃退回。

提交前务必：
1. Developer Portal 为 `com.goalstar.native` 与 `com.goalstar.native.widgets` 均启用 App Groups，勾选 `group.com.goalstar.native`。
2. 重新生成 / 下载 Provisioning Profile，Xcode 两个 target 使用 Automatic Signing（Team `A47KHX4UCC`）。
3. 在**真机**上安装 Archive 版本，确认主 App + Widget 均正常，不闪退。

---

## 6. 截图（Guideline 2.3.3）

- App Store 截图必须展示**真实使用中的界面**（今日页有内容、目标页、专注页、数据页、付费墙），**不能**只放启动屏、标题艺术图或空态。
- 建议 6.9 寸竖屏至少 4–6 张，参照 `docs/app-store-screenshots.md`。

---

## 7. 提交前自检清单

- [ ] Q1–Q7 回复已写好；第 8 节 Notes 已填入 App Review Information → Notes
- [ ] 真机录屏已录（最新 iOS、从启动开始、含内购购买 + 恢复）
- [ ] 内购 `com.goalstar.native.pro.lifetime` 状态 Ready to Submit，且**已加入本次版本一起提交**
- [ ] Paid Applications Agreement 已签署
- [ ] App Group 已在 Developer Portal 启用并重签 profile；真机不闪退
- [ ] App Store 截图为真实使用界面（非启动屏）
- [ ] Sandbox 账号真机验证：付费墙显示价格、购买成功后 Pro 生效、恢复购买可用
- [ ] 隐私问卷：仅本机存储、不追踪、无第三方 SDK、内购由 Apple 处理

---

## 8. App Review Information — Notes 字段（英文全文，直接粘贴）

```
Demo account: Not applicable. Goalstar has no account system and requires no login; it is fully usable immediately after install.

App purpose & audience: Goalstar is a local-first goal, task, and focus companion. Users set long-term goals, break them into daily tasks, check them off, run a focus timer, and track progress on a Data dashboard. Optional Home/Lock-Screen Widgets, a focus Live Activity, and local reminder notifications are included. Target audience: individuals who want private, on-device personal productivity (students, freelancers, professionals).

How to use main features: Today tab: tap "+" to create a goal or task; tap a task to complete it. Goals tab: manage active goals (free tier allows up to 3). Focus tab: start a countdown focus session. Data tab: local aggregated stats. Profile tab: edit nickname, manage local notification permission, and open Goalstar Pro.

External services: Apple StoreKit only (In-App Purchase, payment handled by Apple). No third-party services: no external data providers, no authentication service, no third-party payment processor, no AI services, and no analytics/advertising/tracking SDKs. All user data is stored locally on device (Apple SwiftData); there is no iCloud/CloudKit sync and no custom server.

User-generated / social content: None. All goals, tasks, focus records, and nickname stay on the device and are never shared or visible to other users. Therefore content reporting/blocking is not applicable.

Regional differences: None. Features and content are identical in all regions; only the IAP price is localized automatically by the App Store.

Regulated industry / protected third-party material: Not applicable. All content is original and owned by us.

In-App Purchase: One non-consumable, one-time purchase — "Goalstar Pro (Lifetime)", product ID com.goalstar.native.pro.lifetime — unlocks unlimited active goals (free tier limited to 3). Not an auto-renewing subscription; restorable on the same Apple ID. To reach it: Profile tab -> "Goalstar Pro" (shows price, "Purchase Lifetime Pro", and "Restore Purchase"); or it appears automatically when creating a 4th active goal on the free tier.

Privacy: The app does not collect personal data for advertising or analytics, does not track users, and does not use third-party SDKs.
```
