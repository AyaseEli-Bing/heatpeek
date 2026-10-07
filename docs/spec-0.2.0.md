# Spec - heatpeek 0.2.0（增量 A+B）

> 生成日期：2026-10-08
> 路径判定：迷你路径。目标代码为 2 个 Swift 文件内约 20 行逻辑，无后端、无数据库、无部署环节，故不设PM / UI / DevOps 席位。
> 状态：已确认（用户于 2026-10-08 答复「按你说的做」）

---

## 1. 产品定义

- **一句话描述**：heatpeek 是 macOS Apple Silicon 的菜单栏传感器读数工具，本次为它补两处缺陷修复。
- **目标用户**：关注机器热状态的开发者（本仓库维护者本人即主要用户）。
- **核心问题**：
  1. CLI 契约有一个洞——`--json` 缺 `--once` 时不报错而是挂住GUI，脚本会超时而非失败。
  2. 过热告警**仅靠红色传达**，红绿色觉障碍用户与 macOS「区分无颜色」辅助功能开关下均无法感知。

## 2. MVP 范围（锁定）

| 优先级 | 功能 | 验收标准摘要 | 上游 issue |
|--------|------|------------|-----------|
| P0 | A. `--json` 无 `--once` → EX_USAGE | stderr 含提示与 help，退出码 64，不启动 GUI | #2 |
| P0 | B. 告警增加 `▲` 非颜色提示 | 告警时温度字段文本带 `▲`，未告警不带，颜色通道保留 | #4 |

## 3. 明确不做（Out-of-Scope — 锁定）

| 不做的功能 | 原因 | 何时考虑 |
|------------|------|----------|
| 风扇读取器扩展至 `F6Ac`/`F7Ac` | 本机仅 1 个风扇（实测 `Fan 1`），扩展属盲改，无法验证，违反项目「硬件声明须注明验证机器」原则 | 拿到 2+ 风扇机器后（issue #8） |
| 间隔选择器信息提示 | 改动仅为 UI 提示/文案，无技术含量，价值低于 A+B | issue #7 |
| 历史曲线/ 持久化 | 需突破现有 `Snapshot` 瞬时值架构、引入落盘与 NSMenu 绘图，工作量十倍于 A+B，违背项目克制定位 | v2.0 重新评估 |
| 把 `--json` 改为隐含 `--once` | 用户已明确选择「拒绝 + 退出 64」，保持 help 文本语义不变 | 用户后续变更需求 |
| 告警时每帧补齐菜单栏宽度 | 用户已明确选择接受宽度跳变（状态变化本应可见） | 同上 |

## 4. 技术架构（锁定，含版本锚定）

| 层 | 技术 | 实际版本 | 锁定原因 |
|----|------|---------|---------|
| 语言 | Swift | 6.x（`swift-tools-version: 6.0`） | 已在用 |
| 构建 | SwiftPM | 无外部 package 依赖 | CONTRIBUTING 明令零新增依赖 |
| UI | AppKit（`NSStatusItem` + `NSMenu`） | macOS 13 SDK | 已在用 |
|传感器 | IOKit / IOKit.HID / libIOReport（`dlopen`+`dlsym`） | 运行时解析 | 私有 API 无公开头，禁bridging header |
| 测试 | XCTest | 已在用 | 17 用例全绿 |
| 部署 | ad-hoc 签名 `.app`，无 notarize | — | 免费 Apple ID 无法签发 Developer ID |

**架构铁律（来自 CONTRIBUTING.md，违反即退回）**：`Sources/heatpeek` 是 `executableTarget`，测试 target **无法 import**。故一切可测逻辑必须落在 `Sources/HeatPeekCore`。`Formatting.swift` 中的 `TitleSegment` 正是此铁律的产物。

## 5. 接口清单（锁定）

无HTTP API。命令行契约变更如下：

| 调用 | 现状 | 变更后 | 退出码 |
|------|------|--------|--------|
| `heatpeek` | 启动 GUI | 不变 | — |
| `heatpeek --once` | 一次性读数 | 不变 | 0 |
| `heatpeek --once --json` | JSON 输出 | 不变 | 0 |
| `heatpeek --json` | **启动 GUI 并挂住** | stderr 提示 + help，**不启动 GUI** | **64** |
| `heatpeek --nonsense` | 提示 + help | 不变 | 64 |
| 数据源不可用 | 逐源报告原因 | 不变 | **0**（与崩溃区分） |

## 6. 数据结构（锁定）

**`Snapshot` 不新增字段。** `--json` 的 key 集合必须保持
`{timestamp, temperatures, gpuUtilizationPercent, gpuPowerWatts, fans, unavailable}` 不变。
`isWarning` 是渲染层概念，不进 JSON。

## 7. 页面清单（锁定）

| 界面 | 载体 | 变更 |
|------|------|------|
| 菜单栏读数 | `Formatting.titleSegments` → `StatusItemController.set` | 告警时温度字段文本加 `▲` 前缀；颜色逻辑不变 |
| 下拉菜单 | `StatusItemController.menuNeedsUpdate` | 不变 |
| CLI | `main.swift` | 新增 `--json` 组合校验 |

