# Product Requirement Document (PRD) — Ghost Coder
**Version:** 1.1 (MVP — macOS Only)
**Status:** Ready for Implementation

---

## 1. Product Overview

**Ghost Coder** is an open-source macOS menu bar utility. It intercepts keyboard input system-wide and replaces it with pre-loaded source code — character by character, word by word, or line by line. The user types arbitrary keys on their keyboard; the correct, real source code appears in their IDE as if they typed it themselves.

**Core Value Proposition:**
You have a completed codebase (written by AI or yourself). Ghost Coder makes it look like you are typing it live — keystroke by keystroke — in real time, with VS Code autocomplete, auto-save, and Flutter hot reload all responding naturally, because real keystrokes are being injected.

---

## 2. Problem Statement

Developers and content creators who want to:
1. Create live-coding tutorials or timelapses of an already-completed project
2. Learn code they wrote with AI by physically re-typing it themselves
3. Present a clean, error-free, professional coding demo to an audience

…have no good tool. Manually retyping introduces errors and frustration. Copy-paste destroys the natural visual rhythm. Existing "hacker typer" web tools are purely cosmetic — they do not interact with a real IDE, do not trigger autocomplete, and do not produce hot reload.

**Ghost Coder solves this** by injecting real Unicode keystrokes directly into the active IDE, making it look and behave exactly like genuine human typing.

---

## 3. Goals & Objectives

- **Visual Illusion:** Every keystroke must look indistinguishable from real typing — VS Code autocomplete, IntelliSense, and bracket completion all trigger naturally.
- **Hot Reload Compatibility:** Because real keystrokes are injected into VS Code, VS Code's own auto-save fires. Flutter hot reload, Vite HMR, and any file watcher respond automatically. No extra integration needed.
- **Zero-Friction Activation:** Once configured, the user focuses on their IDE, presses a hotkey, and types. Ghost Coder is invisible.
- **Minimal GUI:** The app is configured once, then hidden. It lives in the menu bar.

---

## 4. Target Audience

- **Tech Content Creators** — YouTubers, TikTokers, and Reels creators making coding timelapses and tutorial videos.
- **AI-Assisted Developers** — Developers who generated a codebase with AI and want to walk through it live without copy-pasting.
- **Learners** — Students who want to learn code by physically typing it out line by line to build muscle memory and understanding.

---

## 5. Platform & Distribution

| Property | Value |
|---|---|
| **Primary Platform** | macOS 13 Ventura and above |
| **Architecture** | ARM64 native (M-series) + x86_64 (Intel); Universal Binary |
| **Distribution** | Open-source GitHub repository + `.dmg` direct download on Releases page |
| **App Store** | ❌ Not applicable. CGEventTap is incompatible with the App Store sandbox. |
| **Notarization** | Recommended (requires Apple Developer Program, $99/year). Prevents Gatekeeper "unidentified developer" warning for end users. |
| **Windows** | Out of scope for MVP. Architecture decision for future Windows port deferred to v2 planning. |

---

## 6. Key Features (MVP)

### 6.1 Source File Loader

The user provides the completed source code file that Ghost Coder will type out.

- **Drag-and-drop zone** on the main GUI to drop any text-based file.
- **File picker button** as an alternative to drag-and-drop.
- Supports any plain text file: `.dart`, `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.swift`, `.kt`, `.html`, `.css`, `.json`, etc.
- After loading, display: filename, total character count, total line count.
- A **Reset button** sets the internal pointer back to position 0 (start of file).
- If the source file is replaced or reloaded, Ghost Mode auto-pauses and the pointer resets.

### 6.2 IDE Target & Activation Scope

Ghost Mode must only activate when the user is focused in the correct application and project. Two configuration fields control this.

**Field A — Target IDE (required)**

A dropdown to select which application triggers Ghost Mode activation:

| Option | Bundle ID Used |
|---|---|
| VS Code (default) | `com.microsoft.VSCode` |
| VS Code Insiders | `com.microsoft.VSCodeInsiders` |
| Xcode | `com.apple.dt.Xcode` |
| Any Application | (no bundle ID check) |

Ghost Mode key interception only activates when the selected IDE is the **frontmost** (focused) application. If the user switches to their browser or Terminal, key interception is paused automatically. When the user returns to the IDE, it resumes.

**Field B — Workspace Folder Path (optional)**

A text field (with a folder picker button) that accepts a directory path, e.g., `/Users/shaon/projects/myapp/lib/`.

- When **set**: Ghost Mode activates only if the target IDE's frontmost window title contains the last component of this folder path. This scopes Ghost Mode to a specific project.
- When **empty**: Ghost Mode activates for any file open in the target IDE.

**Purpose:** Prevents accidental key interception when working on a different project in the same IDE instance.

**Activation Logic (all conditions must be true simultaneously):**

```
Ghost Mode Keys Are Intercepted =
    isGhostModeEnabled           (user toggled it on via hotkey or GUI)
    AND source file is loaded     (sourceCode is not empty)
    AND currentIndex < sourceCode.length   (still have characters to type)
    AND target IDE is frontmost   (based on Field A)
    AND folder scope passes       (Field B empty, OR window title matches)
```

### 6.3 Input Modes

Three modes control how many characters are injected per physical key press. Selected via radio buttons.

| Mode | One Physical Keypress Injects | Example — Source has `import 'flutter/material.dart';\n` |
|---|---|---|
| **Character** | 1 character | Press `t` → `i` appears |
| **Word** | All characters up to and including the next space or newline | Press `t` → `import ` appears |
| **Line** | All characters up to and including the next newline | Press `t` → full line appears + Enter |

