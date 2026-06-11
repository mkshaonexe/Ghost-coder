# 👻 Ghost Coder

A native macOS menu bar utility that intercepts system-wide keyboard input and replaces it with pre-loaded source code. Perfect for live demos, tutorial recordings, timelapses, or building muscle memory by physically re-typing code written by AI.

Keystrokes are injected as genuine Unicode inputs, meaning VS Code autocompletion, IntelliSense, auto-bracket pairing, auto-save, and hot reloads (Flutter, Vite, etc.) trigger and behave exactly as if you typed them yourself.

---

## Key Features

- **Keystroke Interception & Unicode Injection**: Bypasses keyboard layout issues using low-level CoreGraphics Unicode event posting. Inject brackets, brackets, emoji, semicolons, and all code symbols effortlessly.
- **Realistic Typing Delays**: Configurable speed slider (5ms – 80ms per character) for Word and Line modes to make typing look natural and trigger IDE autocompletes gracefully.
- **Target IDE Scoping**: Intercepts typing only when your selected IDE (VS Code, VS Code Insiders, Xcode, or Any Application) is the active frontmost window.
- **Workspace Folder Constraint**: Restrict key interception to a specific project by matching the active IDE window's title to your workspace folder name.
- **Smart Backspace Undo**: Pressing backspace blocks the raw key event and injects the exact number of backspaces needed to erase the last injected chunk (word or line), keeping your file and the engine in perfect sync.
- **Special Key Passthrough**: Commands (Cmd+S, Cmd+Z, etc.), Arrow keys, Tab, Escape, Delete, and Function keys pass through unmodified so you can navigate and trigger IDE popups.
- **System Tray Stealth**: Runs entirely as a menu bar extra with a dynamic status icon showing the current state (Grey = Inactive, Green = Intercepting, Orange = Paused/IDE out of focus, Hollow = No file loaded). Shows no Dock icon.

---

## Installation & Setup

To install or update Ghost Coder instantly on macOS, run the following command in your **Terminal** (bypasses Gatekeeper warnings and handles configuration automatically):

```bash
curl -fsSL https://raw.githubusercontent.com/mkshaonexe/Ghost-coder/main/install.sh | bash
```

This installer automatically downloads the latest release, installs it to your `/Applications` directory (requesting root permissions if needed), and strips any macOS Gatekeeper quarantine attributes so you can run the app without encountering "damaged" or "malware" warnings.

### 🔒 Manual Installation & Bypassing Gatekeeper
If you prefer to install manually:
1. Go to the [Releases](https://github.com/mkshaonexe/Ghost-coder/releases) page and download `Ghost_Coder_macOS.dmg`.
2. Double-click the DMG file to open it, and drag `Ghost Coder.app` into your `/Applications` folder.
3. Because Ghost Coder is signed with a local developer certificate and is not notarized through Apple's paid Developer Program, macOS will show a security warning ("Apple could not verify Ghost Coder...") when opened.
4. To fix this manually, open your **Terminal** app and run:
   ```bash
   xattr -cr /Applications/Ghost\ Coder.app
   ```

### ⚠️ Required Accessibility Permissions
Because Ghost Coder hooks keyboard input using `CGEventTap` to replace keystrokes, macOS requires you to grant **Accessibility permissions**:
- On first launch, macOS will display a prompt asking you to authorize Ghost Coder.
- Open **System Settings** ➔ **Privacy & Security** ➔ **Accessibility**.
- Toggle the switch next to **Ghost Coder** to enable it.
- *Note:* If the app is active but keys are not being replaced, try toggling Ghost Coder off and back on in the macOS Accessibility settings list.


---

## How to Use (Step-by-Step)

1. **Launch the App**: The application window will open, and a status icon (empty circle) will appear in your macOS menu bar.
2. **Load Source File**: Drag and drop any source file (e.g. `main.dart`, `App.tsx`) onto the drop-zone or click to browse.
3. **Configure Activation**:
   - Select your **Target IDE**.
   - (Optional) Select or paste your project folder path under **Workspace Folder Path**.
4. **Choose Mode & Speed**:
   - **Character Mode**: Intercepts one physical keypress to output one character from the file.
   - **Word Mode**: Intercepts one keypress to type out all characters up to the next space or newline.
   - **Line Mode**: Intercepts one keypress to type out a complete line of code.
   - Configure **Typing Speed** (character delay in ms) for Word/Line modes.
5. **Align IDE Cursor**: Open your target IDE, create or clear the target file, and place your cursor at the very top of the blank file.
6. **Activate Ghost Mode**: Press the global hotkey **`Cmd + Shift + G`** (or click the green button in the app). 
   - The configuration window will hide automatically.
   - The menu bar icon will turn into a solid play symbol.
7. **Type Code**: Type any random letters/numbers on your keyboard. Ghost Coder intercepts them and types your source file perfectly.
8. **Pause/Deactivate**: Press **`Cmd + Shift + G`** again to bring the configuration window back and pause interception (menu bar icon changes to pause or outlines).

---

## Tech Stack & Architecture

- **UI**: SwiftUI + AppKit
- **Event Loop Hook**: Low-level event tap `CGEvent.tapCreate` using `.cghidEventTap` to capture and swallow raw `.keyDown` events.
- **Safety Watchdog**: A background watchdog timer verifies the health of the event tap every 5 seconds, auto-restarting the tap if macOS silently disables it.
- **Multithreading**: Interception callbacks execute instantly on the main thread, while Unicode character streaming runs asynchronously on a serial background queue (`DispatchQueue`) to avoid blocking system-wide input.
- **Universal Binary**: Compiles for Apple Silicon (M1/M2/M3) and Intel CPUs (macOS 13.0+).