## 8. 设计 Token（锁定）

本项目为原生AppKit 菜单栏工具，**无设计 Token / 无 SVG 图标库 / 无色彩体系**。
`▲` 是 ASCII 三角字符（U+25B2），非 emoji、非图标库依赖，不触发 P0-1 图标规则。
告警色沿用既有 `NSColor.systemRed`，本次仅**增加**冗余通道，不替换。

## 9. 验收标准（锁定 — EARS 格式）

| 编号 | 功能 | EARS 验收标准 | 优先级 |
|------|------|--------------|--------|
| AC-01 | A | While 用户执行 `heatpeek --json`，系统**必须**向 stderr 写入提示与 help 文本且**必须**不启动 GUI | P0 |
| AC-02 | A | If `--json` 未与 `--once` 同时出现，系统**必须**以退出码 64 结束 | P0 |
| AC-03 | A | While 用户执行 `heatpeek --once --json`，系统**必须**保持现有 JSON 输出与退出码 0 不变 | P0 |
| AC-04 | A | While 用户执行 `heatpeek --nonsense`，系统**必须**保持现有 64 退出码行为不变（无回归） | P0 |
| AC-05 | B | If 最高温 `>=` 告警阈值且阈值非 nil，`titleSegments` 返回的温度段文本**必须**以 `▲` 开头 | P0 |
| AC-06 | B | If 未达阈值或阈值为 nil，温度段文本**必须**不以 `▲` 开头 | P0 |
| AC-07 | B | If 温度段 `isWarning` 为 true，其余三个字段**必须**不携带 `▲` | P0 |
| AC-08 | B | While 温度达任意值，`--json` 输出 key 集合**必须**与变更前完全一致 | P0 |
| AC-09 | B | If 温度段携带 `▲`，`isWarning` 标志**必须**仍为 true（颜色通道保留） | P0 |
| AC-10 | 全局 | While 提交前，`make test` **必须**输出 `failed=0` | P0 |

## 10. 边界与约束

- 最低 macOS 13，Apple Silicon（Intel 传感器 key 不同，未验证）
- 不新增任何外部依赖
- 不改动 `Snapshot.encode(to:)`（无新字段）
- 注释解释「为什么」，不解释「做了什么」，保持短句
- 提交信息：大写祈使句，无 `type:` 前缀，与 `git log` 一致
- **同步义务**：README + CHANGELOG 必须同 commit 更新；硬件声明注明 M4 / macOS 27
- 文档改动必须过 markdownlint（`MD013` 已关闭，其余默认规则开启）

## 11. 内嵌已知坑

| 坑 | 技术栈指纹 | 根因 | 修法 |
|----|-----------|------|------|
| `flt ` 小端序 | apple-smc | 按大端解 IEEE-754 会把 2530 RPM 读成 `7.3e-36`，表现像「风扇坏了」 | `.littleEndian` |
| IOReport 越界索引 | ioreport | `IOReportSimpleGetIntegerValue` 传越界 index 会 fault 而非返回 0 | 只读index 0 |
| executableTarget 不可测 | swiftpm | 测试 target 无法 import executableTarget | 逻辑下沉 HeatPeekCore |
| selftest 硬件断言 | shell | CI runner 无传感器 |硬件断言 **skip 而非 fail** |
| `timeout` 命令可用性 | shell | 曾误判 macOS 无 `timeout` 而绕道`set +e` | 实测 `/usr/bin/timeout` 存在且超时返回 124，可用 |

## 12. 端到端验证步骤

```bash
cd /Users/bing1111/heatpeek

# 1. 构建
make build

# 2. 功能 A 核心流：--json 缺 --once 应立即 64，不得挂住
.build/release/heatpeek --json 2>&1; echo "exit=$?"
# 断言：exit=64，且未启动 GUI（不出现 "…" 菜单栏占位）

# 3. 功能 A 无回归：正常组合仍为 0
.build/release/heatpeek --once --json | head -3; echo "exit=${PIPESTATUS[0]}"
# 断言：合法 JSON，exit=0

# 4. 功能 A 无回归：未知参数仍为 64
.build/release/heatpeek --nonsense >/dev/null 2>&1; echo "exit=$?"
# 断言：exit=64

# 5. 功能 B核心流：单元测试断言 ▲ 出现与不出现
swift test --filter ThresholdTests

# 6. 全量门禁
make test
# 断言：passed=N failed=0，skipped 数需在报告中说明

# 7. B 的 GUI 目视（可选，低阈值触发）
make app && open dist/HeatPeek.app   # 菜单里Warn at 选 80°C 观察 ▲
```

## 13. 变更记录

| 日期 | 变更内容 | 原因 | 影响范围 |
|------|---------|------|---------|
| 2026-10-08 | 初版，锁定 A+B 两功能范围与验收标准 | 用户确认「按你说的做」 | main.swift / Formatting.swift / 两处测试 / README / CHANGELOG |