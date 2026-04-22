# Contributing to RawPicker

[简体中文](CONTRIBUTING.zh-CN.md)

Thanks for helping improve RawPicker.

## Ground Rules

- Be respectful and constructive.
- Keep pull requests focused and small.
- Discuss large changes in an issue first.

## Development Setup

1. Install Xcode 16+ and Swift 6.3 toolchain.
2. Clone the repository.
3. Build locally:

```bash
swift build
```

4. Run tests:

```bash
swift test
```

## Branch and Commit

- Branch naming: `feat/*`, `fix/*`, `docs/*`, `chore/*`.
- Commit messages should be clear and action-oriented.

Recommended style:

- `feat: add keyboard navigation acceleration`
- `fix: avoid stale cache when switching folders`

## Pull Request Checklist

- [ ] Code builds with `swift build`
- [ ] Tests pass with `swift test`
- [ ] New behavior is covered by tests when possible
- [ ] Documentation updated (`README.md` and `README.en.md` when needed)
- [ ] No secrets or private credentials committed

## Reporting Bugs

Please include:

- macOS version
- RawPicker version/commit
- Sample RAW format (for example: RAF, DNG, CR3)
- Reproduction steps
- Expected result vs actual result
- Logs or screenshots if possible

## Feature Requests

Open an issue with:

- Problem statement
- Proposed solution
- Alternative options considered
- Impact on existing workflow
