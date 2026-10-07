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

## OD-003 selftest 的 ioreg 交叉校验偶发失败（根因未定，禁止臆测）

| 字段 | 内容 |
|------|------|
| **Date** | 2026-10-08 |
| **Source** | 0.2.0 交付期间功能 A 工程师报告 `passed=17 failed=1`，初判为回归 |
| **Open Item** | `scripts/selftest.sh:177-185` `[4] cross-check against ioreg` 断言 GPU 利用率与 `ioreg` 读数 delta ≤ 30。失败原因**尚未确定**——不是已确认的缺陷，而是一个**已观测两次、机制不明的偶发事件** |
| **Related Constraints** | CI 的 selftest job 只跑 quick 模式（`[5]` 需 `--full`）；CONTRIBUTING 要求 PR 里贴 `failed=0`，故偶发失败会被误读为功能改动引入的回归 |
| **Current Leaning** | **不改代码。** 两种机制解释都已被实测推翻（见下方裁决记录），任何修复方向此刻都是猜测 |
| **Blocked By** | 触发条件未知。需先复现——在不同时段、不同负载下采样，捕获失败现场并记录当时的 GPU 活动 |
| **Resolves When** | 有人复现出失败并定位到确定机制后，再决定是 skip、放宽阈值还是修正断言。**必须独立成commit**，不得混入功能改动 |
| **Status** | OPEN — 根因未定 |

### 已排除的解释（勿重复走）

**解释一：「两个数据源采样时刻不同导致抖动」——已推翻。**
两者读的是**同一个 registry key**（`GPUReader.swift:11` 的 `Device Utilization %`，即 ioreg 打印的那个）。实测同一时刻成对采样，delta 稳定在 **2–7**，不是 30–60。

**解释二：「`ioreg` 会随机跳到 0，造成 delta 71+」——未复现。**
高频采样 75 次（3 轮 × 25），`ioreg` 稳定在 66–89，`0` 一次都没出现。仅在早前某轮低负载时段出现过一次 `0`（30 次采样里 1 次）。

### 实测记录

| 采样方式 | 结果 |
|---|---|
| `ioreg` 单独，10 次 @0.2 s | 首次观测到含`0` 与 `83`，范围 0–83 |
| `ioreg` 单独，40 次连续 | 66–83，**无 0** |
| `ioreg` 单独，3 轮 × 25 次 | 均值 77 / 79 / 81，**无 0** |
| `ioreg` vs heatpeek 成对，5 次 | delta 2–7 |
| `scripts/selftest.sh` 连跑 6 次 | delta 0–6，阈值 30 余量充足 |

### 唯一确定的事实

`selftest.sh:177` 的哨兵值把 `gpuUtilizationPercent` 为 `null` 的情况映射成 `-1`，而 `181` 行计算 `abs(-1 - IOREG)` 得到 71–76，**必然超过阈值 30**。因此**若 GPU 源确实不可用，这条断言 100% 失败**——这是代码里一条真实存在的确定性路径，只是尚无证据表明它就是那两次偶发失败的原因。

### 裁决记录（项目总监 2026-10-08，经两轮修正）

**第一版诊断错误**：初判根因为「ioreg 自身抖动」，并据此给出候选方案①「`ioreg` 返回 0 时 skip」。复核中发现该解释与实测矛盾——若真是随机抖动，成对采样不应稳定在 delta 2–7。

**第二版仍不成立**：QA 提出根因是哨兵值 `-1` 未被 skip 处理。这一判断指出了一个真实缺陷（见「唯一确定的事实」），但把它当作那两次偶发失败的原因同样缺乏证据——本机 `unavailable` 始终为空，`gpuUtilizationPercent` 从未为 `null`。

**结论**：一个观测了两次的偶发事件，两种解释都无法复现支撑。**登记册记录根因未定，比记录一个错误根因更有价值**——错误根因会误导下一个照着它修的人。放宽阈值更是危险方向：`delta≤30` 是本仓库唯一防止GPU 读数整体偏移的检查，为一次未定位的偶发失败放宽它，等于用真回归的检出能力换一次假警报的消除。

**为何仍要登记**：功能 A 工程师在 `make test` 看到 `failed=1` 时若未深究，就会误判为自己引入了回归并回头改坏代码。这种「测试自身的脆弱性被误读为实现缺陷」值得留档。

---

## 已关闭

（暂无）