**Injection Delay (Word & Line mode only):**
When multiple characters are injected per keypress, a per-character delay is applied so VS Code's autocomplete and IntelliSense trigger naturally and the typing looks realistic. A slider controls this.
- Range: 5ms – 80ms per character
- Default: 12ms
- Label: "Typing Speed"

In Character Mode, no delay is needed — single-character injection is instant.

### 6.4 Ghost Mode Controls

**Global Hotkey: `Cmd + Shift + G`**
- Registered system-wide. Works even when Ghost Coder's window is hidden.
- Toggles Ghost Mode on and off.
- When Ghost Mode is turned ON: the main GUI window hides automatically (stealth mode).
- When Ghost Mode is turned OFF: the main GUI window reappears.

**Menu Bar Status Icon:**
The menu bar icon communicates state at a glance:

| Icon State | Meaning |
|---|---|
| ⚫ Grey circle | Ghost Mode is OFF |
| 🟢 Green circle | Ghost Mode is ON and actively intercepting |
| 🟠 Orange circle | Ghost Mode is ON but paused (IDE not focused / folder mismatch) |
| ⬜ Hollow circle | Source file not loaded |

**Progress Display (in GUI):**
- A progress bar showing `currentIndex / sourceCode.count`
- A label: `"1,247 / 4,832 characters typed"`
- Live-updating as characters are injected.

### 6.5 Backspace Behaviour

When Ghost Mode is active and the user presses `Backspace`:

1. The original Backspace event is **blocked** (does not reach the IDE directly).
2. Ghost Coder injects N backspace key events into the IDE, where N = the number of characters that were last injected (based on the last operation's chunk size).
3. The internal `currentIndex` is decremented by N.
4. The IDE's content and undo history update naturally.

This keeps the Ghost Coder pointer and the IDE content in sync after a correction.

### 6.6 Special Key Passthrough

The following keys are **always passed through** to the IDE unmodified, regardless of Ghost Mode state:

- Any combination with `Cmd` key (Cmd+S save, Cmd+Z undo, Cmd+C copy, Cmd+V paste, etc.)
- Arrow keys (Left, Right, Up, Down)
- `Escape`
- `Tab` — passed through so the user can navigate VS Code's autocomplete dropdown
- `Enter` / `Return` — passed through unless the next character in the source code is `\n`, in which case the Enter is intercepted and used to advance the source pointer
- All Function Keys (F1–F12)
- `Delete` (forward delete)

**Keys that ARE intercepted** (replaced with source code characters):
- All alphanumeric keys: `a–z`, `A–Z`, `0–9`
- All symbol/punctuation keys: `!@#$%^&*()-_=+[]{}\|;:'",.<>/?`
- `Space`

### 6.7 Menu Bar Integration

Ghost Coder runs as a **menu bar application** with no Dock icon (LSUIElement = YES in Info.plist).

Clicking the menu bar icon reveals a dropdown menu:

```
Ghost Coder  ●
─────────────────────────
Status: Active / Inactive / Paused
─────────────────────────
Toggle Ghost Mode     ⌘⇧G
Show / Hide Window
─────────────────────────
Quit Ghost Coder
```

---

## 7. User Flow (MVP — Step by Step)

1. User launches Ghost Coder. Main window appears. Menu bar icon is visible (grey).
2. User drags their completed source file (e.g., `dashboard.dart`) into the dropzone.
3. Ghost Coder displays: `dashboard.dart — 4,832 characters — 143 lines`.
4. User selects **VS Code** as Target IDE.
5. (Optional) User enters `/Users/shaon/projects/myapp/lib/` in the Folder Path field.
6. User selects Input Mode: **Character** (or Word / Line).
7. User opens VS Code. Opens the blank destination file (e.g., a new empty `dashboard.dart` inside their project).
8. User positions VS Code cursor at the top of the blank file.
9. User presses `Cmd + Shift + G`. Ghost Coder window hides. Menu bar icon turns green.
10. User types random keys on their keyboard.
11. The correct source code appears in VS Code, character by character. VS Code auto-save fires. Flutter hot reload triggers. Autocomplete suggestions appear naturally.
12. When finished (or to pause), user presses `Cmd + Shift + G`. Ghost Coder window reappears. Menu bar icon turns grey.

---

## 8. Out of Scope (MVP — Not Building Now)

- Multi-file sequential playback (type file A, then auto-switch to file B)
- Automatic detection of VS Code's currently active file (requires VS Code extension or AppleScript)
- Audio / keyboard click sound effects
- Windows support
- Cloud sync or settings persistence across machines
- Recording or screen capture integration
- Scheduled / timed automatic typing (without user keypresses)
- Git diff mode (type only the changed lines)

---

## 9. Future Scope (v2+)

- **Windows Port:** Evaluate at v2 — either Flutter Desktop + C++ Platform Channel, or a standalone native C#/WPF app.
- **Multi-File Mode:** Queue multiple source files. Ghost Coder auto-advances to the next file when the current one is complete.
- **VS Code Extension:** A companion extension that shows Ghost Coder status in VS Code's status bar and auto-maps the active file.
- **Auto-Save Trigger:** Force `Cmd+S` injection after each line to guarantee hot reload for projects without auto-save enabled.
- **Typing Sound Effects:** Synthetic keyboard click audio synced to injection rate.
- **Session Recording:** Export the session as a `.ghostsession` file to replay later at any speed.
