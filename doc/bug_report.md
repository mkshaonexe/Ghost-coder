# Ghost Coder — Detailed Bug & Issue Report

This report provides a comprehensive, technical analysis of the bugs and syntax-corruption issues identified during the execution of Ghost Coder. It compares the output file produced by Ghost Coder with the desired reference source file, details the exact sequence of events leading to the corruption, identifies the root causes in the codebase, and proposes fixes.

---

## 1. Executive Summary

During testing, Ghost Coder was tasked with injecting the contents of `dashboard_view.dart`. However, the generated output was structurally garbled and syntactically invalid:
- **Major Defect:** The entire class header declaration `class DashboardView extends StatelessWidget {` was completely missing from the output, replaced instead with `get {`.
- **Secondary Defects:** Multiple lines further down in the file were duplicated, misaligned, or interleaved (e.g. nested SingleChildScrollViews and stray brackets).
- **Analysis:** This issue was triggered when the user switched from **Character Mode** to **Line Mode** mid-way through typing line 7. This switch triggered a series of code-generation and input-injection bugs in the Ghost Coder Swift engine.

---

## 2. File Comparison & Output Corruption

### A. Missing Class Header (Line 7)
*   **Desired Source File (`playground/my_app_fultter_test/.../dashboard_view.dart`):**
    ```dart
    import 'package:flutter/material.dart';
    import '../../../domain/models.dart';
    import '../../core/app_theme.dart';
    import '../bank_view_model.dart';
    import '../add_money/add_money_view.dart';
    
    class DashboardView extends StatelessWidget {
      final BankViewModel viewModel;
    ```
*   **Ghost Coder Output File (`test ghost coder/my_app_fultter_test/.../dashboard_view.dart`):**
    ```dart
    import 'package:flutter/material.dart';
    import '../../../domain/models.dart';
    import '../../core/app_theme.dart';
    import '../bank_view_model.dart';
    import '../add_money/add_money_view.dart';
    
    get {
      final BankViewModel viewModel;
    ```
    *Observation:* The class name, inheritance, and declaration syntax are completely gone, replaced by `get {`.

### B. Garbled/Duplicate Structure (Lines 26–33)
*   **Desired Source File:**
    ```dart
    26:               physics: const BouncingScrollPhysics(),
    27:               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    28:               child: Column(
    29:                 crossAxisAlignment: CrossAxisAlignment.start,
    30:                 children: [
    31:                   _buildHeader(context),
    32:                   const SizedBox(height: 24),
    33:                   _buildBalanceCard(context),
    ```
*   **Ghost Coder Output File:**
    ```dart
    26:               physics: const BouncingScrollPhysics(),
    27:               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    28:   });
    29:                 crossAxisAlignment: CrossAxisAlignment.start,
    30:             child: SingleChildScrollView(
    31:                   _buildHeader(context),
    32:                   const SizedBox(height: 24),
    33:                   _buildBalanceCard(context),
    ```
    *Observation:* Syntactic constructs like `});` and `child: SingleChildScrollView(` are injected out of order and nested incorrectly due to bracket auto-closure and cursor misalignment.

---

## 3. Root Cause Analysis: The 6 Confirmed Bugs

Here are the six bugs identified in the Ghost Coder engine, mapped to the exact code files, functions, and lines.

