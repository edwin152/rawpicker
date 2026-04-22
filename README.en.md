# RawPicker

[中文](README.md)

Website: [rawpicker.edwin.work](https://rawpicker.edwin.work)

RawPicker is a macOS app for fast RAW photo browsing and first-pass culling. It keeps the workflow simple: open a batch of RAW files, move through them quickly, mark keepers, filter the selection, and export the files you want to keep.

## Highlights

- Open RAW files or folders, or drag files/folders directly into the window.
- Supports common RAW formats: `RAF`, `DNG`, `NEF`, `CR2`, `CR3`, `ARW`, `RW2`, `ORF`, `PEF`.
  **Actual decoding support depends on macOS built-in ImageIO/Core Image support for each camera model.**
- Thumbnail strip, preview caching, and repeatable arrow-key navigation for quick review.
- Mark keepers with 5 stars; ratings are written to matching `.xmp` sidecar files.
- Filter to 5-star photos, then copy or move them together with their `.xmp` sidecars.
- Inspect EXIF details such as camera, lens, ISO, shutter speed, aperture, and focal length.
- Use fit-to-window, 100%/zoomed viewing, and last-session restore.

## Keyboard Shortcuts

| Action | Shortcut |
| --- | --- |
| Open files or folder | `Command + O` |
| Previous / next photo | `←` / `→` |
| Set 5 stars / reset rating | `Space` |
| Fit / 100% | `F` |
| Zoom in / out | `Command + +` / `Command + -` |
| Toggle EXIF | `Command + I` |

## Package the macOS App

Build Requirements

- macOS 14 or later
- Swift 6.2, or Xcode with a matching Swift toolchain

Build a Release app and copy it to `dist/RawPicker.app`:

```bash
chmod +x scripts/package-macos.sh
./scripts/package-macos.sh
```

Build and launch immediately:

```bash
./scripts/package-macos.sh --run
```

The packaging log is written to `build/logs/package-macos.log`.

## Open Source

- Privacy Policy: [privacy.en.html](https://rawpicker.edwin.work/privacy.en.html)
- Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

## License

RawPicker is released under the MIT License. See [LICENSE](LICENSE).
