<p align="center">
  <img src="assets/images/logo_s.png" width="80" alt="Strive Logo" />
</p>

<h1 align="center">Strive</h1>

<p align="center">
  A minimal, distraction-free study timer and focus tracker for Linux desktop.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux-informational?style=flat&logo=linux&logoColor=white&color=8B5CF6" />
  <img src="https://img.shields.io/badge/Built%20With-Flutter-informational?style=flat&logo=flutter&logoColor=white&color=8B5CF6" />
  <img src="https://img.shields.io/badge/License-MIT-informational?style=flat&color=8B5CF6" />
  <img src="https://img.shields.io/github/v/release/MohsinRazza/Strive?style=flat&color=8B5CF6" />
</p>

---

## Overview

**Strive** is a clean, focused study timer built for the Linux desktop. It tracks your focus sessions with lap-based logging, visualises your study history on a monthly heatmap, and stays completely out of your way while you work.

No subscriptions. No distractions. Just focus.

---

## Features

- **⏱ Digital Focus Timer** — Clean Outfit-font clock with Start, Pause/Resume, and Stop & Save controls
- **✨ Mini Mode (Always on Top)** — Shrink the timer into a floating pill that stays above other windows while you work
- **🎨 Custom Themes & Accents** — System/Light/Dark mode sync, plus 5 premium accent colors (Purple, Dark Brown, Cyan, Sky Blue, Orange Beige)
- **📊 Activity Heatmap** — Month-view calendar showing daily study intensity at a glance
- **📈 Daily Performance** — Total focus time and toggleable individual lap breakdown for any selected day
- **🗓 Date Navigation** — Click any heatmap day to inspect past sessions
- **💾 Data Management** — Export and import your full session history as JSON (clipboard or file)
- **🪟 Custom Frameless Window** — Native drag-to-move title bar with custom window controls
- **🔒 Crash Recovery** — Active session state is auto-saved every 5 seconds to prevent data loss

---

## Screenshots

> _Coming soon_

---

## Installation

### Download (Debian / Ubuntu)

Download the latest `.deb` from [GitHub Releases](https://github.com/MohsinRazza/Strive/releases) and install:

```bash
sudo dpkg -i strive_1.0.0_amd64.deb
```

Then launch **Strive** from your application menu or run:

```bash
strive
```

To uninstall:

```bash
sudo dpkg -r strive
```

---

## How to Run & Build from Source

### Prerequisites

To run or build Strive on your machine, you need:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Linux build dependencies:

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Running the Project (Development)

Clone the repository and run it directly using Flutter:

```bash
git clone https://github.com/MohsinRazza/Strive.git
cd Strive
flutter pub get
flutter run -d linux
```

### Build a .deb Package

A build script is included for packaging:

```bash
chmod +x build_deb.sh
./build_deb.sh
```

The output `.deb` will be placed in `build/strive_<version>_amd64.deb`.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Font | [Outfit](https://fonts.google.com/specimen/Outfit) via `google_fonts` |
| Window Management | `window_manager` |
| Storage | Local JSON via `path_provider` |
| Date Formatting | `intl` |

---

## Data & Privacy

All your data stays **entirely on your machine**. Strive has no network access, no analytics, and no cloud sync. Session history is stored as a plain JSON file in your local documents directory.

You can export or import your data at any time from the Data Management section.

---

## License

MIT © [Mohsin Razza](https://github.com/MohsinRazza)