### Bug #1 — 🔴 CRITICAL: Clipboard Paste Overwrites Pre-Typed Text (CMD+V Erase)
*   **File:** [CharacterInjector.swift](file:///Users/mkshaon/playground/Ghost%20coder/Ghost%20Coder/Ghost%20Coder/Engine/CharacterInjector.swift#L45-L50)
*   **Function:** `injectString(_ text: String)`
*   **Root Cause:**
    When Ghost Coder needs to paste a string that contains a newline (`\n`), it bypasses unicode injection and invokes a clipboard paste operation:
    ```swift
    // Line 45-50
    if text.contains("\n") {
        pasteViaClipboard(text)
        return
    }
    ```
    During character-by-character typing, VS Code's autocomplete/intellisense suggestions are active. If a mode switch (e.g., to Line Mode) occurs, the next injected chunk (`"get {\n"`) contains a newline. The engine copies `"get {\n"` to the clipboard and triggers a synthetic `Cmd+V` paste event.
    
    Because the editor's cursor was resting immediately after `class DashboardView extends StatelessWid` and a typing session was active, VS Code was in a transient text-selection/suggestion state. Generating a `Cmd+V` event under these conditions causes VS Code to treat the paste as a **replacement action**, erasing the 232 characters typed so far on that line and replacing them with just the new chunk (`"get {\n"`).

---

### Bug #2 — 🟠 MEDIUM: Line Mode Chunking Starts Mid-Line
*   **File:** [GhostState.swift](file:///Users/mkshaon/playground/Ghost%20coder/Ghost%20Coder/Ghost%20Coder/Models/GhostState.swift#L440-L449)
*   **Function:** `_buildChunk(sourceCode: String, index: Int, mode: InputMode)`
*   **Root Cause:**
    The line mode chunking logic calculates chunks starting directly from the current index, without validating if that index is at the start of a line:
    ```swift
    case .line:
        // Read up to and including the next newline
        var result = ""
        for char in remaining {
            result.append(char)
            if char == "\n" { break }
        }
        return result
    ```
    If the user starts typing a line in **Character Mode** and switches to **Line Mode** mid-line (at pointer index `232` in our logs), `remaining` starts mid-line at index `232`. The calculated chunk is only the *suffix* of the current line (`"get {\n"`) rather than the *entire* line. This partial suffix contains a newline, triggering Bug #1 and corrupting the line.

---

### Bug #3 — 🟠 MEDIUM: Indentation & Bracket Auto-Closure Garbling
*   **File:** Editor-State Integration (triggered by simulated keyboard events in `CharacterInjector.swift`)
*   **Root Cause:**
    Once the class declaration `class DashboardView extends StatelessWidget {` was deleted and replaced by `get {`, the nesting balance of the file broke.
    
    Subsequent line-by-line injections of the source code were pasted into an editor that had active auto-brackets and auto-indentation rules. As a result, VS Code automatically inserted closing brackets (`});`) and shifted subsequent lines, causing the code to duplicate segments, interleave parts of nested blocks, and append random characters (such as `fjoiaafs` at the end).

---

### Bug #4 — 🟠 MEDIUM: ResponseLogger Missing Undo (Backspace) Logging
*   **File:** [KeyboardInterceptor.swift](file:///Users/mkshaon/playground/Ghost%20coder/Ghost%20Coder/Ghost%20Coder/Engine/KeyboardInterceptor.swift#L190-L202)
*   **Function:** `handleKeyDown(proxy:type:event:)` (Rule 3)
*   **Root Cause:**
    When a user triggers a backspace (keycode `51`) to undo the last injection, the interceptor intercepts the backspace and calls the undo logic on the injector:
    ```swift
    // Rule 3: Backspace (keyCode 51)
    if keyCode == 51 {
        guard !state.isHistoryEmpty else {
            isInjecting = false
            return nil
        }
        injectionQueue.async { [weak self] in
            guard let self else { return }
            self.injector.handleBackspace() // <- Undoes the injection in the IDE
            self.isInjecting = false
        }
        return nil
    }
    ```
    **Critical Flaw:** The interceptor updates `injector` state, but it **fails to notify** the `responseLogger`! No event is written to `response.jsonl` indicating that an undo occurred.
    
    As a result, characters that were typed and then deleted (like the extra `'g'` in sequence `233`) remain in the log file as if they were successfully inserted.

---

### Bug #5 — 🟡 MINOR: Session Metadata `source_file` Always `"none"`
*   **File:** [Ghost_CoderApp.swift](file:///Users/mkshaon/playground/Ghost%20coder/Ghost%20Coder/Ghost%20Coder/Ghost_CoderApp.swift)
*   **Root Cause:**
    `ResponseLogger.startSession()` is called immediately during application launch inside the App delegate. At this point, no source file has been loaded, so `state.sourceFileName` defaults to `"none"` (or is empty).
    
    When a file is loaded later via the CLI command (e.g. 41 seconds later in our logs), there is no mechanism to update the initial session metadata block in the `.jsonl` log.

---

### Bug #6 — 🟡 MINOR: Virtual Output Character Count Mismatch (+1)
*   **File:** [ResponseLogger.swift](file:///Users/mkshaon/playground/Ghost%20coder/Ghost%20Coder/Ghost%20Coder/Engine/ResponseLogger.swift)
*   **Root Cause:**
    This is a mathematical side-effect of Bug #4. Because the log records the injection of the character `'g'` (seq `233`) but does not record its deletion/undo, the cumulative length of all logged characters is 18,639 (1 character more than the actual reference source file length of 18,638).

---

## 4. Summary Table of Issues

| ID | Issue Description | Severity | Target File / Function | Operational Impact |
| :--- | :--- | :--- | :--- | :--- |
| **#1** | Clipboard paste replaces previous characters on mode-switch | 🔴 Critical | `CharacterInjector.swift`<br>`injectString()` | Deletes written source code and replaces it with partial line text. |
| **#2** | Line mode chunking starts mid-line | 🟠 Medium | `GhostState.swift`<br>`_buildChunk()` | Generates partial line suffix chunks instead of complete lines. |
| **#3** | Auto-bracket & indentation corruption | 🟠 Medium | IDE Interaction | Results in duplicated code lines and invalid bracket syntax. |
| **#4** | Backspace/Undo events are not logged | 🟠 Medium | `KeyboardInterceptor.swift`<br>`handleKeyDown()` | Mismatches the response log from the actual editor state. |
| **#5** | `source_file` metadata is always `"none"` | 🟡 Minor | `Ghost_CoderApp.swift`<br>`init()` timing | Prevents identification of the worked file during log analysis. |
| **#6** | Reconstructed character count mismatch | 🟡 Minor | `ResponseLogger.swift` | The log shows +1 character than the actual file size. |

---

## 5. Timeline of the Failure (from Logs)

The following timeline reconstructed from the session logs (`session_2314e27f-1781253461`) shows the exact second the failure happened:

1.  **`14:41:02` - Character Mode Typing Starts:**
    Characters are injected one-by-one (`1 to 1`, `1 to 2`... up to `233` characters).
2.  **`14:41:27` - Keypress 233:**
    Injected character `'g'` (completing `class DashboardView extends StatelessWidg`).
3.  **`14:41:37` - Focus Switch:**
    The user switches application focus to Ghost Coder to change options.
4.  **`14:41:44` - Focus Switch Back:**
    The user returns focus back to VS Code.
5.  **`14:41:48` - Undo Triggered:**
    The user hits backspace. The engine successfully deletes `'g'`. The pointer in the IDE returns to `232` (right after `StatelessWid`).
    *Note: This backspace is NOT written to the response log (Bug #4).*
6.  **`14:41:50` - Mode Switched & Line Injection Fired:**
    The user switches typing mode to **Line Mode** and hits a key.
    - `_buildChunk` generates the suffix `"get {\n"` starting from pointer `232` (Bug #2).
    - `CharacterInjector` detects `\n` in `"get {\n"`.
    - It triggers `pasteViaClipboard("get {\n")` (Bug #1).
    - VS Code highlights/erases `class DashboardView extends StatelessWid` and pastes `get {\n`.
7.  **`14:41:50+` - Indentation Cascading:**
    Subsequent line chunks are pasted into a syntactically broken file. VS Code's auto-formatting engine triggers and garbles the nesting of the entire file (Bug #3).

---

## 6. Conceptual Fixes (No Code Changes Applied)

1.  **For Bug #1 & #2 (Text Loss on Mode Switch):**
    When switching to Line Mode mid-line, the engine should either:
    - Snap the pointer back to the start of the line and paste the entire line, OR
    - Paste the suffix using a multi-character unicode injection sequence instead of clipboard paste, as long as it fits on the same line, preventing `Cmd+V` from triggering replacement mechanics.
2.  **For Bug #4 (Missing Undo Logging):**
    Modify `KeyboardInterceptor.swift` (Rule 3) to call `responseLogger?.logUndoEvent()` (or similar) when backspace is pressed, so the log tracks deletions.
3.  **For Bug #5 (Metadata):**
    Delay starting the log session or update the metadata section of the log file dynamically when `loadSourceFile(url:)` is called.
