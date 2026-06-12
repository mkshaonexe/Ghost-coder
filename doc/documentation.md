# 👻 Ghost Coder - Technical Documentation

Welcome to the **Ghost Coder** technical documentation! This guide is designed for both Junior and Senior developers to understand the internal workings, architecture, and development guidelines for the Ghost Coder macOS app.

## 📌 Table of Contents
1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [Architecture & Folder Structure](#architecture--folder-structure)
4. [Core Engine Components](#core-engine-components)
5. [UI & State Management](#ui--state-management)
6. [Security & Permissions](#security--permissions)
7. [Developer Guidelines (Do's & Don'ts)](#developer-guidelines-dos--donts)

---

## 1. Overview
Ghost Coder is a native macOS menu bar utility built using SwiftUI and AppKit. Its primary function is to intercept system-wide keyboard input and seamlessly replace it with pre-loaded source code. This creates the illusion of "typing out" pre-written code effortlessly, which is perfect for live coding demos, tutorials, or recording programming timelapses.

---

## 2. How It Works
The application relies on low-level macOS CoreGraphics APIs (`CGEventTap`) to manipulate input events globally. 

### The Event Flow:
1. **User presses a key:** A raw `.keyDown` event is fired by macOS.
2. **Interception:** Ghost Coder's highest-priority event tap (`.cghidEventTap`) catches the event *before* it reaches the active application (like VS Code).
3. **Filtering:**
   - If the active window doesn't match the target IDE or workspace, the key is passed through.
   - If a special key (Cmd, Tab, Arrow keys, etc.) is pressed, it is passed through.
   - If a normal alphanumeric key is pressed while the app is "Active", the original key event is "swallowed" (blocked).
4. **Injection:** The `CharacterInjector` asynchronously sends synthetic `CGEvent` keystrokes containing the exact Unicode characters from the loaded source code directly to the active IDE window via `.cgSessionEventTap`.
5. **UI Update:** The UI and `GhostState` update to reflect the new character index.

---

## 3. Architecture & Folder Structure

The project follows an MVVM-like architecture adapted for SwiftUI, heavily leaning on observable state objects.

```text
Ghost Coder/
├── Engine/             # Core logic for keyboard interception, window monitoring, and event injection.
├── Models/             # State management and data structures.
├── Views/              # SwiftUI UI components for the settings/configuration window.
├── HotKey/             # Global keyboard shortcut handling (Cmd+Shift+G).
├── Ghost_CoderApp.swift# App entry point & lifecycle management.
└── ContentView.swift   # Main view container.
```

---

## 4. Core Engine Components
The `/Engine` folder is the heart of the application. It contains the low-level logic that interacts with macOS.

### `KeyboardInterceptor.swift`
- **Purpose:** Manages the `CGEvent.tapCreate` logic.
- **How it works:** It establishes a system-wide hook. It swallows raw keystrokes and decides whether to trigger an injection or let the keypress pass through. It also handles the 5-second watchdog timer to ensure the tap hasn't been disabled by macOS.

### `CharacterInjector.swift`
- **Purpose:** Handles the actual injection of text.
- **How it works:** Uses `CGEvent(keyboardEventSource:virtualKey:keyDown:)` to create and post synthetic keystrokes. It supports character-by-character injection, word chunks, and line chunks. It includes realistic delays to trigger IDE autocompletes (like IntelliSense in VS Code).

### `WindowMonitor.swift`
- **Purpose:** Ensures typing is only intercepted when the user is in their chosen IDE.
- **How it works:** Uses Apple's Accessibility API (`AXUIElement`) to continuously monitor the currently active application and its frontmost window title. This allows the app to enforce Workspace Folder Constraints.

### `CLIServer.swift`
- **Purpose:** Allows Ghost Coder to be controlled or receive data via command-line tools or external scripts, enabling automation workflows.

---

## 5. UI & State Management

### `Models/GhostState.swift`
- This is the single source of truth for the app (`@MainActor class GhostState: ObservableObject`).
- It holds the loaded file contents, the current typing index, user configurations (speed, mode, target IDE), and the active/paused state.
- **Important:** Thread safety is paramount here. Properties are mutated strictly on the Main Thread to ensure SwiftUI updates smoothly without crashes.

### `Views/` (SwiftUI Components)
The configuration window is modularized into highly focused SwiftUI views:
- **`SourceFileSection.swift`**: Drag-and-drop zone for loading `.dart`, `.ts`, `.swift` files.
- **`TargetSection.swift`**: Selectors for the target IDE (VS Code, Xcode, etc.) and workspace path.
- **`ModeSection.swift`**: Toggles for Character, Word, or Line modes, plus typing speed sliders.
- **`ProgressSection.swift`**: Displays a progress bar of how much code has been typed.
- **`DiagnosticsSection.swift` & `PermissionsSection.swift`**: Helps users debug accessibility issues and window detection problems.
- **`MenuBarIcon.swift` / `MenuBarView.swift`**: Renders the system tray icon and its dynamic states (Green = Active, Orange = Paused).

---

## 6. Security & Permissions
Since Ghost Coder intercepts keystrokes, macOS treats it similarly to a keylogger from a security perspective.
- **Accessibility Permissions:** The app *must* have Accessibility permissions in `System Settings > Privacy & Security > Accessibility`.
- **Gatekeeper:** Because the app is not distributed via the Mac App Store and uses raw low-level event taps, it requires the quarantine attribute to be removed via `xattr -cr /Applications/Ghost\ Coder.app` if installed manually.

---

## 7. Developer Guidelines (Do's & Don'ts)

Whether you are fixing a bug or adding a feature, strictly adhere to these rules:

### ✅ DO:
- **Ensure Thread Safety:** The `CGEventTap` callback runs on a background thread. You MUST dispatch any UI updates or `GhostState` mutations to the `DispatchQueue.main`.
- **Use Atomic Operations:** When reading state inside the event tap callback (which needs to be extremely fast to prevent system lag), use thread-safe cached variables (e.g., atomic booleans or `NSLock` protected variables) instead of directly querying `@Published` SwiftUI properties.
- **Keep Event Tap Fast:** Return from `KeyboardInterceptor` callbacks immediately. Any heavy logic (like parsing text or posting long lines of unicode) must be offloaded to an asynchronous background `DispatchQueue`.
- **Handle Accessibility API gracefully:** `AXUIElement` calls can sometimes hang or fail if the target app is unresponsive. Always use notifications or background queues for window monitoring.

### ❌ DON'T:
- **Don't block the Event Tap Thread:** If your code blocks the `CGEventTap` callback for more than a fraction of a second, macOS will automatically kill the event tap, assuming the app has frozen.
- **Don't overuse CPU in WindowMonitor:** Polling the active window title continuously can drain battery. Rely on Workspace notifications (`NSWorkspace.shared.notificationCenter`) where possible instead of a fast loop.
- **Don't intercept modifier keys alone:** Avoid swallowing purely `Cmd`, `Option`, or `Shift` presses, as this breaks native OS functionality like app switching.

---

This documentation should serve as a solid foundation for navigating and contributing to the Ghost Coder project. Happy coding! 👻
