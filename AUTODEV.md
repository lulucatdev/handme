# AUTODEV — 自治开发协议

本文档定义 Handme 项目的机械化开发循环。人和 AI agent 共同遵守。

## 核心原则

**每个 claim 都有 proof。** 说"修好了"必须附 test pass 截图/输出。说"能编译"必须附 build log。没有机械证据的断言等于没说。

**底线只升不降。** Hard gate 一旦通过，后续提交不得打破。这是 compounding——代码库每天都比昨天更健康。

**卡住就喊人。** 同一个问题修 3 次还没过，停下来找人。不要暴力循环。

---

## The Loop

每个任务（无论大小）都走这个循环：

```
READ → IMPLEMENT → VERIFY → pass? → COMMIT
                     ↑        ↓ no
                     └── FIX ─┘
```

1. **READ** — 读任务描述、相关代码、上下文。不读就写 = 盲写。
2. **IMPLEMENT** — 写代码。尽量先写测试。
3. **VERIFY** — 跑全部机械检查（见下方 Gates）。
4. **判断** — 全部 pass → COMMIT。任何 fail → FIX 后重新 VERIFY。
5. **COMMIT** — 原子提交，message 说 why 不说 what。

**FIX 上限：同一个 gate 连续 fail 3 次 → 停下来，记录问题，找人。**

---

## Hard Gates（必须通过，不可跳过）

这些是二元的：过或不过。任何一个 fail 都不能提交。

| Gate | 命令 | 通过标准 |
|------|------|----------|
| **Build** | `swift build` | exit 0，零 error |
| **App Build** | `xcodebuild -project Handme.xcodeproj -scheme Handme build` | exit 0，零 error |
| **Tests** | `swift test` | 全部 pass |
| **Warnings** | （build 输出） | 零 warning（`-warnings-as-errors`） |

### 执行顺序

```bash
# 快速验证脚本（每次 commit 前跑）
swift build 2>&1 | tee /tmp/handme-build.log
swift test 2>&1 | tee /tmp/handme-test.log
```

App build 在涉及 Xcode 项目文件变更时跑。纯 Package 改动只需 `swift build` + `swift test`。

---

## Soft Metrics（追踪趋势，不阻塞提交）

这些指标被追踪但不硬性阻塞。趋势应该向好。明显恶化时要有理由。

| 指标 | 测量方式 | 方向 |
|------|----------|------|
| **测试覆盖率** | `swift test --enable-code-coverage` | ↑ 不强制，但新代码应有测试 |
| **文件行数** | 单文件不超过 400 行 | 超过时考虑拆分 |
| **TODO/FIXME** | `grep -r "TODO\|FIXME" Sources/` | 只增不减时要清理 |
| **依赖数量** | `Package.swift` 中的 dependencies | 保持最少 |

---

## Constraint Rules（硬性约束）

这些是代码层面的不可违反规则：

1. **不引入安全漏洞。** 不硬编码密钥、不执行未校验的用户输入。
2. **不静默失败。** 错误要么处理要么传播，不要 `try?` 吞掉。
3. **不破坏已有行为。** 改接口必须改所有调用方。删除 public API 必须确认无外部使用。
4. **不跳过 verify。** 即使"只改了一行注释"，也跑 build。
5. **不 force push main。** 永远不行。

---

## Session Protocol

### 开始一个 session

1. `git pull` 确保最新
2. 读 `AUTODEV.md`（本文档）和项目 `CLAUDE.md`
3. 读任务描述或 spec
4. 跑一次 `swift build && swift test` 确认基线是绿的
5. 如果基线就是红的 → 先修基线，再开始新任务

### 结束一个 session

1. 确认所有 hard gates pass
2. 确认没有未提交的改动（`git status` clean 或显式 stash）
3. 如果有未完成的工作 → 记录到 TODO 或 issue，不要留半成品在 working tree

---

## Compounding Mechanism

### 质量棘轮

- Hard gates **永远不放松**。今天能编译零 warning，明天也必须。
- 新的 hard gate **可以加入**。比如当项目引入 SwiftLint 后，lint pass 升级为 hard gate。
- 升级 gate 需要：(1) 当前代码已经满足新 gate，(2) 写入本文档，(3) 团队确认。

### 指标记录

每次重要的里程碑（feature 完成、版本发布）记录一次快照：

```
## Metrics Snapshots

### v0.1 - 初始骨架
- Date: [TBD]
- Tests: [count] pass, 0 fail
- Warnings: 0
- Coverage: [X]%
- Files: [count]
- Dependencies: [count]
```

快照放在本文档底部。趋势可视 = 进步可感。

---

## Escalation Protocol

当自治循环卡住时：

| 情况 | 行动 |
|------|------|
| 同一 gate fail 3 次 | 停止。记录错误信息和已尝试的修复。找人。 |
| 不确定 spec 含义 | 停止。问清楚再写。不要猜。 |
| 改动影响范围超出任务 | 停止。提出来讨论，不要偷偷扩大范围。 |
| 需要新依赖 | 停止。说明为什么现有工具不够，提议具体依赖，等确认。 |
| 测试不知道怎么写 | 先写一个最简单的 happy path test，确认能跑。再考虑边界情况。 |

---

## For AI Agents

如果你是 AI agent 在读这个文档：

- **每次 VERIFY 必须真正执行命令并检查输出。** 不要"假设"它会过。
- **贴出 build/test 的关键输出。** 用户需要看到证据。
- **不要连续 3 次尝试修同一个 bug 而不解释策略变化。** 每次尝试前说清楚"这次我换了什么思路"。
- **完成任务后跑完整 verify，不要只跑你改的部分。** 回归很重要。
- **如果你不确定一个改动是否安全，说出来。** "我不确定这样改会不会影响 X"比静默引入 bug 好一万倍。

---

## Metrics Snapshots

### v0.1 — Initial release
- Date: 2026-03-15
- Tests: 10 pass, 0 fail
- Warnings: 0
- Source files: 20 (.swift)
- Dependencies: 2 (GRDB.swift 7.10.0, swift-argument-parser 1.7.0)
- Commits: 16 (implementation)
