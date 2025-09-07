# Explorer Maintenance Script (Windows 11)

A Windows 11 maintenance script designed to keep `explorer.exe` responsive (hopefully fixing hangs) and maintain system performance. This script performs deep cleanup of caches, recent items, temporary files, Quick Access, and rebuilds the Windows Search index, all while providing detailed logging and a summary of actions taken.

It is **fully self-elevating** and optimized for **parallel execution**, significantly reducing runtime on modern systems.

---

## Features

* Self-elevates to run as Administrator.
* Cleans **Recent Items** and Jump Lists older than configurable days.
* Clears **Icon and Thumbnail caches**.
* Cleans **Quick Access cache**.
* Empties **Recycle Bin**.
* Cleans **temporary files**.
* Flushes **DNS cache**.
* Rebuilds **Windows Search index** using COM API.
* Restarts critical processes: `Explorer.exe`, `SearchHost.exe`, `ShellExperienceHost.exe`.
* Generates **detailed logs** in `C:\Temp\explorer-maintenance.log`.
* Parallelized cleanup for faster execution.

---

## Requirements

* Windows 11 (may work on Windows 10, but not tested).
* PowerShell 5.1 or later.
* Administrator privileges (script auto-elevates if needed).

---

## Installation

1. **Save the script** as `fixExplorer.ps1`.
2. **Right-click PowerShell and run as Administrator** (or let the script auto-elevate).
3. **Run the script**:

   ```powershell
   .\fixExplorer.ps1
   ```

   The script will self-elevate if it is not already running as Administrator.

---

## Usage

### Default Run

Simply run the script as described above. All cleanup operations and service/process restarts are performed automatically.

### Customization

You can adjust the following parameters directly in the script:

* Days threshold for Recent Items: `Clear-OldFiles -Days 3`
* Days threshold for Quick Access cache: `-Days 2`
* Icon/Thumbnail cache cleanup: default is older than 1 day

---

## How It Works

1. **Self-Elevation**
   The script checks if it is running as Administrator and re-launches itself with elevated privileges if needed.

2. **Logging**
   All output is saved to `C:\Temp\explorer-maintenance.log`.

3. **Cleanup Operations**

   * **Recent Items & Jump Lists**: Deletes files older than 3 days to prevent stale entries.
   * **Icon & Thumbnail Caches**: Removes outdated cache files to reduce explorer hangs.
   * **Quick Access**: Clears the automatic destinations cache.
   * **Temp Files**: Deletes everything in `%TEMP%`.

4. **Windows Search Index**

   * Stops the `WSearch` service.
   * Deletes old index data.
   * Restarts the service and triggers a COM-based reindex.

5. **Process Restarts**

   * `SearchHost.exe` and `ShellExperienceHost.exe` are restarted to apply cleanup.
   * `Explorer.exe` is restarted as the final step.

6. **Parallel Execution**
   Independent cleanup tasks run concurrently to reduce total runtime.

7. **Summary Report**
   At the end of execution, a detailed summary of actions is displayed and logged.

---

## Example Output

```
===== Explorer Maintenance Started: 2025-09-07 12:34:56 =====

===== Summary =====
DeletedRecent      : 12
DeletedCache       : 8
DeletedQuick       : 1
RecycleBinCleared  : True
TempCleaned        : True
IndexRebuilt       : True
ExplorerRestarted  : True
===== Explorer Maintenance Completed: 2025-09-07 12:35:42 =====
```

---

## Safety Notes

* The script is **readily reversible**, but be careful if modifying paths or thresholds.
* Always verify important files in Recent Items or Temp before deletion if unsure.
* Designed to be **non-destructive**: only deletes old or cache files.
* After running, restart your PC for changes to take full effect.

---

## Contributing

Contributions are welcome!

* Submit **issues** for bugs or feature requests.
* Submit **pull requests** with improvements, such as additional cleanup targets or better parallelization.

---

## License

MIT License – see [LICENSE](LICENSE) for details.
