# CMM Clone

A minimal, aesthetic macOS cleanup utility inspired by CleanMyMac, built with SwiftUI and Apple's Liquid Glass design language.

## Features

- **Free Up RAM** — purge inactive memory and see live pressure metrics
- **Clean Junk** — sweep user caches, logs, Trash, Xcode DerivedData, simulator caches, old Downloads, and browser caches
- **Uninstaller** — remove apps along with their hidden support files, caches, preferences, containers, and launch agents

## Requirements

- macOS 14 (Sonoma) or newer — recommended macOS 26 (Tahoe) for full Liquid Glass effects
- Apple Silicon
- Swift 6 toolchain (Command Line Tools is sufficient)

## Build

```bash
./build.sh
```

This produces `build/CMM Clone.app`. Copy it to `/Applications` to install:

```bash
cp -R 'build/CMM Clone.app' /Applications/
```

## Project Layout

```
Sources/CMMClone/        Swift source files
Resources/               Info.plist, icon generator, icon assets
build.sh                 one-shot build script (swiftc + codesign)
```

## Notes

- The app runs ad-hoc signed (no Apple Developer ID required).
- Uninstalls and junk sweeps delete files directly; you'll be asked to confirm each action in the UI before anything is removed.
- Some system caches require admin privileges and will be skipped silently.

## License

MIT
