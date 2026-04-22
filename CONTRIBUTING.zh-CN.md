# 参与贡献 RawPicker

[English](CONTRIBUTING.md)

感谢你帮助改进 RawPicker。

## 基本原则

- 保持尊重与建设性沟通。
- Pull Request 尽量聚焦、粒度小。
- 对于较大的改动，请先在 Issue 中讨论。

## 开发环境

1. 安装 Xcode 16+ 和 Swift 6.3 工具链。
2. 克隆仓库。
3. 本地构建：

```bash
swift build
```

4. 运行测试：

```bash
swift test
```

## 分支与提交

- 分支命名建议：`feat/*`、`fix/*`、`docs/*`、`chore/*`。
- Commit 信息应清晰、面向动作。

推荐风格：

- `feat: add keyboard navigation acceleration`
- `fix: avoid stale cache when switching folders`

## Pull Request 自检清单

- [ ] 代码可通过 `swift build`
- [ ] 测试可通过 `swift test`
- [ ] 新行为在可行时补充测试
- [ ] 必要时更新文档（`README.md` 和 `README.en.md`）
- [ ] 未提交密钥或私有凭据

## Bug 反馈

请尽量包含以下信息：

- macOS 版本
- RawPicker 版本/commit
- RAW 格式样本（例如 RAF、DNG、CR3）
- 复现步骤
- 期望结果与实际结果
- 日志或截图（如有）

## 功能请求

请在 Issue 中说明：

- 问题背景
- 方案建议
- 考虑过的替代方案
- 对现有工作流的影响
