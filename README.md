# RawPicker

[English](README.en.md)

官网：[rawpicker.edwin.work](https://rawpicker.edwin.work)

RawPicker 是一个面向 macOS 的 RAW 照片快速浏览与初筛工具。它专注于一件事：尽量快地打开一组 RAW 文件，用键盘和缩略图完成浏览、标记、筛选，再把选中的照片导出。

## 功能亮点

- 打开 RAW 文件或整个文件夹，也可以把文件/文件夹直接拖进窗口。
- 支持常见 RAW 格式：`RAF`、`DNG`、`NEF`、`CR2`、`CR3`、`ARW`、`RW2`、`ORF`、`PEF`。
  **实际解码能力取决于 macOS 自带的 ImageIO/Core Image 对具体相机型号的支持。**
- 缩略图条、预览缓存和连续方向键浏览，适合快速挑片。
- 用 5 星标记保留照片，评分写入同名 `.xmp` 附属文件。
- 一键只看 5 星照片，并可复制或移动 5 星照片及对应 `.xmp` 文件。
- 查看相机、镜头、ISO、快门、光圈、焦距等 EXIF 信息。
- 支持适应窗口、100%/缩放查看，以及上次会话恢复。

## 常用快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开文件或文件夹 | `Command + O` |
| 上一张 / 下一张 | `←` / `→` |
| 设为 5 星 / 重置评分 | `Space` |
| 适应窗口 / 100% | `F` |
| 放大 / 缩小 | `Command + +` / `Command + -` |
| 显示 / 隐藏 EXIF | `Command + I` |

## 打包 macOS App

编译系统要求

- macOS 14 或更新版本
- Swift 6.2 或包含对应 Swift 工具链的 Xcode

构建 Release 版本并复制到 `dist/RawPicker.app`：

```bash
chmod +x scripts/package-macos.sh
./scripts/package-macos.sh
```

构建后直接启动：

```bash
./scripts/package-macos.sh --run
```

打包日志会写入 `build/logs/package-macos.log`。

## 开源协作

- 隐私政策：[privacy.html](https://rawpicker.edwin.work/privacy.html)
- 贡献指南：[CONTRIBUTING.md](CONTRIBUTING.md)
- 行为准则：[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 安全策略：[SECURITY.md](SECURITY.md)
- 变更日志：[CHANGELOG.md](CHANGELOG.md)

## 许可证

RawPicker 使用 MIT 许可证，详见 [LICENSE](LICENSE)。
