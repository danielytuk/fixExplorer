## ⚠️ Fix File Explorer Freezing in Windows 11

This PowerShell script is designed to **resolve a common issue in Windows 11** where **File Explorer becomes unresponsive**, often freezing the taskbar and other parts of the system UI. This is typically caused by corrupted or bloated jump list data.

### 🛠️ What It Does

1. **Automatically elevates** itself to run as Administrator if needed.
2. **Clears jump list cache files**, which are known to trigger UI freezing in Windows 11:

   * `AutomaticDestinations` – Stores recent items for frequently used applications.
   * `CustomDestinations` – Stores pinned and recent file data.
3. **Empties the Recycle Bin** to remove additional clutter that might contribute to system lag or UI issues.

### 📁 Affected Paths

The script deletes files in the following directories:

```text
%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations
%APPDATA%\Microsoft\Windows\Recent\CustomDestinations
```

These locations store jump list history that Windows Explorer loads at startup. Corrupted files here can cause **Explorer.exe** to hang or crash.

### ✅ How to Use

1. **Save the script** as `fixExplorer.ps1`.
2. **Right-click PowerShell and run as Administrator** (or let the script auto-elevate).
3. **Run the script**:

   ```powershell
   .\fixExplorer.ps1
   ```

### 💡 Tip

After running, restart **File Explorer** or your PC for changes to take full effect.
