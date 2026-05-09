# DebugProcessWatcher

DebugProcessWatcher is a lightweight macOS menu bar app for inspecting local development processes that are listening on TCP ports.

It is designed for day-to-day local debugging: quickly see what is running, which port it is using, what command launched it, where it is running from, and then either open Terminal in that working directory or kill the process.

## Features

- Menu bar access for fast process inspection
- Dedicated app window with searchable process table
- Language-aware filtering in the sidebar
- Detection for common local dev stacks including:
  - Node.js
  - Python
  - Java
  - Go
  - Rust
  - Swift
  - Ruby
  - PHP
  - .NET
  - Deno
  - Bun
- Shows:
  - Port
  - CPU usage
  - Memory usage
  - Language
  - PID
  - Protocol
  - Listen address
  - Full command
  - Current working directory
- One-click actions per process:
  - Kill process
  - Open Terminal at the process working directory
- Right-click copy actions for:
  - Command
  - CWD
- Auto-refresh support

## Requirements

- macOS 14 or later
- Xcode 16+ or a recent Swift 6 toolchain

## Project Structure

```text
DebugProcessWatcher/
├── Package.swift
├── README.md
├── Scripts/
│   └── package-app.sh
├── Sources/
│   └── DebugProcessWatcher/
│       ├── AppDelegate.swift
│       ├── DebugProcessWatcherApp.swift
│       ├── MenuBarContent.swift
│       ├── ProcessInfo.swift
│       ├── ProcessListView.swift
│       ├── ProcessMonitor.swift
│       └── Resources/
└── Artifacts/
    └── Legacy/
```

## Build

Build the app with Swift Package Manager:

```bash
swift build
```

## Run

Launch the debug build directly:

```bash
.build/arm64-apple-macosx/debug/DebugProcessWatcher
```

## Package As `.app`

To package the current build into a macOS `.app` bundle:

```bash
Scripts/package-app.sh
```

The packaged app will be created at:

```text
Artifacts/DebugProcessWatcher.app
```

## Typical Workflow

1. Build the app with `swift build`
2. Package it with `Scripts/package-app.sh`
3. Launch `Artifacts/DebugProcessWatcher.app`
4. Use the menu bar icon to open the process window

## How It Works

DebugProcessWatcher uses standard macOS command-line tools to inspect listening processes:

- `lsof` for listening sockets and working directories
- `ps` for CPU, memory, and command-line information
- `kill` for process termination
- `osascript` / Terminal integration for opening the process working directory

## Notes

- Language filters only appear when matching processes are currently detected.
- Some process metadata depends on what macOS exposes to the current user session.
- The app is intended for local development workflows rather than production process management.
