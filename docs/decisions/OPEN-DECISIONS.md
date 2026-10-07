# 未决登记册 · OPEN-DECISIONS

> 铁律：只追加 + 就地关闭（OPEN → RESOLVED，补 Resolution 字段）。已关闭的项可升格为 ADR。
> 每次 Phase 开始时，把未决项自动复现到工作上下文最前面，带「N 未决 + M 已决」汇总。

## 汇总

- **未决 2 · 已决 0**

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

## 已关闭

（暂无）