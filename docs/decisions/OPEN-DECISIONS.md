# 未决登记册 · OPEN-DECISIONS

> 铁律：只追加 + 就地关闭（OPEN → RESOLVED，补 Resolution 字段）。已关闭的项可升格为 ADR。
> 每次 Phase 开始时，把未决项自动复现到工作上下文最前面，带「N 未决 + M 已决」汇总。

## 汇总

- **未决 3 · 已决 0**

---

## OD-001 `--version` 与 CHANGELOG 的版本语义分叉

| 字段 | 内容 |
|------|------|
| **Date** | 2026-10-08 |
| **Source** | 0.2.0 交付期间 QA 提出，初判为 P0 |
| **Open Item** | `CLI.version = "0.1.0"` 同时被 `--version`（构建版本）与 CHANGELOG 的 `## 0.1.0`（已发布版本）使用。改动进入 `## Unreleased` 后，二者语义分叉 |
| **Related Constraints** | CHANGELOG 已有 `## Unreleased` 段作为未发布改动的既定容器；`version` 常量不在 0.2.0 的 diff 内 |
| **Current Leaning** | 倾向不修复。判定 `## Unreleased` 为本次的正确语义，`0.1.0` 属存量债 |
| **Blocked By** | 存量设计债，非本次交付引入 |
| **Resolves When** | 上游 issue #6 落地时——届时配套加 selftest 断言（`--version` 必须等于 CHANGELOG 最新已发布版本）+ 改 CI，是独立的第三个变更 |
| **Status** | OPEN |

**裁决记录（项目总监 2026-10-08）**：
降级为非阻断。判P0 的标准是「功能或契约未达成」，不是「文档有瑕疵」。三条理由：① 本次两个功能条目正确落在 `## Unreleased`，符合项目惯例；② `version` 行不在本次 diff 内，未引入分叉；③ Spec 第 9 章 AC-01..AC-10 无一条涉及版本号。按过度设计护栏，未被要求的额外特性不标阻断。

**关联**：issue #6（selftest should fail when --version disagrees with CHANGELOG）、issue #11（已CLOSED，同类文档同步问题的先例——那次正是「文档与代码脱节」被判bug 并修复）

---

## OD-002 `scripts/selftest.sh` 在非 macOS 平台会崩

| 字段 | 内容 |
|------|------|
| **Date** | 2026-10-08 |
| **Source** | 0.2.0 交付期间 QA 提出，初判为 P0 |
| **Open Item** | 脚本第 15 行 `JOBS=$(sysctl -n hw.ncpu)` 在 Linux上无`sysctl -n hw.ncpu`（Linux `sysctl` 是 `sysctl(8)`，参数语法完全不同），配合 `set -euo pipefail` 会**直接崩在第 15 行**，而非优雅跳过。同理 `ioreg` 不存在于 Linux |
| **Related Constraints** | CI 当前仅在 `macos-latest` 运行 `.github/workflows/build.yml` 的 selftest job，暂无 Linux runner需求；`scripts/selftest.sh` 全仓库仅被该 job 调用 |
| **Current Leaning** | 暂不修。属**防御性加固**而非缺陷修复——当前无任何调用方会在非 macOS 平台执行它 |
| **Blocked By** | 无技术阻碍，纯优先级问题 |
| **Resolves When** | 出现下列任一情况：① 有人在 workflow 中加`runs-on: ubuntu-latest` 执行 selftest；② 脚本被外部项目引用；③ 维护者主动要求跨平台加固 |
| **Status** | OPEN |

**裁决记录（项目总监 2026-10-08）**：
降级为非阻断。依据：本项目 README 明确限定「macOS 13 or later on Apple Silicon」，传感器路径全为 IOKit/IOReport/AppleSMC 私有 API，**根本不存在 Linux 适配的可能**——脚本崩在第 15 行反而是快速失败，对一个永不跨平台的脚本是合理行为。加固它属于未被要求的额外特性。

**若将来要修，正确姿势**是在 `JOBS` 赋值前加平台守卫（如 `uname -s` 检测 + 降级为 `nproc` 或 `skip`），而非删改断言。

---

## OD-003 selftest 的 ioreg 交叉校验会偶发失败

| 字段 | 内容 |
|------|------|
| **Date** | 2026-10-08 |
| **Source** | 0.2.0 交付期间功能 A 工程师报告，初判为回归 |
| **Open Item** | `scripts/selftest.sh` `[4] cross-check against ioreg` 断言 GPU 利用率与 `ioreg` 读数delta ≤ 30，但两者存在采样时间差，高负载时会偶发失败（观测到 delta=61、32） |
| **Related Constraints** | CI 的 selftest job 只跑 quick 模式（`[5]` 需 `--full`），而 GPU 负载波动主要影响 `[4]`；CONTRIBUTING 要求 PR 里贴 `failed=0`，故偶发失败会被误读为本次改动引入的回归 |
| **Current Leaning** | 倾向修，但方法须先定。候选：① `ioreg` 返回 0 时按 skip 处理（对齐既有的「硬件断言跳过而非失败」策略）；② 多次采样取中位数；③ 放宽 delta 阈值 |
| **Blocked By** | 需实测确定 `ioreg` 与本机读数的真实分布，才能选阈值——拍脑袋改阈值会把真回归一起放过 |
| **Resolves When** | 有人专门实测 ioreg 抖动分布后择一实施。**必须独立成commit**，不得混入功能改动 |
| **Status** | OPEN |

**裁决记录（项目总监 2026-10-08）**：
本轮验证后确认**与 0.2.0 改动无关**，降级为独立问题。实测证据：间隔 0.2 s 连续采样 10 次，`ioreg` 自身两次读数就会剧烈波动（观测到同机`ioreg`=0 而紧接着一次=75、`ioreg` 稳定在 62–83 而本机读数 66–73），说明抖动源于两个数据源的采样时刻不同，非读数错误。

**为何仍要登记**：功能 A 工程师在 `make test` 看到 `passed=17 failed=1` 时，若未深究就会误判为自己引入了回归并回头改坏代码。这种「测试自身的脆弱性被误读为实现缺陷」值得留档。

---

## 已关闭

（暂无）