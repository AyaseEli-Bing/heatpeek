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
| AC-11 | A | While 用户执行 `--help` / `-h` / `--version` 与任何其他 flag 的组合，系统**必须**打印 help 或版本并退出 0，**不得**进入参数校验 | P1 |

### AC-11 补充说明（2026-10-08 由 QA 验收发现后补入）

`main.swift` 中 help/version 的短路发生在 `parseOptions` **之前**，因此 `-h --json` 打印 help 并退出 0，`--json` 缺 `--once` 的校验不会执行到；同理 `--nonsense --help` 也退出 0，掩盖了未知参数。

**这不是缺陷，是所有 CLI 的通行做法**（`git --help --badflag` 同样返回 0），且 0.1.0 的 `--help` 本就退出 0，改动它会破坏兼容性。故定为P1 契约固化项：把「碰巧如此」升级为「契约如此」，并由 selftest 断言锁住。若将来要改，必须走 Spec 变更流程。

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
| 2026-10-08 | 补AC-11（flag 优先级契约）与 §14 文档一致性修正 | 独立验收发现契约未锁定、Spec 自身数字与章节序有误 | selftest.sh / 本文档 |

## 14. 文档一致性修正（2026-10-08 独立验收后补）

§13 原声明的影响范围遗漏了本次流程改进产出的文件。实际改动全集为：

| 文件 | 归属 | 性质 |
|------|------|------|
| `Sources/heatpeek/main.swift` | 功能 A | 功能代码 |
| `Sources/HeatPeekCore/Formatting.swift` | 功能 B | 功能代码 |
| `Tests/HeatPeekCoreTests/ThresholdTests.swift` | 功能 B | 功能代码 |
| `scripts/selftest.sh` | 功能 A + AC-11 | 门禁脚手架 |
| `README.md` / `CHANGELOG.md` | A + B | 文档（同一 commit 内同步，CONTRIBUTING 要求） |
| `docs/spec-0.2.0.md` | 流程 | 本文档 |
| `docs/verify-0.2.0.sh` | 流程 | 一次性验收工具，与长期资产 `scripts/selftest.sh` 分工不同 |
| `docs/decisions/OPEN-DECISIONS.md` | 流程 | 未决登记册 |
| `scripts/emoji-scan.pl` | 流程 | 落实团队 P0-1 emoji 门禁，因 BSD grep 无 `-P` |

### 引用测试数字时必须注明口径

两个数字来自**不同工具**，含义完全不同：

| 数字 | 来源 | 含义 |
|------|------|------|
| `passed=23` | `make test` → `scripts/selftest.sh` | **shell 断言条数**（CLI 契约、JSON 结构、量程合理性、ioreg 交叉校验） |
| `Executed 25 tests` | `make test` → `swift test` | **XCTest 用例数**（Formatting / SampleCache / Threshold 单元测试） |

0.2.0 交付时分别为 **23 与 25**。PR 描述中引用任一数字都须注明口径，否则会低估测试覆盖。

### 写入文档的数字必须与实现同步

这条纪律来自本次的一个真实缺陷：上表原写「20 与 25」，而它旁边那句「引用时请注明口径」本身就是防止误读的说明——**一段用来解释规则的文字，自己内部却躺着一个失效的数字**。原因是先写下该节（当时 selftest 18→20），随后又补了 AC-11 的 3 条断言（20→23），只更新了代码。

规则：**文档中出现可量化的计数（断言数、用例数、文件数）时，若同一批次改动会改变该计数，必须在同一次改动内同步文档中的引用。** 数字要尽量拆到各自独立的表格行，不要把两个数字并置进一句话——并置时只更新其中一个的概率远高于分开更新。

**markdownlint 不检查章节编号，也不会发现数字过期。** 本次两个文档缺陷（断言数过期、章节序号断裂）CI 全部漏过，只能靠独立复核。

### 复核方法：正向通过不能证明断言有效

本次验收用变异测试（mutation testing）替代「跑一遍绿了就算过」。做法是故意让被测行为退化，确认测试**真的失败**，再恢复。五个变异体及捕获者：

| 变异 | 捕获者 |
|------|--------|
| 抽掉告警标记的三元表达式 | 4 个用例 / 6 处断言 |
| 标记加到全部四个字段 | 2 个用例 / 5 处断言 |
| stderr 退化成单行 `boom` | 2 条新断言 |
| stderr 保留原因但丢掉 help | 仅 usage 那条断言 |
| help 短路改成 `if false && (...)` | AC-11 断言 |

两个关键结论：

1. **变异要拆细。** 第四条变异证明「原因」与「help」是两半独立断言；若当初写成 `grep -qE 'requires --once|Usage:'` 一条，这个变异体会静默通过——那才是真形式主义。
2. **正向通过不证明有效。** 第三轮前我只验证了「新加的断言在正常代码下通过」就宣布锁住契约；反向变异让断言真的报错后，才算证明它会在有人改坏行为时失败。

### 多 agent 并发改同一仓库时的观测纪律

本次出现过一次误报：并行提交期间，某文件一度从 `git diff` 中消失。这不是回退，是并发写入的瞬态窗口。

**纪律：任何「文件消失了 / 内容回退了」的告警，必须先连续采样确认再上报，不可直接判为回退。** 手段有三：间隔数秒连续采样三次、比对 `git show HEAD:<path>` 的 blob sha 与工作树版本、检查是否有并行提交在进行。

同理适用于协作中的任何陈述——**若向他人声称「已写入某文件」，必须以文件内容为准，而非以自己的意图为准。** 本次评审中出现过三条「已落地」但仓库里查无实据的承诺（其中两条是数字同步纪律、一条是本文这条观测纪律），它们只存在于对话里，下一个 agent 读不到，等于没写。

### 登记未决项时，根因不确定就写「不确定」

本次评审把一条未决项的根因改了两次，两个版本都不成立：

- 初判「两个数据源采样时刻不同造成抖动」——实测发现两者读的是**同一个 registry key**，成对采样 delta 稳定在 2–7
- 改判「哨兵值 `-1` 未被 skip 处理」——这确实指出一条真实存在的确定性失败路径，但没有证据表明它就是那两次偶发失败的原因

**两种解释都能自圆其说，也都不能复现。** 正确做法是记为「根因未定」并附上已排除的解释清单，让下一个人不必重走。

理由：**登记册的价值在于根因准确，否则它会把错误结论固化进档案。** 而一旦档案里的根因是错的，照着它修的人会修错方向——本例中，按「抖动」去放宽阈值，会用一个真回归的检出能力去换一次假警报的消除。结论会腐坏，规则不会。